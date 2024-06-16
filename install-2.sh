#!/bin/sh
set -e
trap 'last_command=$current_command; current_command=$BASH_COMMAND; echo "\033[32m Executing $current_command \033[0m"' DEBUG
trap 'echo "\"${last_command}\" command filed with exit code $?."' EXIT
source /etc/profile
export PS1="(chroot) ${PS1}"

disk=/dev/nvme0n1
# this is needed for uefi
echo "Preparing bootloader ..."
mkdir -p /efi
mount /dev/nvme0n1p1 /efi 
mount /dev/nvme0n1p4 /home
# This is needed for non uefi
#mount /dev/sda1 /boot
echo "Installing ebuilds repo ..."
emerge --sync


#echo "Now select a profile ..."
#read -p "Press enter to show profiles"
#eselect profile list
#read -p "Enter the profile number to set or leave empty to leave the selected one: " input_letto
#if [ -n "$input_letto" ]; then
#    eselect profile set "$input_letto"
#fi
echo "Setting cpu flags ..."
emerge --oneshot app-portage/cpuid2cpuflags
echo "*/* $(cpuid2cpuflags)" > /etc/portage/package.use/00cpu-flags
echo "updating @world set ..."
emerge --verbose --update --deep --newuse @world
emerge --depclean

echo "Setting up timezone and locales ..."
echo "Europe/Rome" > /etc/timezone
emerge --config sys-libs/timezone-data
cat > /etc/locale.gen << EOF
en_US ISO-8859-1
en_US.UTF-8 UTF-8
EOF
locale-gen
cat > /etc/env.d/02locale << EOF
LANG="en_US.UTF-8"
LC_COLLATE="C.UTF-8"
EOF
env-update && source /etc/profile && export PS1="(chroot) ${PS1}"
echo "Installing firmware ..."
emerge sys-kernel/linux-firmware
#Intel. 10th gen+ and Apollo Lake (Atom E3900, Celeron N3350, and Pentium N4200) Intel CPUs require this firmware for certain features and certain AMD APUs also have support for this firmware
#https://thesofproject.github.io/latest/platforms/index.html
#emerge --ask sys-firmware/sof-firmware
echo "Compiling kernel ..."
emerge sys-kernel/gentoo-kernel
emerge --depclean

emerge net-misc/dhcpcd
rc-update add dhcpcd default
#rc-service dhcpcd start 
#read -p "Press enter to open /etc/rc.conf: review and change what is needed"
#nano /etc/rc.conf
#read -p "Press enter to open /etc/conf.d/hwclock: review and change what is needed"
#nano /etc/conf.d/hwclock

#TODO siamo qui: https://wiki.gentoo.org/wiki/Handbook:AMD64/Installation/Tools
##TODO import install-3.sh

echo "Installing system tools ..."
emerge app-admin/sysklogd
rc-update add sysklogd default
emerge sys-process/cronie
rc-update add cronie default
emerge app-shells/bash-completion
emerge net-misc/chrony
rc-update add chronyd default
emerge sys-fs/xfsprogs
emerge sys-block/io-scheduler-udev-rules
emerge net-wireless/iw net-wireless/wpa_supplicant
emerge sys-fs/btrfs-progs

echo "Installing bootloader"
## this is needed for uefi
#echo 'GRUB_PLATFORMS="efi-64"' >> /etc/portage/make.conf
emerge sys-boot/grub:2
##Non uefi
#grub-install $disk
# this is needed for uefi
##controllare che effettivamente /boot vada bene come efi directory, non dovrebbe essere /efi??
#grub-install --efi-directory=/efi
grub-install --target=x86_64-efi --efi-directory=/efi
#emerge --noreplace sbsigntools
#export GRUB_MODULES="all_video boot btrfs cat chain configfile echo efifwsetup efinet ext2 fat font gettext gfxmenu gfxterm gfxterm_background gzio halt help hfsplus iso9660 jpeg keystatus loadenv loopback linux ls lsefi lsefimmap lsefisystab lssal memdisk minicmd normal ntfs part_apple part_msdos part_gpt password_pbkdf2 png probe reboot regexp search search_fs_uuid search_fs_file search_label sleep smbios squash4 test true video xfs zfs zfscrypt zfsinfo"
#grub-install --target=x86_64-efi --efi-directory=/efi --modules="${GRUB_MODULES}" --sbat /usr/share/grub/sbat.csv
#sbsign /efi/EFI/Gentoo/grubx64.efi --key /path/to/kernel_key.pem --cert /path/to/kernel_key.pem --out /efi/EFI/Gentoo/grubx64.efi
## shim pre-bootloader for uefi
#emerge sys-boot/shim sys-boot/mokutil sys-boot/efibootmgr
#cp /usr/share/shim/BOOTX64.EFI /efi/EFI/Gentoo/shimx64.efi
#cp /usr/share/shim/mmx64.efi /efi/EFI/Gentoo/mmx64.efi
#This is the key used to sign the kernel
#openssl x509 -in /path/to/kernel_key.pem -inform PEM -out /path/to/kernel_key.der -outform DER
#import certificate
#mokutil --import /path/to/kernel_key.der
#register shim in uefi firmware
#efibootmgr --create --disk /dev/boot-disk --part boot-partition-id --loader '\EFI\GRUB\shimx64.efi' --label 'shim' --unicode
grub-mkconfig -o /boot/grub/grub.cfg
useradd -m -G users,wheel,audio -s /bin/bash andrea
read -p "Now enter the password for user andrea, press enter to continue ..."
passwd andrea
read -p "Now enter the password for user root, press enter to continue ..."
passwd
read -p "Press enter to continue and exit chroot: reboot system and execute install-3.sh to continue ..."
exit
