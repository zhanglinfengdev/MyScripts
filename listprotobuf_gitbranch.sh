#!/bin/bash


POPUP_OFF='/usr/local/bin/sketchybar --set com.itsproto popup.drawing=off'


pbBranchItems="/Users/didi/.config/sketchybar/com.itsproto-branchItems.dot"
# 检查文件是否存在
if [ -f "$pbBranchItems" ]; then

  # 通过 while 循环读取文件的每一行
  while IFS= read -r line
  do
     itemID=$(echo $line | md5sum | awk '{print $1}')
     /usr/local/bin/sketchybar --remove $itemID
  done < "$pbBranchItems"

fi


#!/bin/bash

its_protoHome='/Users/didi/AndroidStudioProjects/its-proto'

# 进入项目目录
cd $its_protoHome

# 拉取最新的远程分支信息
/usr/bin/git fetch --all

# 获取远程分支列表，并根据最后一次提交排序，取前十个
remoteBranches=$(git for-each-ref --sort=-committerdate refs/remotes/ --format="%(refname:lstrip=3)" | head -n 21)

# 输出分支列表
# echo "Top 10 recently updated remote branches:"
# echo "$remoteBranches"

echo '' > "$pbBranchItems"
# 循环遍历这些分支
for branch in $remoteBranches; do
  # 这里可以添加你想对每个分支执行的命令
  # echo "Processing branch: $branch"
  # 示例：打印分支的最后一次提交信息
  git log -1 $branch --pretty=format:"%H - %an, %ar : %s"

  itemID=$(echo $branch | md5sum | awk '{print $1}')
  labelTxt=$(echo "$branch" | awk '{gsub(/[ \t\n]/, ""); print}')
  /usr/local/bin/sketchybar --add item $itemID popup.com.itsproto                      \
      --set $itemID label="$labelTxt"                                                      \
      --set $itemID height=15                                                      \
      --set $itemID click_script="echo '${branch}' | pbcopy; $POPUP_OFF; /Users/didi/scripts/compilepb_branch.sh $branch"
      # --set $line label=$(echo "$line" | awk '{$1=$1};1')           \

  echo $branch >> "$pbBranchItems"

  echo ""
done





# echo '' > "$pbBranchItems"
# # 检查文件是否存在
# if [ -z "$remoteBranchs" ]; then
#   # echo "文件 $wrFile 已存在。"

#   # 通过 while 循环读取文件的每一行
#   while IFS= read -r line
#   do
#      itemID=$(echo $line | md5sum | awk '{print $1}')
#      labelTxt=$(echo "$line" | awk '{gsub(/[ \t\n]/, ""); print}')
#      /usr/local/bin/sketchybar --add item $itemID popup.com.itsproto                      \
#          --set $itemID label="$labelTxt"                                                      \
#          --set $itemID click_script="echo '${line}' | pbcopy; $POPUP_OFFWR; /Users/didi/scripts/compilepb_branch.sh $line"
#          # --set $line label=$(echo "$line" | awk '{$1=$1};1')           \

#      echo $line >> "$pbBranchItems"

#   done < "$remoteBranchs"

#   # curWrContent=$(cat "$wrFile")
#   # /usr/local/bin/sketchybar --set com.wrcontent label="$curWrContent"
# fi




