#!/bin/bash

cd /Users/didi/AndroidStudioProjects/Quattro

export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-11.0.21/Contents/Home
# export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-1.8.0_392/Contents/Home

./gradlew clean -Dorg.gradle.java.home=$JAVA_HOME
if [ $? -ne 0 ]; then
    exit 1
fi
./gradlew --refresh-dependencies -Dorg.gradle.java.home=$JAVA_HOME
if [ $? -ne 0 ]; then
    exit 1
fi
START_TIME=$(date +%s)
./gradlew assembleDebug --stacktrace -Dorg.gradle.java.home=$JAVA_HOME -Pandroid.useNewApkCreator=false
if [ $? -eq 0 ]; then
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    echo "构建耗时: $(($BUILD_TIME / 60)) 分钟 $(($BUILD_TIME % 60)) 秒"
else
    exit 1
fi
./gradlew installDebug -Dorg.gradle.java.home=$JAVA_HOME -Pandroid.useNewApkCreator=false
if [ $? -eq 0 ]; then
    echo "APK 安装成功"
else
    exit 1
fi

adb shell am start -n "com.sdu.didi.psnger/com.didi.sdk.app.MainActivity"
if [ $? -eq 0 ]; then
    echo "APK 启动成功"
else
    exit 1
fi

