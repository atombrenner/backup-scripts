#!/bin/bash

set -euo pipefail
# shellcheck disable=SC2064
trap "cd $(pwd)" ERR EXIT

(( EUID != 0 )) && echo "Please run as root" && exit

# reading and using the disk id prevents running the script on the wrong computer
DISK=$(readlink -f /dev/disk/by-id/nvme-Samsung_SSD_970_PRO_512GB_S5JYNS0N711121D)
BACKUPS_DIR="/home/christian/backups"
BACKUP="${BACKUPS_DIR}/schenker/$(date +%Y-%m-%d-%H-%M)"

echo
echo "Backup Schenker ${DISK} to ${BACKUP}"

# Create backup folder
mkdir -p "${BACKUP}"
cp "$0" "${BACKUP}" # Backup this script
cd "${BACKUP}"

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
cryptsetup --key-file "${BACKUPS_DIR}/keyfile" open "${DISK}p3" decrypted
partclone.btrfs --clone -d -s /dev/mapper/decrypted | zstd -12 -T0 > part3.zst
cryptsetup close decrypted

# Flush caches
echo "Flush caches"
sync

echo "Backup Schenker finished successfully"
