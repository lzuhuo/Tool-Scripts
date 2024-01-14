sudo su

fdisk -l

pvresize /dev/sda3

lvresize -l +100%FREE /dev/mapper/ubuntu--vg-ubuntu--lv

resize2fs /dev/mapper/ubuntu--vg-ubuntu--lv