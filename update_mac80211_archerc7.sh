#! /bin/bash


cd ~/openwrt # To ~/openwrt
if [ $? -ne 0 ]
    then
        echo "Buildroot must be at ~/openwrt ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Prepare the correct package:
echo "Preparing Package:======================================================="
make package/kernel/mac80211/clean QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Cleaning Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/kernel/mac80211/prepare QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Prepare Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move to the correct dir
echo "Moving to correct directory:============================================="
cd build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/compat-wireless-2015-03-09/

# Update to the correct patch
echo "Updating to correct patch: 710-WGTT_compat_printk.patch ================="
quilt push 710-WGTT_compat_printk.patch
if [ $? -ne 0 ]
    then
        echo "quilt push Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Add all files to patch
quilt add net/mac80211/*

# Copy files over
cp -rf ~/shared/repos/mac80211 ./net/

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
make package/kernel/mac80211/update
if [ $? -ne 0 ]
    then
        echo "Update Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

echo "Clean, Compile:=========================================================="
make package/kernel/mac80211/clean package/index
if [ $? -ne 0 ]
    then
        echo "Final Clean Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/kernel/mac80211/compile package/index V=s
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
sh ./make_archerc7.sh

exit
