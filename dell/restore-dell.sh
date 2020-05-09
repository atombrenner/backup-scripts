#!/bin/bash

set -euo pipefail
trap "cd $(pwd)" ERR EXIT

BACKUP=$1
DISK=$(readlink -f /dev/disk/by-id/wwn-0x5e83a9730ffa3529)

echo
echo "Restore Dell Backup $BACKUP to $DISK"

# Restore boot sectors (including partition and grub)
zstd -dcq $BACKUP/bootsector.zst | dd of="${DISK}" bs=512 count=2048
sync

# Restore EFI System Partition
zstd -dcq "${BACKUP}/part1.zst" | partclone.vfat --restore -o "${DISK}1"
sync

# Restore Boot Partition
zstd -dcq "${BACKUP}/part2.zst" | partclone.ext4 --restore -o "${DISK}2"
sync

# Restore luksHeader, only necessary if sectors are damaged
# In case of disk damage, just create a new encrypted partition and restore the partition data
# cryptsetup luksHeaderRestore "${DISK}3" --header-backup-file "${BACKUP}/luksHeader"
# sync

# Restore partition 3 to encrypted device
cryptsetup --key-file - open "${DISK}3" decrypted
zstd -dcq "${BACKUP}/part3.zst" | partclone.ext4 --restore -o /dev/mapper/decrypted
sync
cryptsetup close decrypted
