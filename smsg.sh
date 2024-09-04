#!/bin/bash

# 你的消息作为命令行参数
message="$1"

# 使用curl发送你的消息
curl -d "$message" ntfy.sh/meetlinfengnty
