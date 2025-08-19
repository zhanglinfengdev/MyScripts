#!/usr/bin/env python3
import serial
import time
import argparse

# 串口配置
SERIAL_PORT = "/dev/ttyUSB0"  # 修改为你的串口
BAUD_RATE = 9600
DELAY = 0.2  # 按键间隔 500ms

# 指令
CMD_ON = bytes([0xA0, 0x01, 0x01, 0xA2])
CMD_OFF = bytes([0xA0, 0x01, 0x00, 0xA1])

def press_key(times=1):
    """模拟按键按下"""
    with serial.Serial(SERIAL_PORT, BAUD_RATE, timeout=1) as ser:
        for i in range(times):
            print(f"按下按键 {i+1}/{times}")
            ser.write(CMD_ON)      # 发送打开指令
            time.sleep(0.19)        # 给芯片一点响应时间
            ser.write(CMD_OFF)     # 发送关闭指令
            if i < times - 1:
                time.sleep(DELAY)  # 间隔 500ms

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="CH340 按键模拟脚本")
    parser.add_argument("times", type=int, choices=[1,2,3], help="按键次数 (1/2/3)")
    args = parser.parse_args()
    press_key(args.times)



    <D-v>
        customCommands:
  - key: "n"
    context: "localBranches"        # 指定只在本地分支页面生效
    prompts:
      - type: "input"
        title: "Enter new branch name"
        key: "branchName"
      - type: "input"
        title: "Enter branch description"
        key: "desc"
    command: |
      git checkout -b "{{.Form.branchName}}" && \
      git config branch."{{.Form.branchName}}".description "{{.Form.desc}}"
    loadingText: "Creating and editing branch..."
    description: "Create, set desc, and checkout new branch"

sk-COzBQaF3Q75pTZxWk3JfkvfxGx9yWp47xiBWa2HRZVZ2yWfl


# ~/.config/lazygit/config.yml
customCommands:
  # 这是您已经提供的用于创建新分支的命令 (保持不变)
  - key: "n"
    context: "localBranches"
    # ... (此部分内容省略)
    command: |
      git checkout -b "{{.Form.branchName}}" && \
      git config branch."{{.Form.branchName}}".description "{{.Form.desc}}"

  # 这是新的、用于覆写 commit 并应用模板的命令
  - key: 'c'
    context: 'files'
    description: 'Commit using template with branch desc prefix'
    command: |
      set -e;
      PREFIX=$(git config branch."$(git branch --show-current)".description);
      TEMPLATE_PATH=$(git config --get commit.template);
      if [ -n "$TEMPLATE_PATH" ] && [ -f "$TEMPLATE_PATH" ]; then
        if [ -n "$PREFIX" ]; then
          MSG_CONTENT="$(echo "$PREFIX: "; cat "$TEMPLATE_PATH")";
        else
          MSG_CONTENT="$(cat "$TEMPLATE_PATH")";
        fi;
        git commit --edit -m "$MSG_CONTENT";
      else
        git commit --edit -m "$PREFIX";
      fi
    loadingText: 'Opening editor...'





# --------------------
# 提交标题（必填，50字以内，建议使用类型: 简要说明）
# 常见类型: feat | fix | docs | style | refactor | perf | test | chore
#
# 示例：
# feat: 增加用户登录功能
# fix: 修复首页加载失败的 bug
# --------------------

# 提交描述（可选，换行后写更详细的说明）
# 示例：
# - 增加了 JWT 鉴权逻辑
# - 修改了 UserController 中的验证逻辑
# --------------------

# 关联 issue（可选）
# Closes #123
# --------------------



#!/bin/sh

# 获取当前分支
branch=$(git branch --show-current)

# 获取分支描述（如果有的话）
desc=$(git config branch."$branch".description)

# 如果有描述，就追加到 commit message 模板里
if [ -n "$desc" ]; then
    echo "" >> "$1"
    echo "Branch: $branch" >> "$1"
    echo "Description: $desc" >> "$1"
fi

