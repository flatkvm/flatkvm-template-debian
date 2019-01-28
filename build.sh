#!/bin/sh

if [ $(id -u) != 0 ]; then
	echo "This script must be run as root"
	exit -1
fi

B=$(which buildah)
if [ -z "${B}" ]; then
	echo "This script requires \"buildah\""
	exit -1
fi

which qemu-img > /dev/null
if [ $? != 0 ]; then
	echo "This script requires \"qemu-img\""
	exit -1
fi

which qemu-nbd > /dev/null
if [ $? != 0 ]; then
	echo "This script requires \"qemu-nbd\""
	exit -1
fi

CTR=$($B from debian:buster-20190122)
$B run $CTR apt update

$B run $CTR /bin/sh -c "DEBIAN_FRONTEND=noninteractive apt install -y systemd systemd-sysv lightdm i3 sudo dbus-x11 pulseaudio x11-xserver-utils ifupdown procps flatpak pulseaudio alsa-utils fonts-roboto fonts-liberation2 libxcb-shape0"

$B copy $CTR files/flatkvm-boot /etc/init.d
$B run $CTR systemctl enable flatkvm-boot
$B run $CTR systemctl mask systemd-sysusers
$B copy $CTR files/lightdm.conf /etc/lightdm/lightdm.conf
$B run $CTR systemctl set-default graphical
$B run $CTR mkdir -p /home/flatkvm/.config/i3
$B copy $CTR files/i3.config /home/flatkvm/.config/i3/config
$B run $CTR mkdir -p /var/lib/flatpak
$B copy $CTR files/asound.state /var/lib/alsa/asound.state
$B copy $CTR files/interfaces /etc/network/interfaces
$B copy $CTR files/shadow /etc/shadow
$B copy $CTR files/sudoers /etc/sudoers
$B copy $CTR files/group /etc/group
$B copy $CTR files/hosts /etc/hosts
$B copy $CTR files/hostname /etc/hostname
$B copy $CTR files/fstab /etc/fstab
$B copy $CTR files/99-vports.rules /etc/udev/rules.d/99-vports.rules
$B copy $CTR files/flatkvm-agent /usr/bin/flatkvm-agent

$B run $CTR mkdir -p /home/flatkvm/.config/systemd/user/default.target.wants
$B run $CTR mkdir -p /home/flatkvm/.config/systemd/user/socket.target.wants
$B run $CTR ln -s /usr/lib/systemd/user/pulseaudio.service /home/flatkvm/.config/systemd/user/default.target.wants/pulseaudio.service
$B run $CTR ln -s /usr/lib/systemd/user/pulseaudio.socket /home/flatkvm/.config/systemd/user/socket.target.wants/pulseaudio.socket


# Free up some space
$B run $CTR rm -fr /usr/share/man
$B run $CTR rm -fr /usr/share/doc

qemu-img create -f qcow2 template-debian-tmp.qcow2 2G
modprobe nbd
qemu-nbd -c /dev/nbd0 template-debian-tmp.qcow2
mkfs.ext4 /dev/nbd0
mount /dev/nbd0 /mnt

MDIR=$($B mount $CTR)
cp -a $MDIR/. /mnt

umount /mnt
qemu-nbd -d /dev/nbd0
$B umount $CTR
$B rm $CTR

qemu-img convert -c -f qcow2 -O qcow2 template-debian-tmp.qcow2 template-debian.qcow2
rm template-debian-tmp.qcow2

