
#!/bin/bash

# 启动 scrcpy
scrcpy &

# 启动 logcat
adb logcat -v color | lnav

