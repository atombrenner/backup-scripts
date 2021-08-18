#!/bin/bash
set -euo pipefail
# shellcheck disable=SC2064
trap "cd $(pwd)" ERR EXIT

COMPUTER="via15pro"
DISK_ID="nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNM0R221905M"
DISK=$(readlink -f "/dev/disk/by-id/${DISK_ID}")
BACKUPS_DIR="/home/christian/backups"
BACKUP="${1:-$(dirname "$(readlink -e "$0")")}"

if [[ ! -r "${BACKUP}/${COMPUTER}" ]]; then
    echo "${BACKUP} seems not to be a valid backup for ${COMPUTER}"
    exit
fi
(( EUID != 0 )) && echo "Please run as root" && exit 1

echo
echo "Restore Backup $BACKUP to $DISK"

# Restore boot sectors (including partition and grub)
zstd -dcq $BACKUP/bootsector.zst | dd of="${DISK}" bs=512 count=2048
sync

# Restore EFI System Partition
zstd -dcq "${BACKUP}/part1.zst" | partclone.vfat --restore -o "${DISK}p1"
sync

# Restore Boot Partition
zstd -dcq "${BACKUP}/part2.zst" | partclone.ext4 --restore -o "${DISK}p2"
sync

# Restore luksHeader
# In case of disk damage, just create a new encrypted partition and restore the partition data
cryptsetup luksHeaderRestore "${DISK}p3" --header-backup-file "${BACKUP}/luksHeader.bak"
sync

# Restore partition 3 to encrypted device
cryptsetup --key-file "${BACKUPS_DIR}/keyfile" open "${DISK}p3" decrypted
zstd -dcq "${BACKUP}/part3.zst" | partclone.btrfs --restore -o /dev/mapper/decrypted
sync
cryptsetup close decrypted
