

DISK=sdb   # nvme0n1 
PART1=sdb1 # nvme0n1p1
PART2=sdb2 # nvm0n1p2

sudo parted -s /dev/$DISK mklabel gpt
sudo parted -s /dev/$DISK mkpart ESP fat32 1MiB 1025MiB
sudo mkfs.vfat -F32 /dev/$PART1
sudo parted -s /dev/$DISK set 1 boot on
sudo parted -s /dev/$DISK mkpart primary 1025MiB 100%

sudo cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random luksFormat --type luks2 /dev/$PART2
sudo cryptsetup luksOpen /dev/$PART2 $PART2_crypt

sudo pvcreate /dev/mapper/$PART2_crypt
sudo vgcreate mint /dev/mapper/$PART2_crypt
sudo lvcreate -L 20G mint -n swap
sudo lvcreate -l +100%FREE mint -n root

sh -c 'ubiquity -b gtk_ui'

sudo mount /dev/mapper/mint-root /mnt
sudo mount --bind /dev /mnt/dev
sudo mount --bind /dev/pts /mnt/dev/pts
sudo mount --bind /sys /mnt/sys
sudo mount --bind /proc /mnt/proc
sudo mount --bind /run /mnt/run
sudo mount /dev/$PART1 /mnt/boot/efi

sudo chmod -R g-rwx,o-rwx /mnt/boot

echo "$PART2_crypt UUID=$(sudo blkid -s UUID -o value /dev/$PART2) none luks"| sudo chroot /mnt tee -a /etc/crypttab

sudo chroot /mnt sed -i.bak 's/\/dev\/mapper\/mint-root/UUID='"$(sudo blkid -s UUID -o value /dev/mapper/mint-root)"'/' /etc/fstab
sudo chroot /mnt locale-gen --purge --no-archive
sudo chroot /mnt update-initramfs -u
sudo chroot /mnt mkdir /boot/efistub
sudo chroot /mnt mkdir -p /boot/efi/EFI/Boot
sudo chroot /mnt mkdir -p /boot/efi/EFI/Mint

echo "root=UUID=$(sudo blkid -s UUID -o value /dev/mapper/mint-root) ro quiet splash" | sudo chroot /mnt tee -a /boot/efistub/cmdline.txt

sudo chroot /mnt objcopy --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 --add-section .cmdline=/boot/efistub/cmdline.txt --change-section-vma .cmdline=0x30000 --add-section .linux=/boot/vmlinuz --change-section-vma .linux=0x40000 --add-section .initrd=/boot/initrd.img --change-section-vma .initrd=0x3000000 -S /usr/lib/systemd/boot/efi/linuxx64.efi.stub /boot/efistub/kernel.efi

sudo cp -f /mnt/boot/efistub/kernel.efi /mnt/boot/efi/EFI/Mint/kernel.efi
sudo cp -f /mnt/boot/efistub/kernel.efi /mnt/boot/efi/EFI/Boot/Bootx64.efi
sudo chroot /mnt efibootmgr -c -d /dev/$DISK -p 1 -D -L "Mint" -l "\EFI\Mint\kernel.efi"

sudo chroot /mnt mkdir -p /etc/initramfs/post-update.d

echo "#! /bin/sh" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "echo \"Running hook /etc/initramfs/post-update.d/objcopy_update_hook for PACKAGE \$DPKG_MAINTSCRIPT_PACKAGE ... START\"" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "if (echo \"\$DPKG_MAINTSCRIPT_PACKAGE\" |grep -q \"linux-image-\")" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " then" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " cp -f /boot/efistub/kernel.efi /boot/efistub/kernel.\$(uname -r).efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " cp -f /boot/efi/EFI/Mint/kernel.efi /boot/efi/EFI/Mint/kernel.second.last.efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " echo \"PACKAGE \$DPKG_MAINTSCRIPT_PACKAGE matches pattern 'linux-image-' ... kernel warehouse & and second last boot kernel updated\"" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "fi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "objcopy --add-section .osrel=/etc/os-release --change-section-vma .osrel=0x20000 --add-section .cmdline=/boot/efistub/cmdline.txt --change-section-vma .cmdline=0x30000 --add-section .linux=/boot/vmlinuz --change-section-vma .linux=0x40000 --add-section .initrd=/boot/initrd.img --change-section-vma .initrd=0x3000000 -S /usr/lib/systemd/boot/efi/linuxx64.efi.stub /boot/efistub/kernel.efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "if [ -d "/boot/efikeys" ]" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " then" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " sbsign --key /boot/efikeys/db.key --cert /boot/efikeys/db.crt --output /boot/efistub/kernel.efi /boot/efistub/kernel.efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo " sbverify --cert /boot/efikeys/db.crt /boot/efistub/kernel.efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "fi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "cp -f /boot/efistub/kernel.efi /boot/efi/EFI/Mint/kernel.efi" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "echo \"Last boot kernel updated\"" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "sync" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "echo \"Running hook /etc/initramfs/post-update.d/objcopy_update_hook for PACKAGE \$DPKG_MAINTSCRIPT_PACKAGE ... END\"" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook
echo "sleep 10" | sudo chroot /mnt tee -a /etc/initramfs/post-update.d/objcopy_update_hook

sudo chroot /mnt chmod +x /etc/initramfs/post-update.d/objcopy_update_hook

sudo umount /mnt/boot/efi /mnt/proc /mnt/dev/pts /mnt/dev /mnt/sys /mnt/run /mnt

