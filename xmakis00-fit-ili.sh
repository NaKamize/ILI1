#!/bin/bash

echo "1. Creating 4 loop devices"
dd if=/dev/zero of=disk0 bs=200M count=1
cp disk0 disk1
cp disk0 disk2
cp disk0 disk3

for p in {0..3}; do losetup "loop$p" "disk$p"; done

echo "2. Creating RAID1 on first two loop devices and RAID0 on other two loop devices"
yes | mdadm --create /dev/md1 --level=mirror --raid-devices=2 /dev/loop0 /dev/loop1
yes | mdadm --create /dev/md0 --level=stripe --raid-devices=2 /dev/loop2 /dev/loop3

echo "3. Creating volume group on top of RAID devices"
pvcreate /dev/md{0..1}
vgcreate FIT_vg /dev/md{0..1}

echo "4. Creating 2 logical volume devices of size 100MB each"
lvcreate FIT_vg -n FIT_lv1 -L 100M
lvcreate FIT_vg -n FIT_lv2 -L 100M

echo "5. Creating EXT4 filesystems on FIT_lv1"
mkfs.ext4 /dev/FIT_vg/FIT_lv1

echo "6. Creating XFS filesystems on FIT_lv2"
mkfs.xfs /dev/FIT_vg/FIT_lv2

echo "7. Mouting FIT_lv1 to /mnt/test1 and FIT_lv2 to /mnt/test2"
mkdir /mnt/test1
mkdir /mnt/test2
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
mount /dev/FIT_vg/FIT_lv2 /mnt/test2

echo "8. Resizing filesystems FIT_lv1 to claim all avaible space in volume group"
umount /mnt/test1
lvresize -rl +100%FREE /dev/FIT_vg/FIT_lv1
mount /dev/FIT_vg/FIT_lv1 /mnt/test1
df -h

echo "9. Creating 300MB file fed with data from /dev/urandom"
dd if=/dev/urandom of=/mnt/test1/big_file bs=1M count=300
sha512sum /mnt/test1/big_file

echo "10. Faulty disk replacement"
dd if=/dev/zero of=disk4 bs=200M count=1
losetup loop4 ./disk4
mdadm --manage /dev/md1 --fail /dev/loop0
mdadm --manage /dev/md1 --remove /dev/loop0
mdadm --manage /dev/md1 --add /dev/loop4
mdadm --wait /dev/md1
cat /proc/mdstat
echo "Done"

