#!/bin/bash

# 设置环境变量
cd /Users/didi/AndroidStudioProjects/Quattro

export JAVA_HOME=/usr/local/Cellar/openjdk@11/11.0.25/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-15.0.2/Contents/Home
export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-17.0.14/Contents/Home

# Set the Gradle options once
GRADLE_OPTS="-Dorg.gradle.daemon=true -Dorg.gradle.parallel=true -Dorg.gradle.configureondemand=true"

# Define the apkCreator property to reuse it
# APK_CREATOR_OPTS="-Pandroid.useNewApkCreator=false"
APK_CREATOR_OPTS=""

echo "正在清理项目..."
# Consider only cleaning when necessary to avoid extra work
# ./gradlew clean $GRADLE_OPTS

echo "正在执行 Gradle 同步..."
./gradlew --refresh-dependencies $GRADLE_OPTS
if [ $? -ne 0 ]; then
    echo "Gradle 同步失败"
    exit 1
fi
echo "Gradle 同步完成"

echo "正在构建 APK..."
START_TIME=$(date +%s)
./gradlew assembleDebug --stacktrace $GRADLE_OPTS $APK_CREATOR_OPTS
if [ $? -eq 0 ]; then
    echo "APK 构建成功"
    END_TIME=$(date +%s)
    BUILD_TIME=$((END_TIME - START_TIME))
    echo "构建耗时: $(($BUILD_TIME / 60)) 分钟 $(($BUILD_TIME % 60)) 秒"
else
    echo "APK 构建失败"
    exit 1
fi

# echo "正在安装 APK..."
# ./gradlew installDebug $GRADLE_OPTS $APK_CREATOR_OPTS
# if [ $? -eq 0 ]; then
#     echo "APK 安装成功"
# else
#     echo "APK 安装失败"
#     exit 1
# fi

# echo "正在启动 APK..."
# adb shell am start -n "com.sdu.didi.psnger/com.didi.sdk.app.MainActivity"
# if [ $? -eq 0 ]; then
#     echo "APK 启动成功"
# else
#     echo "APK 启动失败"
#     exit 1
# fi

# echo "构建、安装和启动流程完成"


# ...

echo "正在安装 APK..."
./gradlew installDebug $GRADLE_OPTS $APK_CREATOR_OPTS
if [ $? -eq 0 ]; then
    echo "APK 安装成功"
else
    echo "APK 安装失败"
    exit 1
fi

echo "正在启动 APK，并获取启动耗时..."

LAUNCH_OUTPUT=$(adb shell am start -W -n "com.sdu.didi.psnger/com.didi.sdk.app.MainActivity" 2>&1)

if echo "$LAUNCH_OUTPUT" | grep -q "Error"; then
    echo "启动失败，错误信息如下:"
    echo "$LAUNCH_OUTPUT"
    exit 1
else
    LAUNCH_TIME=$(echo "$LAUNCH_OUTPUT" | grep "TotalTime" | awk '{print $2}')
    if [ ! -z "$LAUNCH_TIME" ]; then
        echo "APK 启动成功"
        echo "APK 启动耗时: ${LAUNCH_TIME}ms"
        END_TIME=$(date +%s) # Correctly capture the current time in nanoseconds
        TOTAL_TIME=$((END_TIME - START_TIME)) # Calculate the difference
        echoMsg="总耗时: $(($TOTAL_TIME / 60)) 分钟 $(($TOTAL_TIME % 60)) 秒" # Convert nanoseconds to milliseconds
        ~/scripts/smsg.sh "${echoMsg}"
        echo ${echoMsg}
    else
        echo "启动时间未知，输出信息如下:"
        echo "$LAUNCH_OUTPUT"
        exit 1
    fi
fi

echo "构建、安装和启动流程完成"
