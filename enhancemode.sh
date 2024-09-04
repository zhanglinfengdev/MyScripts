osascript -e 'tell application "System Events" to key code 101'



# osascript  <<EOF
#     display notification "enhance switch" with title "enhance"
# EOF


# 读取文件内容
value=$(cat "/Users/didi/.config/sketchybar/com.enhance.dot")

# 将数值加1
((value++))

# 将结果写回文件
echo "$value" > "/Users/didi/.config/sketchybar/com.enhance.dot"


source /Users/didi/.config/skhd/scripts/helpers.sh;



# if [ "$1" = "-N" ]; then
#     normal_mode
# elif [ "$1" = "-Window" ]; then
#     window_mode
# elif [ "$1" = "-Script" ]; then
#     scripts_mode
# elif [ "$1" = "-iMpd" ]; then
#     instruction_mode_mpd
# elif [ "$1" = "-iHA-fan" ]; then
#     instruction_mode_homeAssistant_fan
# elif [ "$1" = "-iHA-lamp" ]; then
#     instruction_mode_homeAssistant_lamp
# fi

# 判断奇偶性
if (( value % 2 == 0 )); then
    sketchybar --set com.enhance icon=􀂝
    instruction_mode_homeAssistant_fan
else
    normal_mode
    sketchybar --set com.enhance icon=􀂜
fi

