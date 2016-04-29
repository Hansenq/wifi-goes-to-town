#! /bin/bash


cd ~/openwrt # To ~/openwrt
if [ $? -ne 0 ]
    then
        echo "Buildroot must be at ~/openwrt ! ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Prepare the correct package:
echo "Preparing Package:======================================================="
make target/linux/clean QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Cleaning Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make target/linux/prepare QUILT=1
if [ $? -ne 0 ]
    then
        echo "Initial Prepare Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Move to the correct dir
echo "Moving to correct directory:============================================="
cd build_dir/target-mips_34kc_uClibc-0.9.33.2/linux-ar71xx_generic/linux-3.18.23/drivers/net/wireless/ath

# Update to the correct patch
echo "Updating to correct patch: generic/790-wifi_goes_to_town.patch =========="
quilt pop -a
quilt push generic/790-wifi_goes_to_town.patch
if [ $? -ne 0 ]
    then
        echo "quilt push Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

# Add all files to patch
quilt add ath10k/*
quilt add ath9k/*

# Copy files over
cp -rf ~/shared/repos/ath/ath10k/* .
cp -rf ~/shared/repos/ath/ath9k/* .

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
make target/linux/update package/index
if [ $? -ne 0 ]
    then
        echo "Update Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

echo "Clean, Compile:=========================================================="
make target/linux/clean package/index
if [ $? -ne 0 ]
    then
        echo "Final Clean Failed. ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

make target/linux/compile package/index V=s
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
