#!/bin/bash
export PATH=/usr/local/bin:$PATH
# 获取当前获取焦点的窗口的信息
window_info=$(yabai -m query --windows --window)

# echo $window_info >> ~/gggggggggggg.txt

# osascript -e "display notification "$(echo "$window_info" | jq '.["app"]')" with title \"Focused Window\""

# if [ "$(echo "$WINDOW" | jq '.["has-focus"]')" = "true" ] && [ "$(echo "$WINDOW" | jq '.["app"]')" = "Raycast" ]; then
#     # 使用 AppleScript 发送通知
#     osascript -e "display notification \"$window_info\" with title \"Focused Window\""
# fi

