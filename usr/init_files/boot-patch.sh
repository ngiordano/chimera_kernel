#!/system/xbin/busybox sh
#
# this starts the initscript processing and writes log messages
# and/or error messages for debugging of kernel initscripts or
# user/init.d-scripts.
#

# backup and clean logfile and last_kmsg
/system/xbin/busybox cp /data/user.log /data/user.log.bak
/system/xbin/busybox rm /data/user.log

/system/xbin/busybox cp /data/last_kmsg.txt /data/last_kmsg.txt.bak
/system/xbin/busybox cp /proc/last_kmsg /data/last_kmsg.txt

# start logging
exec >>/data/user.log
exec 2>&1

# start logfile output
echo
echo "************************************************"
echo "DEVIL-ICS BOOT LOG (thanks Mialwe)"
echo "************************************************"
echo

# log basic system information
echo -n "Kernel: ";/system/xbin/busybox uname -r
echo -n "PATH: ";echo $PATH
echo -n "ROM: ";cat /system/build.prop|/system/xbin/busybox grep ro.build.display.id
echo

# set busybox location
BB="/system/xbin/busybox"

# print file contents <string messagetext><file output>
cat_msg_sysfile() {
    MSG=$1
    SYSFILE=$2
    echo -n "$MSG"
    cat $SYSFILE
}


# partitions
echo; echo "mount"
#busybox mount -o remount,noatime,barrier=0,nobh /system
#busybox mount -o remount,noatime,barrier=0,nobh /cache
#busybox mount -o remount,noatime /data
#for i in $($BB mount | $BB grep relatime | $BB cut -d " " -f3);do
#    busybox mount -o remount,noatime $i
#done
#mount

#echo; echo "mount system rw"
busybox mount -o rw,remount /system

    if $BB [ ! -d /data/local/devil ]; then 
	$BB echo "making devil folder at /data/local"
	$BB mkdir /data/local/devil
	$BB chmod 777 /data/local/devil
    fi

if [ -e "/system/vendor/bin/samsung-gpsd" ]; then
    echo 2 > /proc/sys/kernel/randomize_va_space
fi

#copy use normal swap or zram:
if [ -e "/data/local/devil/swap_use" ]; then
swap_use=`cat /data/local/devil/swap_use`
	if [ "$swap_use" -eq 1 ]; then

	# Detect the swap partition
	SWAP_PART=`fdisk -l /dev/block/mmcblk1 | grep swap | sed 's/\(mmcblk1p[0-9]*\).*/\1/'`

		if [ -n "$SWAP_PART" ]; then
    			# If exists a swap partition activate it and create the fstab file
    			echo "Found swap partition at $SWAP_PART"
    			SWAP_RESULT=`swapon $SWAP_PART 2>&1 | grep "not implemented"` 
    			if [ -z "$SWAP_RESULT" ]; then
        			echo "#!/system/bin/sh" > /system/etc/init.d/S05swap
        			echo "swapon -a" >> /system/etc/init.d/S05swap
        			echo "echo 60 > /proc/sys/vm/swappiness" >> /system/etc/init.d/S05swap
        			chmod 750 /system/etc/init.d/S05swap
        			echo "$SWAP_PART swap swap" > /system/etc/fstab
        			echo "Swap partition activated successfully!"
    			else
        			echo "Current kernel does not support swap!"
    			fi
		else
    			echo "Swap partition not found!"
		fi

	elif [ "$swap_use" -eq 2 ]; then
		if [ -e "/system/etc/fstab" ]; then
		rm /system/etc/fstab
		fi
	if [ -e "/data/local/devil/zram_size" ]; then
	RAMSIZE=`cat /data/local/devil/zram_size`
	else RAMSIZE=75
	fi

	if $BB [ "$RAMSIZE" -eq 50 ];then echo "Zram: found vaild RAMSIZE: <$RAMSIZE mb>" 
	elif $BB [ "$RAMSIZE" -eq 75 ];then echo "Zram: found vaild RAMSIZE: <$RAMSIZE mb>" 
	elif $BB [ "$RAMSIZE" -eq 100 ];then echo "Zram: found vaild RAMSIZE: <$RAMSIZE mb>" 
	elif $BB [ "$RAMSIZE" -eq 150 ];then echo "Zram: found vaild RAMSIZE: <$RAMSIZE mb>" 
	else RAMSIZE=75
	echo "Zram: set RAMSIZE to: <$RAMSIZE mb>" 
	fi
	ZRAMSIZE=$(($RAMSIZE*1024*1024))
