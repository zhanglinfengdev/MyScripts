#!/bin/bash

# 执行 adb 命令并通过 awk 处理输出，提取 topResumedActivity 的信息
# adb shell dumpsys activity activities | awk '
#     /topResumedActivity=/,/^ *$/{ # 从 topResumedActivity 开始到下一个空行
#         if (/topResumedActivity=/) {
#             print "Top Resumed Activity:"
#             next
#         }
#         if ($0 ~ /^ *$/) next # 跳过空行
#         print $0 # 打印 topResumedActivity 块的所有行
#     }'

# adb shell dumpsys activity activities | awk '/topResumedActivity/ {print}'

adb shell dumpsys activity activities | grep topResumedActivity
