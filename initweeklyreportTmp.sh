#!/bin/bash

# # 获取当前年份
# year=$(date +%Y)

# # 获取今天的日期
# today=$(date +%Y-%m-%d)

# # 获取当前日期是这一年的第几周
# week=$(date -j -f "%Y-%m-%d" "$today" +%V)

# # 计算周一的日期
# # 注意：在 macOS 中，周日被视为一周的第一天，所以我们需要调整算法
# offset=$(date -j -f "%Y-%m-%d" "$today" +%u)
# offset=$(($offset - 1))  # 减一以适应周日为第一天的情况
# monday=$(date -j -v-"$offset"d -f "%Y-%m-%d" "$today" +%m月%d日)

# # 计算周日的日期
# sunday=$(date -j -v+"$((6 - offset))"d -f "%Y-%m-%d" "$today" +%m月%d日)

# # 格式化输出
# prefix="${year}年第${week}周-${monday}～${sunday}"
# wrFile="/Users/didi/Documents/WeeklyReport/$prefix.wr"

# # 检查文件是否存在
# if [ -f "$wrFile" ]; then
#   echo "文件 $wrFile 已存在。"
# else
#   # 创建文件
#   touch "$wrFile"
#   echo "               $prefix-周报" >> "$wrFile"
#   echo "文件 $wrFile 已创建。"
# fi

# /usr/local/bin/kitty nvim $wrFile

#周报的文本文件
wrFile=$1
#周报的标题
wrTitle=$2



#这里向文件的第二行剧中写入一个wrTitle并拼接一个周报
echo "               $prefix-周报" >> "$wrFile"
#这里写入一个空行
echo "文件 $wrFile 已创建。"

