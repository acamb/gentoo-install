#!/bin/sh
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND; echo "\033[32m Executing $current_command \033[0m"' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
#netdev="enp2s1"
disk="/dev/nvme0n1"
efiPart="/dev/nvme0n1p1"
swap="/dev/nvme0n1p2"
rootPart="/dev/nvme0n1p3"
homePart="/dev/nvme0n1p4"

stageBaseUrl="https://distfiles.gentoo.org/releases/amd64/autobuilds/20240602T164858Z/"
stageFile="stage3-amd64-desktop-openrc-20240602T164858Z.tar.xz"
hostname="zion"
#dhcpcd $netdev
#### Non uefi
#parted $disk mklabel msdos
#parted $disk mkpart primary ext2 1Mib 200Mib
#parted $disk set 1 boot on
#parted $disk mkpart primary xfs 200Mib 100%
#mkfs.ext4 $bootPart
#mkfs.xfs -f $rootPart
#### UEFI
parted $disk mklabel gpt
parted $disk mkpart primary fat32 1MiB 1GiB
parted $disk mkpart primary linux-swap 1GiB 5GiB 
parted $disk mkpart primary btrfs 5GiB 205GiB 
parted $disk mkpart primary btrfs 205GiB 405GiB
mkfs.vfat $efiPart
mkfs.btrfs -L rootfs $rootPart
mkfs.btrfs -L homefs $homePart
mkswap $swap
swapon $swap

chronyd -q
mkdir -p /mnt/gentoo/efi

mount $rootPart /mnt/gentoo
mkdir /mnt/gentoo/boot

cd /mnt/gentoo
wget $stageBaseUrl$stageFile
tar xf $stageFile
echo "Setting up /etc/portage/make.conf"
cp make.conf /mnt/gentoo/etc/portage/make.conf
mkdir -p /mnt/gentoo/etc/portage/package.use
cp package.use/* /mnt/gentoo/etc/portage/package.use/

echo "Setting up base system..."
cp --dereference /etc/resolv.conf /mnt/gentoo/etc/
##This is needed only if not using gentoo install image
#mount --types proc /proc /mnt/gentoo/proc
#mount --rbind /sys /mnt/gentoo/sys
#mount --make-rslave /mnt/gentoo/sys
#mount --rbind /dev /mnt/gentoo/dev
#mount --make-rslave /mnt/gentoo/dev
#mount --bind /run /mnt/gentoo/run
#mount --make-slave /mnt/gentoo/run 
## This is available only in gentoo install image

cat > /mnt/gentoo/etc/fstab << EOF
/dev/nvme0n3 / brtfs defaults 0 0
/dev/nvme0n1 /efi vfat defaults 0 0
/dev/nvme0n2 none swap sw 0 0
/dev/nvme0n4 /home ext4 defaults 0 0
EOF

echo $hostname > /mnt/gentoo/etc/hostname

echo "\033[32m Chrooting, execution will continue with install-2.sh ... \033[0m"
read -p "Press enter to continue"
cp install*.sh /mnt/gentoo/
mirrorselect -i -o >> /mnt/gentoo/etc/portage/make.conf
arch-chroot /mnt/gentoo /install-2.sh
