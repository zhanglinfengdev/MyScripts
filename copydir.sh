#!/bin/bash

# 获取当前工作目录的完整路径
current_dir=$(pwd)

# 将路径复制到剪贴板
echo "$current_dir" | pbcopy

# 可选：告诉用户路径已复制
# echo "The current directory path has been copied to the clipboard."
# 发送通知
osascript -e 'display notification "The current directory path has been copied to the clipboard." with title "Directory Copied"'
