#! /bin/bash

cp ~/shared/repos/archerc7.config ~/openwrt/.config
cd ~/openwrt

make -j 3
if [ $? -ne 0 ]
    then
        echo "Make Failed! +++++++++++++++++++++++++++++++++++++++++++++++++++ "
        exit
fi

sudo cp -rf bin ~/shared/

exit