#	RAMSIZE=`grep MemTotal /proc/meminfo | awk '{ print \$2 }'`
#	ZRAMSIZE=$(($RAMSIZE*200))
	echo "#!/sbin/bb/busybox ash" > /etc/init.d/05zram
#	echo "insmod /system/lib/modules/zram.ko" >> /etc/init.d/05zram
	echo "echo 1 > /sys/block/zram0/reset" >> /etc/init.d/05zram
	echo "echo $ZRAMSIZE > /sys/block/zram0/disksize" >> /etc/init.d/05zram
	echo "mkswap /dev/block/zram0" >> /etc/init.d/05zram
	echo "swapon /dev/block/zram0" >> /etc/init.d/05zram
#	echo "echo 70 > /proc/sys/vm/swappiness" >> /system/etc/init.d/05zram
	echo 'echo "500,1000,20000,20000,20000,25000" > /sys/module/lowmemorykiller/parameters/minfree'  >> /etc/init.d/05zram
	chmod 555 /etc/init.d/05zram
	echo 70 > /proc/sys/vm/swappiness
	echo "zram enabled and activated"
	else
	echo "zram and swap not activated"	
	echo 0 > /data/local/devil/swap_use
	echo 0 > /proc/sys/vm/swappiness	
	fi
else
echo "zram and swap settings not found --> do not activate"	
echo 0 > /data/local/devil/swap_use
echo 0 > /proc/sys/vm/swappiness	
fi

# load profile
echo; echo "profile"
	if [ -e "/data/local/devil/profile" ];then
	profile=`cat /data/local/devil/profile`
	echo "profile: found: <$profile>";
		if [ "$profile" -eq 1 ]; then
    			echo "profile: found vaild governor profile: <smooth>";
      			echo 1 > /sys/class/misc/devil_tweaks/governors_profile;
		elif [ "$profile" -eq 2 ]; then
    			echo "profile: found vaild governor profile: <powersave>";
      			echo 2 > /sys/class/misc/devil_tweaks/governors_profile;
		else
    			echo "profile: setting governor profile: <normal>";
      			echo 0 > /sys/class/misc/devil_tweaks/governors_profile;
    			echo 0 > /data/local/devil/profile;
		fi
	else
    		echo "profile not found: doing nothing";
      		echo 0 > /sys/class/misc/devil_tweaks/governors_profile;
    		echo 0 > /data/local/devil/profile;
	fi

#set cpu max freq while screen off
echo; echo "set cpu max freq while screen off"
if [ -e "/data/local/devil/user_min_max_enable" ];then
   min_max_enable=`cat /data/local/devil/user_min_max_enable`
