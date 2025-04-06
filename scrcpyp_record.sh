#!/bin/bash
# 获取当前终端的 Bundle ID
current_app=$(osascript -e 'tell application "System Events" to get bundle identifier of first application process whose frontmost is true')

# # 启动 scrcpy
# scrcpy

# # 延迟一段时间，以确保 scrcpy 窗口已经打开
# sleep 1

# # 将焦点切换回原来的应用
# osascript -e "tell application id \"$current_app\" to activate"
#

# pkill -f 'scrcpy'

# 启动 scrcpy
# /usr/local/bin/scrcpy --record "scrcpyRecord-$0.mp4"
scrcpy --no-playback
 --record AAAvideo.mp4
# 给 scrcpy 一点时间启动
# sleep 2

# yabai -m window --insert stack

# # 循环三次将焦点切换回原来的应用
# for i in {1..7}
# do
#   osascript -e "tell application id \"$current_app\" to activate"
#   # sleep 1 # 在尝试之间暂停一秒
# done


# sleep 2
# yabai -m window --focus stack.next

# 等待 scrcpy 进程结束
# wait

