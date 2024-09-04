#!/bin/bash



























#apiKey=sk-r9KLZjy62T4I1X5d0NsykNHObSU6Qr81kyv5uODtE88Effyh



## curl https://api.moonshot.cn/v1/models -H "Authorization: Bearer $apiKey"


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
#kimiWrFile="/Users/didi/Documents/WeeklyReport/$prefix-kimiPolishing.wr"

# 检查文件是否存在
if [ -f "$wrFile" ]; then
  echo "文件 $wrFile 已存在。"
else
  # 创建文件
  touch "$wrFile"
  echo "文件 $wrFile 已创建。"
fi

input_text=$(osascript /Users/didi/scripts/prompt_input.applescript "addNewWork" "工作内容")

echo "$input_text" >> $wrFile
#/usr/local/bin/sketchybar --set com.weeklyreport icon="Polishing"


## file=/Users/didi/Documents/WeeklyReport/aaaa.wr
## file=$1
#content=$(cat $wrFile);

#payload=$(echo "$content" | tr -d ' \n')

#json_payload=$(cat <<EOF
#{
#    "model": "moonshot-v1-8k",
#    "messages": [
#        {"role": "system", "content": "你是 Kimi，由 Moonshot AI 提供的人工智能助手，你会为用户提供安全，有帮助，准确的回答。你更擅长中文和英文的对话。我希望你能担任软件开发人员的角色。我会提供一些关于一个Web应用需求的具体信息，而你的工作就是设计出使用Java和Kotlin,JavaScript,TypeScript,ReactNative开发安全应用程序的架构和代码。"},
#        {"role": "user", "content": "$payload <<< 对前面这段文本做周报内容优化,要求增强表达的专业性逻辑性和显示格式并对项目内容进行适当的描述展开" }
#    ],
#    "temperature": 0.7
#}
#EOF
#)


#echo $json_payload

#response=$(/usr/bin/curl -s https://api.moonshot.cn/v1/chat/completions -H "Content-Type: application/json"  -H "Authorization: Bearer $apiKey" -d "$json_payload")

## echo "------------------------"
#echo $response

## echo "------------------------"
#optWr=$(echo $response | jq '.choices[0].message.content')


## $(echo $optWr | /usr/bin/sed 's/\\n/\n/g') >> $file
#echo -e "$optWr" | /usr/bin/sed 's/\\n/\n/g' > "$kimiWrFile"

## echo "$optWr" >> $file
##
#/usr/local/bin/sketchybar --set com.weeklyreport icon="W"

#/usr/local/bin/kitty nvim $kimiWrFile


