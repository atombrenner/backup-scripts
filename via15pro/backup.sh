#!/bin/bash
set -euo pipefail
# shellcheck disable=SC2064
trap "cd $(pwd)" ERR EXIT

COMPUTER="via15pro"
DISK_ID="nvme-Samsung_SSD_970_EVO_Plus_500GB_S4EVNM0R221905M"
DISK=$(readlink -f "/dev/disk/by-id/${DISK_ID}") # reading and using the disk id prevents running the script on the wrong computer
BACKUPS_DIR="/home/christian/backups"
BACKUP="${BACKUPS_DIR}/${COMPUTER}/$(date +%Y-%m-%d-%H-%M)"

if [ "${COMPUTER}" != "$(basename "$(dirname "$(readlink -e "$0")")")" ]; then
    echo "this backup.sh script must be placed in '${COMPUTER}' directory" 
    exit 1 
fi
(( EUID != 0 )) && echo "Please run as root" && exit 1

echo
echo "Backup ${DISK} to ${BACKUP}"

# Create backup folder
mkdir -p "${BACKUP}"
touch "${BACKUP}/${COMPUTER}"

# Backup this script
cp "$0" "${BACKUP}" 
cp "$(dirname "$0")/restore.sh" "${BACKUP}"

cd "${BACKUP}"

# Backup partition table
sfdisk -d "${DISK}" >partition.dump

# Backup boot sectors (including partition and grub)
dd if="${DISK}" bs=512 count=2048 status=none | zstd -9 > bootsector.zst

# Backup EFI System Partition
partclone.vfat --clone -d -s "${DISK}p1" | zstd -9 -T0 > part1.zst

# Backup Boot Partition
partclone.ext4 --clone -d -s "${DISK}p2" | zstd -9 -T0 > part2.zst

# Backup Luks Partition Headers
cryptsetup luksDump "${DISK}p3" > luksDump.bak
cryptsetup luksHeaderBackup "${DISK}p3" --header-backup-file luksHeader.bak

# Backup decrypted btrfs partition
cryptsetup --key-file "${BACKUPS_DIR}/keyfile" open "${DISK}p3" decrypted
partclone.btrfs --clone -d -s /dev/mapper/decrypted | zstd -9 -T0 > part3.zst
cryptsetup close decrypted

# Flush caches
echo "Flush caches"
sync

echo "Backup ${COMPUTER} ${DISK} finished successfully"
