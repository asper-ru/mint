# 
# first part of the installation, before ubuquity
#

sudo parted -s /dev/nvme0n1 mklabel gpt
sudo parted -s /dev/nvme0n1 mkpart ESP fat32 1MiB 1025MiB
sudo mkfs.vfat -F32 /dev/nvme0n1p1
sudo parted -s /dev/nvme0n1 set 1 boot on
sudo parted -s /dev/nvme0n1 mkpart primary 1025MiB 100%

sudo cryptsetup -v --cipher aes-xts-plain64 --key-size 512 --hash sha512 --iter-time 5000 --use-random luksFormat --type luks2 /dev/nvme0n1p2
sudo cryptsetup luksOpen /dev/nvme0n1p2 nvme0n1p2_crypt

sudo pvcreate /dev/mapper/nvme0n1p2_crypt
sudo vgcreate mint /dev/mapper/nvme0n1p2_crypt
sudo lvcreate -L 20G mint -n swap
sudo lvcreate -l +100%FREE mint -n root

sh -c 'ubiquity -b gtk_ui'&

