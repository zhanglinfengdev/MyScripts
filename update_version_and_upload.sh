#!/bin/zsh

# Requires Bash 4.0+ for associative arrays
# export JAVA_HOME=/usr/local/Cellar/openjdk@11/11.0.25/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-15.0.2/Contents/Home
# export JAVA_HOME=/Users/didi/Library/Java/JavaVirtualMachines/corretto-17.0.14/Contents/Home


# --- Configuration Maps ---
declare -A project_dirs
declare -A version_keys   # Key for the version property (e.g., "version")
declare -A gradle_configs # How to execute gradle ('wrapper', 'global', 'sdk:X.Y', '/path/to/gradle')
declare -A gradle_jvm # How to execute gradle ('wrapper', 'global', 'sdk:X.Y', '/path/to/gradle')
# NEW: Keys for Group and Artifact ID properties in gradle.properties
declare -A group_keys       # Key for the GROUP property (e.g., "GROUP")
declare -A artifact_id_keys # Key for the ARTIFACT_ID property (e.g., "ARTIFACT_ID")

# --- Default Property Keys (used if not specified per-project) ---
DEFAULT_VERSION_KEY="VERSION" # Changed default assumption based on user's last example
DEFAULT_GROUP_KEY="GROUP_ID"
DEFAULT_ARTIFACT_ID_KEY="ARTIFACT_ID"

# === ADD/MODIFY YOUR CONFIGURATIONS BELOW ===

