##!/bin/bash

## 从剪贴板读取内容
#clipboard_content=$(pbpaste)

## 检查剪贴板内容是否为空或者不是一个存在的本地文件或目录
#if [[ -z "$clipboard_content" ]] || ! [[ -e "$clipboard_content" ]]; then
#  # 使用 home 目录作为备选
#  directory_to_use="$HOME"
#  osascript -e 'display notification "Clipboard content is not a valid path. Using home directory instead." with title "Using Home Directory"'
#else
#  # 检查内容是否是一个存在的本地文件或目录
#  if [[ -d "$clipboard_content" ]]; then
#    # 内容是目录，可以直接使用
#    directory_to_use="$clipboard_content"
#  elif [[ -f "$clipboard_content" ]]; then
#    # 内容是文件，获取文件所在目录
#    directory_to_use=$(dirname "$clipboard_content")
#  fi
#fi

## 使用 directory_to_use 变量做你需要的事
## 以下是一个示例命令，使用 `kitty` 打开目录
#open -a Kitty.app "$directory_to_use"

## 发送通知
#osascript -e 'display notification "Kitty opened at: '"$directory_to_use"'." with title "Kitty Launched"'









#!/bin/bash

# 从剪贴板读取内容
clipboard_content=$(pbpaste)

# 定义发送通知的函数
function send_notification {
    local message=$1
    local title=$2
    osascript -e "display notification \"$message\" with title \"$title\""
}

# 检查剪贴板内容是否为空或者不是一个存在的本地文件或目录
if [[ -z "$clipboard_content" ]] || ! [[ -e "$clipboard_content" ]]; then
  # 使用 home 目录作为备选
  directory_to_use="$HOME"
  # 发送多次通知以提高可见性
  for i in {1..1}; do
    send_notification "Clipboard content is not a valid path. Using home directory instead." "Using Home Directory"
    sleep 1 # 稍微延迟避免通知同时到达
  done
else
  # 检查内容是否是一个存在的本地文件或目录
  if [[ -d "$clipboard_content" ]]; then
    # 内容是目录，可以直接使用
    directory_to_use="$clipboard_content"
  elif [[ -f "$clipboard_content" ]]; then
    # 内容是文件，获取文件所在目录
    directory_to_use=$(dirname "$clipboard_content")
  fi
fi

# 使用 directory_to_use 变量做你需要的事
# 以下是一个示例命令，使用 `kitty` 打开目录
open -a Kitty.app "$directory_to_use"

# 发送通知
send_notification "at:$directory_to_use." "Kitty Launched"










