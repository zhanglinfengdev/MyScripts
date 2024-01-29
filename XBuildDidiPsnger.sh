#!/bin/bash

cd /Users/didi/AndroidStudioProjects/Quattro

export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-11.0.21/Contents/Home
# export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-1.8.0_392/Contents/Home

echo "正在清理项目..."
./gradlew clean -Dorg.gradle.java.home=$JAVA_HOME
if [ $? -ne 0 ]; then
    echo "项目清理失败"
    exit 1
fi
echo "项目清理完成"

echo "正在执行 Gradle 同步..."
./gradlew --refresh-dependencies -Dorg.gradle.java.home=$JAVA_HOME
if [ $? -ne 0 ]; then
    echo "Gradle 同步失败"
    exit 1
fi
echo "Gradle 同步完成"

echo "正在构建 APK..."
START_TIME=$(date +%s)
./gradlew assembleDebug --stacktrace -Dorg.gradle.java.home=$JAVA_HOME -Pandroid.useNewApkCreator=false
if [ $? -eq 0 ]; then
    echo "APK 构建成功"
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    echo "构建耗时: $(($BUILD_TIME / 60)) 分钟 $(($BUILD_TIME % 60)) 秒"
else
    echo "APK 构建失败"
    exit 1
fi

echo "正在安装 APK..."
./gradlew installDebug -Dorg.gradle.java.home=$JAVA_HOME -Pandroid.useNewApkCreator=false
if [ $? -eq 0 ]; then
    echo "APK 安装成功"
else
    echo "APK 安装失败"
    exit 1
fi

echo "正在启动 APK..."
adb shell am start -n "com.sdu.didi.psnger/com.didi.sdk.app.MainActivity"
if [ $? -eq 0 ]; then
    echo "APK 启动成功"
else
    echo "APK 启动失败"
    exit 1
fi

echo "构建、安装和启动流程完成"
