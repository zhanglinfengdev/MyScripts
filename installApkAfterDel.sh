#!/bin/bash

# echo "$?" > ~/yyyyyyyyy.txt
    # echo "APK 安装成功" >> ~/yyyyyyyyy.txt
$(/Users/didi/scripts/installApk.sh $@)
$(rm -rf "$OLDPWD/$2") >> ~/yyyyyyyyy.txt

