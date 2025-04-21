#!/bin/bash

# 脚本：获取 Android Studio 最近打开的项目目录 (适配 V2 结构)
# 用途：优先查找 'lastOpenedProject' 选项，如果找不到再尝试解析项目列表。

# --- 配置区域 ---
# 在下面的 search_paths 数组中，添加或修改为您系统中正确的 recentProjects.xml 文件路径。
# 使用 "$HOME" 代替 "/Users/your_username" 以获得更好的兼容性。
# 将您找到的最常用的那个版本的路径放在最前面，以便优先查找。

search_paths=(
  # !!!===> 在这里添加您系统上正确的路径! 例如: <===!!!
  # "$HOME/Library/Application Support/Google/AndroidStudio2024.3/options/recentProjects.xml"
  # "$HOME/Library/Application Support/Google/AndroidStudio2024.2/options/recentProjects.xml"

  # # --- 您之前找到的其他路径 ---
  # "$HOME/Library/Application Support/Huawei/DevEcoStudio3.1/options/recentProjects.xml"
  # "$HOME/Library/Application Support/JetBrains/IntelliJIdea2023.2/options/recentProjects.xml"
  # "$HOME/Library/Application Support/JetBrains/IntelliJIdea2023.1/options/recentProjects.xml"

  "/Users/linfeng/Library/Application\ Support/Google/AndroidStudio2024.3/options/recentProjects.xml"
  "/Users/linfeng/Library/Application\ Support/Google/AndroidStudio2024.2/options/recentProjects.xml"
  # --- 通用但可能不匹配的路径 ---
  # "$HOME/Library/Application Support/Google/AndroidStudio*/options/recentProjects.xml"
  # "$HOME/Library/Preferences/AndroidStudio*/options/recentProjects.xml"

)
# --- 配置结束 ---

xml_file=""

# 查找存在的 recentProjects.xml 文件
for potential_path in "${search_paths[@]}"; do
  # 展开路径中的 ~ 和 $HOME
  eval expanded_path="$potential_path"
  # 检查文件是否存在且可读
  if [[ -f "$expanded_path" && -r "$expanded_path" ]]; then
    xml_file="$expanded_path"
    # Uncomment the next line for debugging
    # echo "找到文件: $xml_file" >&2
    break # 找到第一个就停止
  fi
done

# 检查是否找到了文件
if [[ -z "$xml_file" ]]; then
  echo "错误：未能找到合适的 'recentProjects.xml' 文件。" >&2
  echo "请在脚本的 'search_paths' 数组中添加或确认您的精确路径。" >&2
  exit 1
fi

# 检查 xmllint 是否可用
if ! command -v xmllint &> /dev/null; then
    echo "错误: 'xmllint' 命令未找到。" >&2
    echo "请先安装 xmllint。在 macOS 上，可以尝试 'brew install libxml2' 或 'xcode-select --install'。" >&2
    exit 1
fi

# --- 优先尝试直接获取 lastOpenedProject ---
xpath_last_opened="//component[@name='RecentProjectsManager']/option[@name='lastOpenedProject']/@value"
last_project_path=$(xmllint --xpath "$xpath_last_opened" "$xml_file" 2>/dev/null | awk -F'"' '{print $2}')

# 检查是否通过 shortcut 获取到了路径
if [[ -n "$last_project_path" ]]; then
  # 处理路径中的 $USER_HOME$ 变量
  resolved_path=$(echo "$last_project_path" | sed "s|\$USER_HOME\$|$HOME|g")
  echo "$resolved_path"
  exit 0
fi

# --- 如果没有 lastOpenedProject，则回退到解析 map (适配您提供的XML结构) ---
# 这个 XPath 获取 map 中每个 entry 的 key (项目路径)
xpath_map_keys="//component[@name='RecentProjectsManager']/option[@name='additionalInfo']/map/entry/@key"
# 这个 XPath 获取每个 entry 内部最新的时间戳 (尝试 activationTimestamp 或 projectOpenTimestamp)
xpath_map_timestamps="//component[@name='RecentProjectsManager']/option[@name='additionalInfo']/map/entry/value/RecentProjectMetaInfo/option[@name='activationTimestamp' or @name='projectOpenTimestamp']/@value"

# 注意：直接用 XPath 匹配 Key 和 Value 并排序比较复杂。
# 一个简化的方法是假设 map 中的第一个条目（如果存在）可能是最新的，
# 或者我们可以提取所有的 key，然后只取第一个。
# 对于您提供的 XML 结构，更可靠的是 *仍然依赖* lastOpenedProject (如果它总是存在的话)
# 如果 lastOpenedProject 不可靠或不存在，解析 map 需要更复杂的脚本。

# 由于我们已经优先处理了 lastOpenedProject，如果代码执行到这里，
# 说明那个选项不存在，或者文件结构非常不同。
# 我们可以尝试提取 map 中的 *第一个* key 作为备选方案。

first_key_in_map=$(xmllint --xpath "($xpath_map_keys)[1]" "$xml_file" 2>/dev/null | awk -F'"' '{print $2}')

if [[ -n "$first_key_in_map" ]]; then
    echo "警告：未找到 'lastOpenedProject' 选项，尝试使用 map 中的第一个项目。" >&2
    resolved_path=$(echo "$first_key_in_map" | sed "s|\$USER_HOME\$|$HOME|g")
    echo "$resolved_path"
    exit 0
fi


echo "错误：无法从文件中找到 'lastOpenedProject' 选项，也无法解析 'additionalInfo' map 中的项目路径。" >&2
echo "请检查 XML 文件结构是否符合预期: $xml_file" >&2
exit 1





