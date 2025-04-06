#!/bin/bash




# sketchybar --add item com.versions   left                   \
#            --set com.versions "${com_versions[@]}"          \
                                                            # \
           # --add item apple.prefs1    popup.com.versions     \
           # --set apple.prefs "${apple_prefs1[@]}"           \
           #                                                  \
           # --add item apple.activity1 popup.com.versions     \
           # --set apple.activity "${apple_activity1[@]}"



POPUP_OFFWR='/usr/local/bin/sketchybar --set com.weeklyreport popup.drawing=off'
# 获取当前年份
year=$(date +%Y)

# 获取今天的日期
today=$(date +%Y-%m-%d)

# 获取当前日期是这一年的第几周
week=$(date -j -f "%Y-%m-%d" "$today" +%V)

# 计算周一的日期
# 注意：在 macOS 中，周日被视为一周的第一天，所以我们需要调整算法
offset=$(date -j -f "%Y-%m-%d" "$today" +%u)
offset=$(($offset - 1))  # 减一以适应周日为第一天的情况
monday=$(date -j -v-"$offset"d -f "%Y-%m-%d" "$today" +%m月%d日)

# 计算周日的日期
sunday=$(date -j -v+"$((6 - offset))"d -f "%Y-%m-%d" "$today" +%m月%d日)

# 格式化输出
prefix="${year}年第${week}周-${monday}～${sunday}"
wrFile="/Users/didi/Documents/WeeklyReport/$prefix.md"

/usr/local/bin/sketchybar --set com.weeklyreport label="${week}周"






wrpitemsFile="/Users/didi/.config/sketchybar/com.weeklyreport-wrpitems.dot"
# 检查文件是否存在
if [ -f "$wrpitemsFile" ]; then

  # 通过 while 循环读取文件的每一行
  while IFS= read -r line
  do
     itemID=$(echo $line | md5sum | awk '{print $1}')
     /usr/local/bin/sketchybar --remove $itemID
  done < "$wrpitemsFile"

fi



echo '' > "$wrpitemsFile"
# 检查文件是否存在
if [ -f "$wrFile" ]; then
  echo "文件 $wrFile 已存在。"

  # 通过 while 循环读取文件的每一行
  while IFS= read -r line
  do
     itemID=$(echo $line | md5sum | awk '{print $1}')
     labelTxt=$(echo "$line" | awk '{gsub(/[ \t\n]/, ""); print}')
     /usr/local/bin/sketchybar --add item $itemID popup.com.weeklyreport                      \
         --set $itemID label="$labelTxt"                                                      \
         --set $itemID click_script="echo '${line}' | pbcopy; $POPUP_OFFWR; /Users/didi/scripts/weekdateformat.sh"
         # --set $line label=$(echo "$line" | awk '{$1=$1};1')           \

     echo $line >> "$wrpitemsFile"

  done < "$wrFile"

  # curWrContent=$(cat "$wrFile")
  # /usr/local/bin/sketchybar --set com.wrcontent label="$curWrContent"
else
  # 创建文件
  touch "$wrFile"
  # echo "$prefix" >> "$wrFile"
  # ## <font color="orange"><center>2024年第36周-09月02日～09月08日-周报&darr;</center></font>
  # echo "                 $prefix-周报" >> "$wrFile"
  echo "## <font color="orange"><center> $prefix-周报&darr; </center></font>" >> "$wrFile"
  echo "文件 $wrFile 已创建。"
fi




