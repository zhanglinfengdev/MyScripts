#!/bin/bash



# export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-1.8.0_402-1/Contents/Home

# export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-11.0.22/Contents/Home
#

# 检查是否传入了参数
if [ $# -eq 0 ]; then
    echo "Usage: $0 <version>"
    exit 1
fi

# 根据参数设置JAVA_HOME
case $1 in
    8)
        export JAVA_HOME="/Users/didi/Library/Java/JavaVirtualMachines/corretto-1.8.0_402-1/Contents/Home"
        ;;
    11)
        export JAVA_HOME="/Users/didi/Library/Java/JavaVirtualMachines/corretto-11.0.22/Contents/Home"
        ;;
    17)
        export JAVA_HOME="/Users/didi/Library/Java/JavaVirtualMachines/jbr-17.0.9/Contents/Home"
        ;;
    *)
        echo "Unsupported version: $1"
        exit 2
        ;;
esac

export PATH=$JAVA_HOME/bin:$PATH

echo "Set JAVA_HOME to $JAVA_HOME"

# 为了使JAVA_HOME的变化影响到当前shell, 需要使用source命令执行此脚本
# 或者可以在这里启动一个子shell，例如运行一个Java应用程序
# java -version
