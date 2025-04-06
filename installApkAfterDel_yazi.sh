#!/bin/bash

# echo "$?" > ~/yyyyyyyyy.txt
    # echo "APK 安装成功" >> ~/yyyyyyyyy.txt
$(/Users/didi/scripts/installApk_yazi.sh $@)
$(rm -rf "$1") >> ~/yyyyyyyyy.txt

