#! /bin/bash


cd ~/openwrt # To ~/openwrt
if [ $? -ne 0 ]
    then
        echo "Buildroot must be at ~/openwrt ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Prepare the correct package:
echo "Preparing Package:======================================================="
make package/network/services/hostapd/clean QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Cleaning Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/network/services/hostapd/prepare QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Prepare Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move to the correct dir
echo "Moving to correct directory:============================================="
cd build_dir/target-arm_cortex-a9+vfpv3_uClibc-0.9.33.2_eabi/hostapd-wpad-mini/hostapd-2015-03-25/

# Update to the correct patch
echo "Updating to correct patch: 710-WGTT_compat_printk.patch ================="
quilt push 710-WGTT_hostapd.patch
if [ $? -ne 0 ]
    then
        echo "quilt push Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Add all files to patch (need to do so before copying)
quilt add hostapd/*
quilt add src/ap/*
quilt add src/ap/wgtt.h
quilt add src/ap/wgtt.c
quilt add src/drivers/*
quilt add src/utils/*

# Copy files over
echo "Copy Files Over:========================================================="
cd ..
cp -rf ~/shared/repos/hostapd-2015-03-25 ./
cd hostapd-2015-03-25

#quilt diff

# Update patch with changes
echo "Refresh Patch with Changes:=============================================="
quilt refresh
if [ $? -ne 0 ]
    then
        echo "Quilt Refresh Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move back to buildroot
echo "Update:=================================================================="
cd ~/openwrt
make package/network/services/hostapd/update
if [ $? -ne 0 ]
    then
        echo "Update Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

echo "Clean, Compile:=========================================================="
make package/network/services/hostapd/clean package/index
if [ $? -ne 0 ]
    then
        echo "Final Clean Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/network/services/hostapd/compile package/index V=s
if [ $? -ne 0 ]
    then
        echo "Final Compile Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move back to this directory
cd ~/
cd shared
cd repos

echo "Make all:=========================================================="
sh ./make_wrt1200ac.sh

exit
