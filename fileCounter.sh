#!/bin/bash


# 获取当前目录
directory=$(pwd)

# 统计不同文件类型的数量
echo "当前目录下文件类型统计："

# 使用find命令找到当前目录下所有文件，并使用awk和cut提取文件类型，然后使用sort和uniq统计数量
find "$directory" -type f | awk -F. '{print $NF}' | awk '{count[$1]++} END {for (type in count) print type, count[type]}' | sort

