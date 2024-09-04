#!/bin/bash

# 启动新的 Kitty 窗口
kitty &

# 获取最近创建的窗口的 ID
# 注意：这里使用了 `sleep` 来确保 Kitty 窗口有足够的时间启动
# 这不是最佳实践，因为启动时间可能因系统而异
sleep 1
new_window_id=$(yabai -m query --windows | jq -r '.[] | select(.app=="kitty") | .id' | tail -n 1)

# 将新的 Kitty 窗口移动到 Space ID 为 3 的 Space
yabai -m window --focus $new_window_id
yabai -m window $new_window_id --space 3

# 可选：将焦点切换到新的 Space
yabai -m space --focus 3






#!/bin/bash

# 启动新的 Kitty 窗口
kitty &

# 获取当前 Space 的 ID
current_space_id=$(yabai -m query --spaces --space | jq -r '.index')

# 切换到 Space ID 为 3 的 Space
yabai -m space --focus 3

# 注意：这里使用了 `sleep` 来确保 Kitty 窗口有足够的时间启动
# 这不是最佳实践，因为启动时间可能因系统而异
sleep 1

# 获取最新打开的 Kitty 窗口的 ID
new_window_id=$(yabai -m query --windows | jq 'reverse | .[] | select(.app=="kitty").id' | head -1)

# 如果当前 Space 不是 3，那么移动 Kitty 窗口到 Space 3
if [ "$current_space_id" -ne 3 ]; then
    yabai -m window $new_window_id --space 3

    # 可选：切换回原始 Space
    yabai -m space --focus $current_space_id
fi

# 可选：聚焦新的 Kitty 窗口
yabai -m window --focus $new_window_id
