# pids="/Users/didi/.config/sketchybar/com.weeklyreport-wrpitems.dot"
# # 检查文件是否存在
# if [ -f "$wrpitemsFile" ]; then

#   # 通过 while 循环读取文件的每一行
#   while IFS= read -r line
#   do
#      itemID=$(echo $line | md5sum | awk '{print $1}')
#      /usr/local/bin/sketchybar --remove $itemID
#   done < "$wrpitemsFile"

# fi

kill -9 $(pgrep "kitty")  /dev/null 2>&1 &
