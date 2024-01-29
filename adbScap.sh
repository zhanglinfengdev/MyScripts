
#!/bin/bash

# 检查设备连接
adb devices > /dev/null 2>&1
if [ $? != 0 ]; then
    echo "请连接设备并启用 USB 调试"
    exit 1
fi

# 截屏并保存到设备
adb shell screencap -p /sdcard/screenshot.png

# 将截图下载到当前目录
adb pull /sdcard/screenshot.png .
echo "已将截图保存到当前目录"