echo $min_max_enable > /sys/class/misc/devil_idle/user_min_max_enable
   if [ "$min_max_enable" -eq 1 ]; then
   	if [ -e "/data/local/devil/screen_off_max" ];then
	screen_off_max=`cat /data/local/devil/screen_off_max`
	if $BB [ "$screen_off_max" -eq 1400000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>" 
	elif $BB [ "$screen_off_max" -eq 1300000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>"
	elif $BB [ "$screen_off_max" -eq 1200000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>" 
	elif $BB [ "$screen_off_max" -eq 1000000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>"
	elif $BB [ "$screen_off_max" -eq 800000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>" 
	elif $BB [ "$screen_off_max" -eq 400000 ];then echo "CPU: found vaild screen_off_max: <$screen_off_max>"   		
	else
		echo "CPU: did not find vaild screen_off_max, setting 1000 Mhz as default"
		screen_off_max=1000000
	fi
	echo $screen_off_max > /sys/class/misc/devil_idle/user_max
    	else
	echo "screen_off_max: did not find any screen_off_max, setting 1000 Mhz as default"
	echo 1000000 > /sys/class/misc/devil_idle/user_max
	echo 1000000 > /data/local/devil/screen_off_max
   	fi
   else
	echo "screen_off_user_min_max not enabled...nothing to do"
   fi
fi

#set cpu min freq while screen off
echo; echo "set cpu min freq while screen off"
if [ -e "/data/local/devil/screen_off_min" ];then
	screen_off_min=`cat /data/local/devil/screen_off_min`
	if $BB [ "$screen_off_min" -eq 100000 ];then echo "CPU: found vaild screen_off_min: <$screen_off_min>"  
	elif $BB [ "$screen_off_min" -eq 200000 ];then echo "CPU: found vaild screen_off_min: <$screen_off_min>" 
	elif $BB [ "$screen_off_min" -eq 400000 ];then echo "CPU: found vaild screen_off_min: <$screen_off_min>" 
	elif $BB [ "$screen_off_min" -eq 800000 ];then echo "CPU: found vaild screen_off_min: <$screen_off_min>" 
		  		

	else
		echo "CPU: did not find vaild screen_off_min, setting 100 Mhz as default"
		screen_off_min=100000
	fi
		echo $screen_off_min > /sys/class/misc/devil_idle/user_min
else
	echo "screen_off_min: did not find any screen_off_min, setting 100 Mhz as default"
	echo 100000 > /sys/class/misc/devil_idle/user_min
	echo 100000 > /data/local/devil/screen_off_min
fi

# set fsync
echo; echo "fsync"
if [ -e "/data/local/devil/fsync" ];then
	fsync=`cat /data/local/devil/fsync`
	if [ "$fsync" -eq 0 ] || [ "$fsync" -eq 1 ];then
    		echo "fsync: found vaild fsync mode: <$fsync>"
    		echo $fsync > /sys/devices/virtual/misc/fsynccontrol/fsync_enabled
	else
		echo "fsync: did not find vaild fsync mode: setting default"
		echo 1 > /sys/devices/virtual/misc/fsynccontrol/fsync_enabled
	fi
else
echo "fsync: did not find vaild fsync mode: setting default"
echo 1 > /data/local/devil/fsync
echo 1 > /sys/devices/virtual/misc/fsynccontrol/fsync_enabled
fi


# uksm
echo; echo "uksm"
	if [ -e "/data/local/devil/uksm" ];then
	uksm=`cat /data/local/devil/uksm`
		if [ "$uksm" -eq 1 ]; then
    			echo "uksm: found vaild uksm value: <enabled>";
      			echo 1 > /sys/kernel/mm/uksm/run;
		else
    			echo "uksm: found vaild uksm value: <disabled>";
      			echo 0 > /sys/kernel/mm/uksm/run;
		fi
	else
    		echo "uksm not found: doing nothing";
      		echo 0 > /sys/kernel/mm/uksm/run;
    		echo 0 > /data/local/devil/uksm;
	fi


# vm tweaks
# just output of default values for now
echo; echo "vm"
echo "2000" > /proc/sys/vm/dirty_writeback_centisecs # Flush after 20sec. (o:500)
echo "2000" > /proc/sys/vm/dirty_expire_centisecs    # Pages expire after 20sec. (o:200)
echo "10" > /proc/sys/vm/dirty_background_ratio      # flush pages later (default 5% active mem)
echo "65" > /proc/sys/vm/dirty_ratio                 # process writes pages later (default 20%)  
echo "3" > /proc/sys/vm/page-cluster
echo "0" > /proc/sys/vm/laptop_mode
echo "0" > /proc/sys/vm/oom_kill_allocating_task
echo "0" > /proc/sys/vm/panic_on_oom
echo "1" > /proc/sys/vm/overcommit_memory
cat_msg_sysfile "swappiness: " /proc/sys/vm/swappiness                   
cat_msg_sysfile "dirty_writeback_centisecs: " /proc/sys/vm/dirty_writeback_centisecs
cat_msg_sysfile "dirty_expire_centisecs: " /proc/sys/vm/dirty_expire_centisecs    
cat_msg_sysfile "dirty_background_ratio: " /proc/sys/vm/dirty_background_ratio
cat_msg_sysfile "dirty_ratio: " /proc/sys/vm/dirty_ratio 
cat_msg_sysfile "page-cluster: " /proc/sys/vm/page-cluster
cat_msg_sysfile "laptop_mode: " /proc/sys/vm/laptop_mode
cat_msg_sysfile "oom_kill_allocating_task: " /proc/sys/vm/oom_kill_allocating_task
cat_msg_sysfile "panic_on_oom: " /proc/sys/vm/panic_on_oom
cat_msg_sysfile "overcommit_memory: " /proc/sys/vm/overcommit_memory

# security enhancements
# rp_filter must be reset to 1 if TUN module is used (issues)
echo; echo "sec"
echo 0 > /proc/sys/net/ipv4/ip_forward
echo 0 > /proc/sys/net/ipv4/conf/all/rp_filter
echo 2 > /proc/sys/net/ipv6/conf/all/use_tempaddr
echo 0 > /proc/sys/net/ipv4/conf/all/accept_source_route
echo 0 > /proc/sys/net/ipv4/conf/all/send_redirects
echo 1 > /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts
echo -n "SEC: ip_forward :";cat /proc/sys/net/ipv4/ip_forward
echo -n "SEC: rp_filter :";cat /proc/sys/net/ipv4/conf/all/rp_filter
echo -n "SEC: use_tempaddr :";cat /proc/sys/net/ipv6/conf/all/use_tempaddr
echo -n "SEC: accept_source_route :";cat /proc/sys/net/ipv4/conf/all/accept_source_route
echo -n "SEC: send_redirects :";cat /proc/sys/net/ipv4/conf/all/send_redirects
echo -n "SEC: icmp_echo_ignore_broadcasts :";cat /proc/sys/net/ipv4/icmp_echo_ignore_broadcasts 

# setprop tweaks
echo; echo "prop"
setprop wifi.supplicant_scan_interval 180
echo -n "wifi.supplicant_scan_interval (is this actually used?): ";getprop wifi.supplicant_scan_interval

# kernel tweaks
echo; echo "kernel"
echo "NO_GENTLE_FAIR_SLEEPERS" > /sys/kernel/debug/sched_features
echo 500 512000 64 2048 > /proc/sys/kernel/sem 
echo 3000000 > /proc/sys/kernel/sched_latency_ns
echo 500000 > /proc/sys/kernel/sched_wakeup_granularity_ns
echo 500000 > /proc/sys/kernel/sched_min_granularity_ns
echo 0 > /proc/sys/kernel/panic_on_oops
echo 0 > /proc/sys/kernel/panic
cat_msg_sysfile "sched_features: " /sys/kernel/debug/sched_features
cat_msg_sysfile "sem: " /proc/sys/kernel/sem; 
cat_msg_sysfile "sched_latency_ns: " /proc/sys/kernel/sched_latency_ns
cat_msg_sysfile "sched_wakeup_granularity_ns: " /proc/sys/kernel/sched_wakeup_granularity_ns
cat_msg_sysfile "sched_min_granularity_ns: " /proc/sys/kernel/sched_min_granularity_ns
cat_msg_sysfile "panic_on_oops: " /proc/sys/kernel/panic_on_oops
cat_msg_sysfile "panic: " /proc/sys/kernel/panic

# set sdcard read_ahead
echo; echo "read_ahead_kb"
#cat_msg_sysfile "default: " /sys/devices/virtual/bdi/default/read_ahead_kb
#if $BB [[ "$readahead" -eq 64 || "$readahead" -eq 128 || "$readahead" -eq 256 || "$readahead" -eq 512  || "$readahead" -eq 1024 || "$readahead" -eq 2048 || "$readahead" -eq 3096 ]];then
#    echo "CPU: found vaild readahead: <$readahead>"
#else
    readahead=256
#fi
echo $readahead > /sys/devices/virtual/bdi/179:0/read_ahead_kb
echo $readahead > /sys/devices/virtual/bdi/179:8/read_ahead_kb
cat_msg_sysfile "179.0: " /sys/devices/virtual/bdi/179:0/read_ahead_kb
cat_msg_sysfile "179.8: " /sys/devices/virtual/bdi/179:8/read_ahead_kb

# small fs read_ahead
echo 16 > /sys/block/mtdblock2/queue/read_ahead_kb # system
echo 16 > /sys/block/mtdblock3/queue/read_ahead_kb # cache
echo 64 > /sys/block/mtdblock6/queue/read_ahead_kb # datadata

echo; echo "$(date) io"
MTD=`$BB ls -d /sys/block/mtdblock*`
LOOP=`$BB ls -d /sys/block/loop*`
MMC=`$BB ls -d /sys/block/mmc*`
      

# mtd/mmc only tweaks
for i in $MTD $MMC;do
    echo 1024 > $i/queue/nr_requests
done

for i in $MTD $MMC $LOOP $RAM;do
    cat_msg_sysfile "$i/queue/scheduler: " $i/queue/scheduler
    cat_msg_sysfile "$i/queue/rotational: " $i/queue/rotational
    cat_msg_sysfile "$i/queue/iostats: " $i/queue/iostats
    cat_msg_sysfile "$i/queue/read_ahead_kb: " $i/queue/read_ahead_kb
    cat_msg_sysfile "$i/queue/rq_affinity: " $i/queue/rq_affinity   
    cat_msg_sysfile "$i/queue/nr_requests: " $i/queue/nr_requests
    echo
done



# debug output BLN
echo;echo "bln"
cat_msg_sysfile "/sys/class/misc/backlightnotification/enabled: " /sys/class/misc/backlightnotification/enabled



# load bus_limit_settings
echo; echo "bus_limit"
	if [ -e "/data/local/devil/bus_limit" ];then
	bus_limit=`cat /data/local/devil/bus_limit`
	echo "profile: found: <$bus_limit>";
		if [ "$bus_limit" -eq 1 ]; then
    			echo "bus_limit: found vaild bus_limit profile: <automatic>";
      			echo 1 > /sys/class/misc/devil_idle/bus_limit;
		elif [ "$bus_limit" -eq 2 ]; then
    			echo "bus_limit: found vaild bus_limit profile: <permanent>";
      			echo 2 > /sys/class/misc/devil_idle/bus_limit;
		else
    			echo "bus_limit: setting bus_limit profile: <disabled>";
      			echo 0 > /data/local/devil/bus_limit;
    			echo 0 > /sys/class/misc/devil_idle/bus_limit;
		fi
	else
    		echo "bus_limit not found: setting bus_limit profile: <disabled>";
      		echo 0 > /data/local/devil/bus_limit;
    		echo 0 > /sys/class/misc/devil_idle/bus_limit;
	fi


# set vibrator value
echo; echo "vibrator"
if [ -e "/data/local/devil/vibrator" ];then
	vibrator=`cat /data/local/devil/vibrator`
	if [ "$vibrator" -le 43640 ] && [ "$vibrator" -ge 20000 ];then
    		echo "vibrator: found vaild vibrator intensity: <$vibrator>"
    		echo $vibrator > /sys/class/timed_output/vibrator/duty
	else
		echo "vibrator: did not find vaild vibrator intensity: setting default"
		echo 40140 > /sys/class/timed_output/vibrator/duty
	fi
else
	echo "vibrator: did not find vaild vibrator intensity: setting default"
	echo 40140 > /data/local/devil/vibrator
	echo 40140 > /sys/class/timed_output/vibrator/duty
fi

# set wifi
echo; echo "wifi"
if [ -e "/data/local/devil/wifi" ];then
	wifi=`cat /data/local/devil/wifi`
	if [ "$wifi" -eq 0 ] || [ "$wifi" -eq 1 ];then
    		echo "wifi: found vaild wifi mode: <$wifi>"
    		echo $wifi > /sys/module/bcmdhd/parameters/uiFastWifi
	else
		echo "wifi: did not find vaild wifi mode: setting default"
		echo 0 > /sys/module/bcmdhd/parameters/uiFastWifi
	fi
else
	echo "wifi: did not find vaild wifi mode: setting default"
	echo 0 > /data/local/devil/wifi
	echo 0 > /sys/module/bcmdhd/parameters/uiFastWifi
fi

# smooth_ui
echo; echo "smooth_ui"
if [ -e "/data/local/devil/smooth_ui" ];then
    smooth_ui=`cat /data/local/devil/smooth_ui`
	if [ "$smooth_ui" -eq 0 ] || [ "$smooth_ui" -eq 1 ];then
    		echo $smooth_ui > /sys/class/misc/devil_tweaks/smooth_ui_enabled
    		echo "smooth_ui: $smooth_ui"
	else
    		echo "did not find vaild smooth_ui value: setting default (enabled)"
    		echo 1 > /sys/class/misc/devil_tweaks/smooth_ui_enabled
	fi
else
    	echo "did not find any smooth_ui value: setting default (enabled)"
    	echo 1 > /sys/class/misc/devil_tweaks/smooth_ui_enabled
	echo 1 > /data/local/devil/smooth_ui
fi



# init.d support 
# executes <0-9><0-9>scriptname, <E>scriptname, <S>scriptname 
# in this order.
echo; echo "init.d"
    echo "starting init.d script execution..."

    echo $(date) USER INIT START from /system/etc/init.d
    	if cd /system/etc/init.d >/dev/null 2>&1 ; then
           for file in [0-9][0-9]* ; do
		if [ "$file" != "00initd_verify" ]; then
            		if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
           	 	echo "init.d: START '$file'"
            		/system/bin/sh "$file"
            		echo "init.d: EXIT '$file' ($?)"
		else
			echo "do not execute 00initd_verify"
		fi
           done
    	fi
    echo $(date) USER INIT DONE from /system/etc/init.d

    echo $(date) USER EARLY INIT START from /system/etc/init.d
    	if cd /system/etc/init.d >/dev/null 2>&1 ; then
            for file in E* ; do
            	if ! cat "$file" >/dev/null 2>&1 ; then continue ; fi
            	echo "init.d: START '$file'"
            	/system/bin/sh "$file"
            	echo "init.d: EXIT '$file' ($?)"
            done
    	fi
    echo $(date) USER EARLY INIT DONE from /system/etc/init.d

    echo $(date) USER INIT START from /system/etc/init.d
    if cd /system/etc/init.d >/dev/null 2>&1 ; then
        for file in S* ; do
            if ! ls "$file" >/dev/null 2>&1 ; then continue ; fi
            echo "init.d: START '$file'"
            /system/bin/sh "$file"
            echo "init.d: EXIT '$file' ($?)"
        done
    fi
    echo $(date) USER INIT DONE from /system/etc/init.d

# governor specific settings:
echo; echo "governor settings"
    governor=`cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor`
	if [ "$governor" = "conservative" ] || [ "$governor" = "ondemand" ];then
		if [ -e "/data/local/devil/$governor" ];then
		$responsiveness=`cat /data/local/devil/$governor/responsiveness`
		$min_upthreshold=`cat /data/local/devil/$governor/min_upthreshold`
		$sleep_multiplier=`cat /data/local/devil/$governor/sleep_multiplier`
		echo $responsiveness > /sys/devices/system/cpu/cpufreq/$governor/responsiveness_freq
		echo $min_upthreshold > /sys/devices/system/cpu/cpufreq/$governor/up_threshold_min_freq
		echo $sleep_multiplier > /sys/devices/system/cpu/cpufreq/$governor/sleep_multiplier
		else
		echo "/data/local/devil/$governor not found, skipping..."
		fi
	else
		echo "nothing to do"
	fi

# userinit.d:
echo; echo "userinit.d"
if [ -d /data/local/userinit.d ];
then
   logwrapper $BB run-parts /data/local/userinit.d;
   setprop cm.userinit.active 1;
fi;

if [ -e /etc/init.d/05zram ]; then
rm /etc/init.d/05zram
fi

if [ -e /etc/init.d/S05swap ]; then
rm /etc/init.d/S05swap
fi

echo; echo "mount system ro"
busybox mount -o ro,remount /system


