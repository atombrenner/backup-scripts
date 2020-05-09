#!/bin/bash

set -euo pipefail
trap "cd $(pwd)" ERR EXIT

BACKUP="/home/christian/backups/lenovo/$(date +%Y-%m-%d-%H-%M)"
DISK=$(readlink -f /dev/disk/by-id/nvme-SAMSUNG_MZVLW512HMJP-000L7_S359NX0J402722)

echo
echo "Backup Lenovo $DISK to $BACKUP"

# Create backup folder
mkdir -p "$BACKUP"
cp "$0" "$BACKUP" # Backup this script
cd "$BACKUP"

# Backup partition table
sfdisk -d "${DISK}" >partition.dump

# Backup boot sectors (including partition and grub)
dd if="${DISK}" bs=512 count=2048 status=none | zstd -9 > bootsector.zst

# Backup EFI System Partition
partclone.vfat --clone -d -s "${DISK}p1" | zstd -9 > part1.zst

# Backup Boot Partition
partclone.ext4 --clone -d -s "${DISK}p2" | zstd -9 -T0 > part2.zst

# Skip swap partition 3

# Backup Encrypted Partition 4
cryptsetup luksDump "${DISK}p4" > luksDump4
cryptsetup luksHeaderBackup "${DISK}p4" --header-backup-file luksHeader4
cryptsetup --key-file - open "${DISK}p4" decrypted
partclone.ext4 --clone -d -s /dev/mapper/decrypted | zstd -8 -T0 > part4.zst
cryptsetup close decrypted

# Flush caches
echo "Flush caches"
sync

echo "Backup finished successfully"