project_dirs["sdk"]="/Users/didi/AndroidStudioProjects/MapFlowView"
version_keys["sdk"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["sdk"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["sdk"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["sdk"]="wrapper"

project_dirs["sync-trip-sdk"]="/Users/didi/AndroidStudioProjects/DiDiSyncTripSDK"
version_keys["sync-trip-sdk"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["sync-trip-sdk"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["sync-trip-sdk"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["sync-trip-sdk"]="wrapper"

project_dirs["address"]="/Users/didi/AndroidStudioProjects/poi_selector"
version_keys["address"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["address"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["address"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["address"]="wrapper"

project_dirs["mappoiselect"]="/Users/didi/AndroidStudioProjects/map_poi_select"
version_keys["mappoiselect"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["mappoiselect"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["mappoiselect"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["mappoiselect"]="/Users/didi/.gradle/wrapper/dists/gradle-6.5-all/4061lg9ykbxtf8xnyo6cpg8pp/gradle-6.5"
gradle_jvm["mappoiselect"]="/Users/didi/Library/Java/JavaVirtualMachines/corretto-1.8.0_442/Contents/Home"

project_dirs["andoid_common_poi_selecter"]="/Users/didi/AndroidStudioProjects/andoid_common_poi_selecter"
version_keys["andoid_common_poi_selecter"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["andoid_common_poi_selecter"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["andoid_common_poi_selecter"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["andoid_common_poi_selecter"]="wrapper"

project_dirs["mapelementdrawsdk"]="/Users/didi/AndroidStudioProjects/mapelementdrawsdk"
version_keys["mapelementdrawsdk"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["mapelementdrawsdk"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["mapelementdrawsdk"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["mapelementdrawsdk"]="wrapper"

project_dirs["poi_base_lib"]="/Users/didi/AndroidStudioProjects/poi_base_lib"
version_keys["poi_base_lib"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["poi_base_lib"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["poi_base_lib"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["poi_base_lib"]="wrapper"

project_dirs["PsgRouteChooserSdk"]="/Users/didi/AndroidStudioProjects/PsgRouteChooserSdk"
version_keys["PsgRouteChooserSdk"]="VERSION"         # Must match the key in projectA's gradle.properties
group_keys["PsgRouteChooserSdk"]="GROUP_ID"          # Must match the key in projectA's gradle.properties
artifact_id_keys["PsgRouteChooserSdk"]="ARTIFACT_ID" # Must match the key in projectA's gradle.properties
gradle_configs["PsgRouteChooserSdk"]="wrapper"

#
# project_dirs["libraryB"]="/Users/your_username/libs/libraryB"
# # libraryB uses defaults for keys (VERSION, GROUP, ARTIFACT_ID assumed)
# gradle_configs["libraryB"]="sdk:8.7"
#
# project_dirs["appC"]="/path/to/another/projectC"
# version_keys["appC"]="appVersion" # Custom version key
# # appC uses defaults for GROUP and ARTIFACT_ID keys
# gradle_configs["appC"]="global"

# === END OF CONFIGURATIONS ===

# --- Output File for Dependencies ---
DEPENDENCY_OUTPUT_FILE="/Users/didi/generated_dependencies.properties"

# --- Function: Print Usage ---
usage() {
  echo "用法: $0 <config_name1> [config_name2] ..."
  echo "读取 gradle.properties 中的 GROUP, ARTIFACT_ID, VERSION, 更新 VERSION 并附加时间戳,"
  echo "然后运行 uploadArchives，并将成功模块的坐标写入 $DEPENDENCY_OUTPUT_FILE。"
  echo "不再需要 printPublicationInfo Gradle 任务。"
  echo ""
  echo "Gradle 配置 (gradle_configs): 'wrapper', 'global', 'sdk:<版本>', '/path/to/gradle'"
  echo "属性键配置: version_keys, group_keys, artifact_id_keys (如果省略则使用默认值)"
  echo ""
  echo "可用配置名称:"
  for name in "${!project_dirs[@]}"; do
    local vk=${version_keys[$name]:-$DEFAULT_VERSION_KEY}
    local gk=${group_keys[$name]:-$DEFAULT_GROUP_KEY}
    local ak=${artifact_id_keys[$name]:-$DEFAULT_ARTIFACT_ID_KEY}
    local config_val=${gradle_configs[$name]:-"wrapper"}
    local config_desc=""
    # Determine description based on config value (simplified for brevity)
    if [[ "$config_val" == "wrapper" ]]; then
      config_desc="Wrapper"
    elif [[ "$config_val" == "global" ]]; then
      config_desc="Global (PATH)"
    elif [[ "$config_val" == sdk:* ]]; then
      config_desc="Global (SDKMAN ${config_val#sdk:})"
    elif [[ "$config_val" == /* ]] || [[ "$config_val" == ~* ]]; then
      config_desc="指定路径"
    else config_desc="未知"; fi

    echo "  - $name (路径: ${project_dirs[$name]}, 键: G=$gk, A=$ak, V=$vk, Gradle: $config_desc)"
  done
  exit 1
}

# --- Function: Print Error / Info ---
error_msg() { echo "错误 [$1]: $2" >&2; }
info_msg() { echo "信息 [$1]: $2"; }

# --- Main Logic ---

if [ $# -eq 0 ]; then
  error_msg "脚本" "请至少提供一个配置名称。"
  usage
fi

# Initialize/Clear output file
echo "# Auto-generated dependency info on $(date +"%Y-%m-%d %H:%M:%S %Z")" >"$DEPENDENCY_OUTPUT_FILE"
echo "# Format: GROUP, ARTIFACT_ID, VERSION_NAME for successfully uploaded modules" >>"$DEPENDENCY_OUTPUT_FILE"
echo "# Read directly from gradle.properties, VERSION_NAME includes timestamp" >>"$DEPENDENCY_OUTPUT_FILE"
echo "" >>"$DEPENDENCY_OUTPUT_FILE"

echo "开始批量处理指定的配置..."
ORIGINAL_DIR=$(pwd)
overall_success=true

for config_name in "$@"; do
  echo "--------------------------------------------------"
  info_msg "$config_name" "正在处理..."
  config_failed=false
  gradle_command=""
  gradle_command_source_info=""

  # 1. Look up configuration details
  if [[  -z project_dirs["$config_name"] ]]; then
    error_msg "$config_name" "未找到项目目录配置。"+$config_name
    overall_success=false
    config_failed=true
    continue
  fi


  PROJECT_DIR=${project_dirs["$config_name"]}
  # Get property keys, using defaults if not specified for the config
  version_key_prop=${version_keys["$config_name"]:-"$DEFAULT_VERSION_KEY"}
  group_key_prop=${group_keys["$config_name"]:-"$DEFAULT_GROUP_KEY"}
  artifact_id_key_prop=${artifact_id_keys["$config_name"]:-"$DEFAULT_ARTIFACT_ID_KEY"}
  gradle_config_value=${gradle_configs["$config_name"]:-"wrapper"}
  gradle_jvm_home=${gradle_jvm["$config_name"]:-"$JAVA_HOME"}

  if [ ! -d "$PROJECT_DIR" ]; then
    error_msg "$config_name" "工程目录 '$PROJECT_DIR' 不存在。"
    overall_success=false
    config_failed=true
    continue
  fi
  info_msg "$config_name" "工程目录: $PROJECT_DIR"
  info_msg "$config_name" "属性键: Version=$version_key_prop, Group=$group_key_prop, ArtifactID=$artifact_id_key_prop"
  info_msg "$config_name" "请求的 Gradle 配置: $gradle_config_value"

  # --- PRE-CHECKS: Determine and Validate Gradle Command (Logic unchanged) ---
  # (Using case statement as before to determine $gradle_command and $gradle_command_source_info)
  case "$gradle_config_value" in
  wrapper)
    wrapper_path="$PROJECT_DIR/gradlew"
    if [ ! -f "$wrapper_path" ]; then
      error_msg "$config_name" "'$wrapper_path' 未找到。"
      overall_success=false
      config_failed=true
      continue
    fi
    gradle_command="$PROJECT_DIR/gradlew"
    gradle_command_source_info="Wrapper ($gradle_command)"
    ;;
  global)
    if command -v gradle &>/dev/null; then
      gradle_command="gradle"
      gradle_command_path=$(command -v gradle)
      gradle_command_source_info="Global (PATH at $gradle_command_path)"
    else
      error_msg "$config_name" "'gradle' 命令未在 PATH 中找到。"
      overall_success=false
      config_failed=true
      continue
    fi
    ;;
  sdk:*)
    specific_version=${gradle_config_value#sdk:}
    if [ -z "$specific_version" ]; then
      error_msg "$config_name" "'sdk:' 后面缺少版本号。"
      overall_success=false
      config_failed=true
      continue
    fi
    eval expanded_home_path="~"
    sdk_path="$expanded_home_path/.sdkman/candidates/gradle/$specific_version/bin/gradle"
    if [ -f "$sdk_path" ] && [ -x "$sdk_path" ]; then
      gradle_command="$sdk_path"
      gradle_command_source_info="Global (SDKMAN Version $specific_version)"
    else
      error_msg "$config_name" "SDKMAN Gradle '$specific_version' 未在 '$sdk_path' 找到。"
      overall_success=false
      config_failed=true
      continue
    fi
    ;;
  /* | ~*)
    eval expanded_gradle_path="$gradle_config_value"
    if [ -f "$expanded_gradle_path/bin/gradle" ] && [ -x "$expanded_gradle_path/bin/gradle" ]; then
      if [ -f gradle_jvm_home]; then
        export JAVA_HOME="$gradle_jvm_home"
      fi
        gradle_command="$expanded_gradle_path/bin/gradle"
        gradle_command_source_info="指定路径 ($expanded_gradle_path)"
    else
      error_msg "$config_name" "指定路径 '$expanded_gradle_path' 未找到或不可执行。"
      overall_success=false
      config_failed=true
      continue
    fi
    ;;
  *)
    error_msg "$config_name" "无效 Gradle 配置 '$gradle_config_value'。"
    overall_success=false
    config_failed=true
    continue
    ;;
  esac
  info_msg "$config_name" "将使用的 Gradle 命令来源: $gradle_command_source_info"
  # --- END PRE-CHECKS ---

  # 2. Locate and Read gradle.properties
  PROPERTIES_FILE="$PROJECT_DIR/$config_name/gradle.properties"
  info_msg "$config_name" "正在读取属性文件: $PROPERTIES_FILE"
  if [ ! -f "$PROPERTIES_FILE" ]; then
    error_msg "$config_name" "属性文件 '$PROPERTIES_FILE' 未找到。"
    overall_success=false
    config_failed=true
    continue
  fi

  # Read required values BEFORE modification
  info_msg "$config_name" "正在读取属性: $group_key_prop, $artifact_id_key_prop, $version_key_prop"
  GROUP_LINE=$(grep "^${group_key_prop}=" "$PROPERTIES_FILE")
  ARTIFACT_ID_LINE=$(grep "^${artifact_id_key_prop}=" "$PROPERTIES_FILE")
  VERSION_LINE=$(grep "^${version_key_prop}=" "$PROPERTIES_FILE")

  # Validate all lines were found
  if [ -z "$GROUP_LINE" ]; then
    error_msg "$config_name" "未找到键 '$group_key_prop'"
    overall_success=false
    config_failed=true
    continue
  fi
  if [ -z "$ARTIFACT_ID_LINE" ]; then
    error_msg "$config_name" "未找到键 '$artifact_id_key_prop'"
    overall_success=false
    config_failed=true
    continue
  fi
  if [ -z "$VERSION_LINE" ]; then
    error_msg "$config_name" "未找到键 '$version_key_prop'"
    overall_success=false
    config_failed=true
    continue
  fi

  # Extract values
  GROUP_VAL=$(echo "$GROUP_LINE" | cut -d'=' -f2- | xargs)
  ARTIFACT_ID_VAL=$(echo "$ARTIFACT_ID_LINE" | cut -d'=' -f2- | xargs)
  BASE_VERSION=$(echo "$VERSION_LINE" | cut -d'=' -f2- | xargs)

  # Validate extracted values are not empty
  if [ -z "$GROUP_VAL" ]; then
    error_msg "$config_name" "键 '$group_key_prop' 值为空"
    overall_success=false
    config_failed=true
    continue
  fi
  if [ -z "$ARTIFACT_ID_VAL" ]; then
    error_msg "$config_name" "键 '$artifact_id_key_prop' 值为空"
    overall_success=false
    config_failed=true
    continue
  fi
  if [ -z "$BASE_VERSION" ]; then
    error_msg "$config_name" "键 '$version_key_prop' 值为空"
    overall_success=false
    config_failed=true
    continue
  fi

  info_msg "$config_name" "读取值: GROUP=$GROUP_VAL, ARTIFACT_ID=$ARTIFACT_ID_VAL, BASE_VERSION=$BASE_VERSION"

  # 3. Generate timestamp and new version number
  TIMESTAMP=$(date +'%Y%m%d%H%M%S')
  # NEW_VERSION="${BASE_VERSION}-${TIMESTAMP}"
  # info_msg "$config_name" "生成的新版本号 (VERSION_NAME): $NEW_VERSION"

  # 3.1 Define the regex to match a version string ending specifically
  #    with a hyphen followed by exactly 14 digits (YYYYMMDDHHMMSS).
  #    - (.*) captures the part *before* the hyphen and timestamp (Group 1)
  #    - - matches the literal hyphen
  #    - ([0-9]{14}) captures exactly 14 digits (Group 2)
  #    - $ anchors the match to the end of the string
  TIMESTAMP_REGEX='(.*)-([0-9]{14})$'

  # # 3.3 Check if BASE_VERSION matches the pattern
  # if [[ "$BASE_VERSION" =~ $TIMESTAMP_REGEX ]]; then
  #   # Pattern matched! BASE_VERSION ends with the timestamp format.
  #   # Extract the part *before* the hyphen using the capture group BASH_REMATCH[1].
  #   BASE_PART="${BASH_REMATCH[1]}"
  #   # Construct the NEW_VERSION by replacing the old timestamp with the new one.
  #   NEW_VERSION="${BASE_PART}-${TIMESTAMP}"
  #   echo "  -> Found existing timestamp format at the end. Updating timestamp."
  # else
  #   # Pattern did not match. BASE_VERSION does not end with "-YYYYMMDDHHMMSS".
  #   # Construct the NEW_VERSION by simply appending the new timestamp.
  #   NEW_VERSION="${BASE_VERSION}-${TIMESTAMP}"
  #   echo "  -> No existing timestamp format found at the end. Appending timestamp."
  # fi


  TIMESTAMP=$(date +'%Y%m%d%H%M%S')

  # 使用正则判断是否以 "-14位数字" 结尾
  if [[ "$BASE_VERSION" =~ -[0-9]{14}$ ]]; then
    # 若包含旧时间戳则替换
    NEW_VERSION="${BASE_VERSION%-*}-${TIMESTAMP}"
  else
    # 若无时间戳则追加
    NEW_VERSION="${BASE_VERSION}-${TIMESTAMP}"
  fi








  # 4. Update ONLY the version in gradle.properties file
  info_msg "$config_name" "正在更新 '$PROPERTIES_FILE' 中的 '$version_key_prop'..."
  sed -i '' "s|^${version_key_prop}=.*|${version_key_prop}=${NEW_VERSION}|" "$PROPERTIES_FILE"
  if [ $? -ne 0 ]; then
    error_msg "$config_name" "更新 '$PROPERTIES_FILE' 失败。"
    overall_success=false
    config_failed=true
    continue
  fi
  info_msg "$config_name" "属性文件更新成功。"

  # 5. Change Directory and Execute Gradle Upload Task
  info_msg "$config_name" "切换到工程目录: $PROJECT_DIR"
  cd "$PROJECT_DIR"
  if [ $? -ne 0 ]; then
    error_msg "$config_name" "无法切换到目录 '$PROJECT_DIR'"
    overall_success=false
    config_failed=true
    cd "$ORIGINAL_DIR" || echo "警告:无法切回"
    continue
  fi

  # If using wrapper, check executable permission now (Logic unchanged)
  if [[ "$gradle_config_value" == "wrapper" ]] && [[ ! -x "$gradle_command" ]]; then
    info_msg "$config_name" "警告: '$gradle_command' 不可执行。尝试添加权限..."
    chmod +x "$gradle_command"
    if [ $? -ne 0 ]; then
      error_msg "$config_name" "无法为 '$gradle_command' 添加权限。"
      overall_success=false
      config_failed=true
      cd "$ORIGINAL_DIR" || echo "警告:无法切回"
      continue
    fi
  fi

  # Execute uploadArchives
  info_msg "$config_name" "正在执行 '$gradle_command uploadArchives' 任务..."
  info_msg ">>>:${config_name}:uploadArchives"

  "$gradle_command" ":${config_name}:uploadArchives"
  UPLOAD_EXIT_CODE=$?

  # 6. If upload succeeded, write dependency info using NEW_VERSION
  if [ $UPLOAD_EXIT_CODE -eq 0 ]; then
    info_msg "$config_name" "Gradle 任务 'uploadArchives' 执行成功。"
    info_msg "$config_name" "写入依赖信息到 $DEPENDENCY_OUTPUT_FILE"
    # Use the values read earlier, but importantly use NEW_VERSION for the version name
    echo "# Configuration: $config_name (Gradle Source: $gradle_command_source_info)" >>"$DEPENDENCY_OUTPUT_FILE"
    echo "GROUP=$GROUP_VAL" >>"$DEPENDENCY_OUTPUT_FILE"
    echo "ARTIFACT_ID=$ARTIFACT_ID_VAL" >>"$DEPENDENCY_OUTPUT_FILE"
    echo "VERSION_NAME=$NEW_VERSION" >>"$DEPENDENCY_OUTPUT_FILE" # Write the generated version
    echo "" >>"$DEPENDENCY_OUTPUT_FILE"
  else
    error_msg "$config_name" "Gradle 任务 'uploadArchives' 执行失败 (退出码: $UPLOAD_EXIT_CODE)。跳过依赖信息写入。"
    overall_success=false
    config_failed=true
    # Attempt to revert the version change? Maybe too complex for this script.
    # info_msg "$config_name" "注意: uploadArchives 失败，但 gradle.properties 中的版本已被修改为 $NEW_VERSION"
  fi

  # 7. Go back to the original directory
  info_msg "$config_name" "处理完成，切换回原始目录..."
  cd "$ORIGINAL_DIR" || echo "警告 [$config_name]: 无法切换回原始目录 '$ORIGINAL_DIR'"

done # End loop through config names

echo "--------------------------------------------------"
# Final status report
if $overall_success; then
  echo "所有请求的配置处理完成。依赖信息已写入 '$DEPENDENCY_OUTPUT_FILE' (仅包含成功的模块)。"
  exit 0
else
  echo "部分或全部配置处理失败。请检查上面的错误信息。'$DEPENDENCY_OUTPUT_FILE' 可能不完整。"
  exit 1
fi
