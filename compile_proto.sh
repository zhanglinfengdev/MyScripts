#!/bin/bash


# 检查参数
# if [ "$#" -ne 2 ]; then
#     echo "Usage: $0 <proto_source_dir> <output_java_dir>"
#     exit 1
# fi

its_proto_dir="/Users/didi/AndroidStudioProjects/its-proto"
cd $its_proto_dir
# PROTO_DIR=.
JAVA_OUT_DIR="/Users/didi/AndroidStudioProjects/its-proto/javaOut"

# 找到所有的 .proto 文件并编译
/Users/didi/.jenv/shims/java -jar /Users/didi/scripts/wire-compiler-1.8.0-jar-with-dependencies.jar  \
    --proto_path=$its_proto_dir \
    --java_out=$JAVA_OUT_DIR \
    $(find $its_proto_dir -name "*.proto" | sed "s|.*/its-proto/||")

    # $(find $its_proto_dir -name  "*.proto")

echo "Compilation complete. Java files are saved in $JAVA_OUT_DIR"
