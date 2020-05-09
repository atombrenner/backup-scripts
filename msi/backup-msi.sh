#!/bin/bash

set -euo pipefail
# shellcheck disable=SC2064
trap "cd $(pwd)" ERR EXIT

ROOT="$(realpath $(dirname "$0")/..)"
KEYFILE="${ROOT}/keyfile"
BACKUP="${ROOT}/backups/msi/$(date +%Y-%m-%d-%H-%M)"
DISK=$(readlink -f /dev/disk/by-id/nvme-THNSN5256GPUK_NVMe_TOSHIBA_256GB_176B747OKSGU)

echo
echo "Backup MSI ${DISK} to ${BACKUP}"

# Create backup folder
mkdir -p "$BACKUP"
cp "$0" "$BACKUP" # Backup this script
cd "$BACKUP"

# Backup partition table
sfdisk -d "${DISK}" >partition.dump

# Backup boot sectors (including partition and grub)
dd if="${DISK}" bs=512 count=2048 status=none | zstd -12 > bootsector.zst

# Backup EFI System Partition
partclone.vfat --clone -d -s "${DISK}p1" | zstd -12 -T0 > part1.zst

# Backup Boot Partition
partclone.ext4 --clone -d -s "${DISK}p2" | zstd -12 -T0 > part2.zst

# Backup Encrypted Partition
cryptsetup luksDump "${DISK}p3" > luksDump.bak
cryptsetup luksHeaderBackup "${DISK}p3" --header-backup-file luksHeader.bak
cryptsetup --key-file "${KEYFILE}" open "${DISK}p3" decrypted
partclone.ext4 --clone -d -s /dev/mapper/decrypted | zstd -12 -T0 > part3.zst
cryptsetup close decrypted

# Flush caches
echo "Flush caches"
sync

echo "Backup finished successfully"
