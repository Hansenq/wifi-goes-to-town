#! /bin/bash


cd ~/openwrt # To ~/openwrt
if [ $? -ne 0 ]
    then
        echo "Buildroot must be at ~/openwrt ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Prepare the correct package:
echo "Preparing Package:======================================================="
make package/kernel/mwlwifi/clean QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Cleaning Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/kernel/mwlwifi/prepare QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Prepare Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move to the correct dir
echo "Moving to correct directory:============================================="
cd build_dir/target-arm_cortex-a9+vfpv3_uClibc-0.9.33.2_eabi/linux-mvebu/mwlwifi-10.3.0.14-20151130

# Update to the correct patch
echo "Updating to correct patch: 710-WGTT_compat_printk.patch ================="
quilt push 710-WGTT_mwlwifi_printk.patch
if [ $? -ne 0 ]
    then
        echo "quilt push Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Add all files to patch
quilt add *

# Copy files over
cp -rf ~/shared/repos/mwlwifi-10.3.0.14-20151130/* .

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
make package/kernel/mwlwifi/update
if [ $? -ne 0 ]
    then
        echo "Update Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

echo "Clean, Compile:=========================================================="
make package/kernel/mwlwifi/clean package/index
if [ $? -ne 0 ]
    then
        echo "Final Clean Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make package/kernel/mwlwifi/compile package/index V=s
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
sh ./make_wrt1900ac.sh

exit
