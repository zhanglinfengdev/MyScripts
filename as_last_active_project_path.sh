#!/bin/bash

LOG_FILE="/Users/didi/active_as_project_path.log" # Optional log file
# Format as MM/DD HH:MM)
# current_time=$(TZ="Asia/Shanghai" date "+%H:%M:%S") # Ensure correct timezone if needed
echo "$current_time $@" >$LOG_FILE
echo "$@" >$LOG_FILE
