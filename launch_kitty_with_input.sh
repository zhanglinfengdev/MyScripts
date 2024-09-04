#!/bin/bash

# 启动Kitty
# 如果Kitty不在默认路径，你需要指定正确的路径
open -a Kitty

# 等待一小段时间让Kitty启动
sleep 1

# 提示用户输入文本
read -p "请输入一些文本: " input_text

# 显示输入的文本
echo "你输入的文本是: $input_text"

# 你可以在这里做进一步的处理，比如将文本保存到文件或传递给其他程序

