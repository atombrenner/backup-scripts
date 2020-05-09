#!/bin/bash

set -euo pipefail
trap "cd $(pwd)" ERR EXIT

BACKUP="/home/christian/big-disk/redhome/$(date +%Y-%m-%d-%H-%M)"
DISK=$(readlink -f /dev/disk/by-id/wwn-0x5e83a97f2ef90426)

echo
echo "Backup RedHome to $BACKUP"

# Create backup folder
mkdir -p "$BACKUP"
cp "$0" "$BACKUP" # Backup this script
cd "$BACKUP"

# Backup partition table
sfdisk -d "${DISK}" >partition.dump

# Backup boot sectors (including partition and grub)
dd if="${DISK}" bs=512 count=2048 status=none | zstd -9 > bootsector.zst

# Backup EFI System Partition
partclone.vfat --clone -d -s "${DISK}1" | zstd -9 > part1.zst

# Backup Boot Partition
partclone.ext2 --clone -d -s "${DISK}2" | zstd -9 -T0 > part2.zst

# Backup Encrypted Partition
cryptsetup luksDump "${DISK}3" > luks.dump
cryptsetup luksHeaderBackup "${DISK}3" --header-backup-file luksHeader.bak
cryptsetup --key-file ~keyfile open "${DISK}3" crypto
lvm lvs > lvm.dump
lvm vgcfgbackup -f vgcfgbackup.txt xubuntu-vg
partclone.ext4 --clone -d -s /dev/xubuntu-vg/root | zstd -9 -T0 > part3.zst
lvchange -an xubuntu-vg 
cryptsetup close crypto

# Flush caches
echo "Flush caches"
sync

echo "Backup finished successfully"

