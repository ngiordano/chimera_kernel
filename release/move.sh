#!/system/bin/sh
if [ ! -d "/system/etc/init.d/backup" ];
then
	mkdir /system/etc/init.d/backup
fi
mv /system/etc/init.d/* /system/etc/init.d/backup/