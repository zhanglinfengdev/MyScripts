#!/bin/bash

# 设定拼音输入法和英语键盘的输入法标识符
PINYIN_IM="com.apple.inputmethod.SCIM.Shuangpin"
ENGLISH_IM="com.apple.keylayout.ABC"

# 获取当前输入法标识符
current_im=$(im-select)

# 切换输入法
if [ "$current_im" == "$PINYIN_IM" ]; then
  im-select $ENGLISH_IM
  im-select $ENGLISH_IM
  echo "Switched to English Keyboard."
elif [ "$current_im" == "$ENGLISH_IM" ]; then
  im-select $PINYIN_IM
  im-select $PINYIN_IM
  echo "Switched to Pinyin Input Method."
else
  echo "Current input method is neither Pinyin nor English, switching to English."
  im-select $ENGLISH_IM
fi

~/.config/skhd/scripts/updateMenuBarInputIcon.sh

