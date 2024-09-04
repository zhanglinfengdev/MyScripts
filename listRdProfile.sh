#!/bin/bash




# sketchybar --add item com.versions   left                   \
#            --set com.versions "${com_versions[@]}"          \
                                                            # \
           # --add item apple.prefs1    popup.com.versions     \
           # --set apple.prefs "${apple_prefs1[@]}"           \
           #                                                  \
           # --add item apple.activity1 popup.com.versions     \
           # --set apple.activity "${apple_activity1[@]}"



POPUP_OFF='/usr/local/bin/sketchybar --set com.versions popup.drawing=off'

version_item=(
  icon=$ACTIVITY
  # label="Activity"
  # click_script="echo $date_no_space | pbcopy; $POPUP_OFF"
)



directory="/Users/didi/Documents/RdProfiles"
suffix="prd"



echo $NAME
# 指定搜索深度
depth=4


# dateL=$(cat "/Users/didi/.config/sketchybar/com.versions.dot")
# /usr/local/bin/sketchybar --set com.versions label="$dateL"

    # --set com.retime "${version_item[@]}"           \
    # --set com.retime label="􁆸 LTime:$dateL"    \
    # --set com.retime click_script="echo $dateL | pbcopy; $POPUP_OFF"

$(echo cat ~/aaaaa11111111.txt | awk -F'=' '{print $NF}')

/usr/local/bin/sketchybar --remove popup.com.versions

# echo -n " " > ~/aaaaa11111111.txt

recentC=""

# 使用find命令递归搜索目录并找到包含关键字的文件，使用ls -lt命令按照修改时间排序
# for file in $(find $directory -maxdepth $depth -type f -name "*.$suffix" -mtime -7 -exec grep -wrl -e $keyword1 -e $keyword2 {} \; | xargs ls -lt | awk '{print $9}')
# for file in $(find $directory -maxdepth $depth -type f -name "*.$suffix" -mtime -61 -exec grep -wrl -e $keyword1 -e $keyword2 {} \; | xargs ls -lt | awk '{print $9}')
for file in $(find "$directory" -maxdepth "$depth" -type f -name "*.$suffix" -mtime -61 | xargs -r ls -lt)
# for file in $(find $directory -type f -name "*.$suffix" -mtime -7 -print0 | xargs -0 -P 4 grep -Frl -e $keyword1 -e $keyword2    | xargs -0 ls -lt | cut -f 9-)
do


   # 使用stat命令获取最后修改时间
   # modified_time=$(date -r $(stat -f "%m" $file) "+%m月%d日%H时%M分%S秒")
   modified_time=$(date -r $(stat -f "%m" $file) "+%m月%d日%H时%M分%S秒")

   # 使用grep命令获取包含关键字的行
   line_content1=$(grep -E '^[[:space:]]*'"$keyword1" $file )
   line_content2=$(grep -E '^[[:space:]]*'"$keyword2" $file )

   # 如果找到了包含关键字的行，才打印输出
   if [ ! -z "$line_content1" -a ! -z "$line_content2" ]
   then

       # 使用awk命令分割字符串并获取最后一个等号后的部分
       artifact_id=$(echo $line_content1 | awk -F'=' '{print $NF}')
       version=$(echo $line_content2 | awk -F'=' '{print $NF}')

       # 拼接两个字符串
       result="$modified_time:${artifact_id}=${version}"

       if [ -z "$recentC" ]
       then
           # last=$(echo $version | cut -d. -f$(echo $version | tr . '\n' | wc -l))
           # last=$(echo $version | rev | cut -d. -f2- | rev)
           recentC="$artifact_id/$version";
       fi
       # /usr/local/bin/sketchybar --remove $file

       /usr/local/bin/sketchybar --add item $file popup.com.versions  \
           --set $file "${version_item[@]}"                           \
           --set $file label="$result"                                \
           --set $file click_script="echo '${artifact_id} ${version}' | pbcopy; $POPUP_OFF"


       # echo -n $file >> ~/aaaaa11111111.txt
       # echo -n " " >> ~/aaaaa11111111.txt

      # echo "File: $file"
      # echo "Last modified: $modified_time"
      # echo "Line with '$keyword1': $line_content1"
      # echo "Line with '$keyword2': $line_content2"
      # echo "------------------------"
   fi
done

# /usr/local/bin/sketchybar --set com.versions label="$dateL/$recentC"

# echo $(TZ="Asia/Shanghai" date) > "./$NAME.dot"
# TZ="Asia/Shanghai" date "+%H:%M:%S:$recentC"  > "/Users/didi/.config/sketchybar/com.versions.dot"
# echo $(date) > "./$NAME.dot"

# sketchybar --reorder $(cat "/Users/didi/aaaaa11111111.txt")
# sketchybar --reorder <item 1> <item 2>

# dateL=$(cat "/Users/didi/.config/sketchybar/com.versions.dot")
D=$(TZ="Asia/Shanghai" date "+%H:%M:%S")
/usr/local/bin/sketchybar --set com.versions label="$D:$recentC"






# /Users/didi/scripts/updateWrContent.sh




# POPUP_OFFWR='/usr/local/bin/sketchybar --set com.weeklyreport popup.drawing=off'
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

# /usr/local/bin/sketchybar --set com.weeklyreport label="${week}周"






# # 检查文件是否存在
# if [ -f "$NAME-wrpitems.dot" ]; then

#   # 通过 while 循环读取文件的每一行
#   while IFS= read -r line
#   do
#      /usr/local/bin/sketchybar --remove $line
#   done < "$NAME-wrpitems.dot"

# fi



# echo '' > "$NAME-wrpitems.dot"
# # 检查文件是否存在
# if [ -f "$wrFile" ]; then
#   echo "文件 $wrFile 已存在。"

#   # 通过 while 循环读取文件的每一行
#   while IFS= read -r line
#   do
#      /usr/local/bin/sketchybar --add item $line popup.com.weeklyreport \
#          --set $line label=$(echo "$line" | awk '{$1=$1};1')           \
#          --set $line click_script="echo '${line}' | pbcopy; $POPUP_OFFWR; /Users/didi/scripts/weekdateformat.sh" \
#          --set $line hegiht=25

#      echo $line >> "$NAME-wrpitems.dot"

#   done < "$wrFile"

#   # curWrContent=$(cat "$wrFile")
#   # /usr/local/bin/sketchybar --set com.wrcontent label="$curWrContent"
# fi




