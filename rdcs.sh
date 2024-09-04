#!/bin/bash

# 定义搜索的目录
SEARCH_DIR="/Users/didi/Documents/RdProfiles"

# 定义文件后缀
FILE_SUFFIX=".rd"  # 举例，你可以根据需要修改为 .log, .conf 等

find . -type f -exec echo {} \;
# 使用find命令查找指定后缀的文件，并使用ls对结果排序，取最上面的一行即最新修改的文件
# NEWEST_FILE=$(find "$SEARCH_DIR" -type f -name "*$FILE_SUFFIX" -printf "%T+ %p\n" | sort -r | head -n 1 | cut -d " " -f 2-)
# NEWEST_FILE=$(find "$SEARCH_DIR" -type f -name "*$FILE_SUFFIX" -exec stat -f "%m %N" {} \; | sort -rn | head -n 1 | cut -d " " -f 2-)
# NEWEST_FILE=$(find $SEARCH_DIR -type f -name "*$FILE_SUFFIX" -exec stat -f '%m %N' {} + | sort -rn | head -n 1)
cd /Users/didi/Documents/RdProfiles
fzf --preview='stat -f "%m %N" {}' < <(find /path/to/directory -name "*.后缀名" -type f)

NEWEST_FILE=$(fzf --preview='stat -f "%m %N" {}' < <(find "/Users/didi/Documents/RdProfiles" -name "*.rd" -type f))
# find /path/to/directory -name "*.txt" -exec ls -lt {} \; | head -n 1



if [[ -n "$NEWEST_FILE" ]]; then
    echo "最新修改的文件是: $NEWEST_FILE"
else
    echo "没有找到匹配的文件。"
fi

