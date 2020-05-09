#!/bin/bash

BIGDISK=$(readlink -f /dev/disk/by-id/usb-WDC_WD50_00AAJS-00TKA0_FDC0FD500000000FD0FCAFF4517163-0:0)
cryptsetup --key-file - open "${BIGDISK}" big-disk
mount -t ext4 -U 20aadf1a-d4c7-441a-ba68-ba5655620fa9 /home/christian/big-disk
