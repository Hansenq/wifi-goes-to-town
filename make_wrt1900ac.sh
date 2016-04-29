#! /bin/bash

cp ~/shared/repos/wrt1900ac.config ~/openwrt/.config
cd ~/openwrt

make -j 3
if [ $? -ne 0 ]
    then
        echo "Make Failed! +++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

sudo cp -rf bin ~/shared/

exit
