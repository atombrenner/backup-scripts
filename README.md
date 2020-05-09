# Backup Scripts

Scripts to backup my computers with encrypted disks.

# Motivation
Clonezilla cannot backup encrypted disks in an efficient manner,
it will use `dd` to backup every byte of the disk, regardless if it is used or not. 

So I had to write my own tooling, which assumes that the backup target
is also an encrypted disk. 

My backup script uses the decrypted mapped device with partclone to backup partitions.
As a bonus, it will pipe the data through zstd, which has better compression and is much faster on multi core machines.

This folder lives on an encrypted Fedora installed on an encrypted USB SSD.

The backup are stored on encrypted devices. 
