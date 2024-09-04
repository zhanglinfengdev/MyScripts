#!/bin/bash



apiKey=sk-r9KLZjy62T4I1X5d0NsykNHObSU6Qr81kyv5uODtE88Effyh



# curl https://api.moonshot.cn/v1/models -H "Authorization: Bearer $apiKey"

# title=$(/Users/didi/scripts/launch_kitty_with_input.sh)
# 启动Kitty
# 如果Kitty不在默认路径，你需要指定正确的路径
# open -a Kitty
# input_text
# /usr/local/bin/kitty read -p "请输入一些文本: " $input_text

input_text=$(osascript /Users/didi/scripts/prompt_input.applescript "newRdProfileGuide" "需求名称" "简述" "跟版本号" "涉及到的组件" )


# # 显示输入的文本
# echo "你输入的文本是: $input_text"



if [ ! -z "$input_text" ]
then

    /Users/didi/scripts/TZ.sh
    prefix="$(pbpaste)-$input_text"
    prdFile="/Users/didi/Documents/RdProfiles/$prefix.prd"
    kimiPrdFile="/Users/didi/Documents/WeeklyReport/$prefix-kimi.prd"







    # 检查文件是否存在
    if [ -f "$prdFile" ]; then
        echo "文件 $prdFile 已存在。"
    else
        # 创建文件
        touch "$prdFile"
        echo "文件 $prdFile 已创建。"
    fi


# /usr/local/bin/sketchybar --set com.weeklyreport icon="Polishing"


# file=/Users/didi/Documents/WeeklyReport/aaaa.wr
# file=$1
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

    /usr/local/bin/kitty nvim $prdFile

fi

