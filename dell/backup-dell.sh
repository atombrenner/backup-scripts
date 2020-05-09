#!/bin/bash

set -euo pipefail
trap "cd $(pwd)" ERR EXIT

BACKUP="/home/christian/backups/dell/$(date +%Y-%m-%d-%H-%M)"
DISK=$(readlink -f /dev/disk/by-id/wwn-0x5e83a9730ffa3529)

echo
echo "Backup Dell $DISK to $BACKUP"

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
partclone.ext4 --clone -d -s "${DISK}2" | zstd -9 -T0 > part2.zst

# Backup Encrypted Partition
cryptsetup luksDump "${DISK}3" > luksDump
cryptsetup luksHeaderBackup "${DISK}3" --header-backup-file luksHeader
cryptsetup --key-file - open "${DISK}3" decrypted
partclone.ext4 --clone -d -s /dev/mapper/decrypted | zstd -9 -T0 > part3.zst
cryptsetup close decrypted

# Flush caches
echo "Flush caches"
sync

echo "Backup finished successfully"
