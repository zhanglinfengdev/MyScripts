#!/bin/bash

# 获取中国大陆时区的日期
date=$(LC_TIME=zh_CN.UTF-8 TZ="Asia/Shanghai" date)

# 去除日期中的空格
date_no_space=${date// /}

# 将日期写入剪贴板
echo $date_no_space | pbcopy

