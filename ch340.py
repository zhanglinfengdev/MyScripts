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
