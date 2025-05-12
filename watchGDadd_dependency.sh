#!/bin/zsh

# --- Helper Functions ---

# Function to display error messages and exit
error_exit() {
  echo "❌ Error: $1" >&2
  # Optional: Add notification for errors as well
  # notify "Script Error" "$1"
  exit 1
}

# Placeholder for the notification function (adapt to your system if needed)
# Using osascript for macOS notifications
notify() {
  osascript -e "display notification \"$2\" with title \"$1\""
}

# --- Main Script Logic ---

# 1. Check arguments
# DEFAULT_SCOPE="implementation" # Define a default scope if not provided
if [ "$#" -lt 4 ] || [ "$#" -gt 5 ]; then
  echo "Usage: $0 <project_directory> <groupId> <artifactId> <version> [scope (default: $DEFAULT_SCOPE)]"
  echo "Example: $0 ~/Projects/MyAwesomeApp com.google.code.gson gson 2.9.1 implementation"
  exit 1
fi

PROJECT_DIR="$1"
PROJECT_DIR="$(/Users/didi/scripts/get_as_project_dir.sh)" # Get current AS project
GROUP_ID="$2"
ARTIFACT_ID="$3"
VERSION="$4"

# Input validation (basic)
# if [[ -z "$PROJECT_DIR" || -z "$GROUP_ID" || -z "$ARTIFACT_ID" || -z "$VERSION" || -z "$SCOPE" ]]; then
if [[ -z "$PROJECT_DIR" || -z "$GROUP_ID" || -z "$ARTIFACT_ID" || -z "$VERSION" ]]; then
  error_exit "Error: Project Directory, GroupId, ArtifactId, Version, and Scope cannot be empty."
fi
if [ ! -d "$PROJECT_DIR" ]; then
  error_exit "Error: Project directory '$PROJECT_DIR' not found or is not a directory."
fi
# Basic validation for common invalid chars in dependency parts
# if [[ "$GROUP_ID" =~ [[:space:]\'\"] || "$ARTIFACT_ID" =~ [[:space:]\'\"] || "$VERSION" =~ [[:space:]\'\"] || "$SCOPE" =~ [[:space:]\'\"] ]]; then
if [[ "$GROUP_ID" =~ [[:space:]\'\"] || "$ARTIFACT_ID" =~ [[:space:]\'\"] || "$VERSION" =~ [[:space:]\'\"] ]]; then
  error_exit "Error: GroupId, ArtifactId, Version, Scope should not contain spaces, single quotes, or double quotes."
fi

# Escape potential special characters for regex/sed later
ESCAPED_GROUP_ID=$(echo "$GROUP_ID" | sed 's/\./\\./g')
ESCAPED_ARTIFACT_ID=$(echo "$ARTIFACT_ID" | sed 's/\./\\./g')

echo "🔍 Searching for build files in: $PROJECT_DIR"
echo "🎯 Targeting Dependency: Group='$GROUP_ID', Artifact='$ARTIFACT_ID', Version='$VERSION'"
echo "---"
echo "$ARTIFACT_ID:$VERSION" | pbcopy

# 2. Find all build.gradle or build.gradle.kts files recursively
# build_files=()
# while IFS= read -r file; do
#   build_files+=("$file")
# done < <(find "$PROJECT_DIR" \( -name "build.gradle" -o -name "build.gradle.kts" \) -type f)
build_files=( "$PROJECT_DIR"/**/(build.gradle|build.gradle.kts)(.N) )

if [ ${#build_files[@]} -eq 0 ]; then
  error_exit "No build.gradle or build.gradle.kts files found within '$PROJECT_DIR'."
fi

echo "✅ Found ${#build_files[@]} build file(s):"
printf "   %s\n" "${build_files[@]}"
echo "---"

# 3. Process each build file
updated_count=0
not_found_count=0
error_count=0

# Ensure temporary file is cleaned up on script exit (including errors)
trap 'rm -f "$TEMP_FILE"' EXIT

for BUILD_FILE in "${build_files[@]}"; do
  echo "📄 Processing File: $BUILD_FILE"

  BUILD_FILE_TYPE=""
  INDENT="    "
  NEW_DEPENDENCY_STRING_NO_INDENT=""
  NEW_DEPENDENCY_STRING_WITH_INDENT=""
  EXISTING_DEP_PATTERN=""
  EXISTING_DEP_REPLACE_PATTERN="" # Renamed for clarity

  # Determine file type and format strings/patterns
  if [[ "$BUILD_FILE" == *.kts ]]; then
    BUILD_FILE_TYPE="kotlin"
    NEW_DEPENDENCY_STRING_NO_INDENT="${SCOPE}(\"$GROUP_ID:$ARTIFACT_ID:$VERSION\")"
    NEW_DEPENDENCY_STRING_WITH_INDENT="${INDENT}${NEW_DEPENDENCY_STRING_NO_INDENT}"
    EXISTING_DEP_PATTERN="[\"']${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^\"']*[\"']"
    EXISTING_DEP_REPLACE_PATTERN="[\"']${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^\"']*[\"']"
  elif [[ "$BUILD_FILE" == *.gradle ]]; then
    BUILD_FILE_TYPE="groovy"
    NEW_DEPENDENCY_STRING_NO_INDENT="${SCOPE} '$GROUP_ID:$ARTIFACT_ID:$VERSION'"
    NEW_DEPENDENCY_STRING_WITH_INDENT="${INDENT}${NEW_DEPENDENCY_STRING_NO_INDENT}"
    EXISTING_DEP_PATTERN="[\"']${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^\"']*[\"']"
    EXISTING_DEP_REPLACE_PATTERN="[\"']${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^\"']*[\"']"
  else
    echo "⚠️ Skipping file with unknown extension: $BUILD_FILE"
    continue
  fi

  # Basic sanity check for dependencies block
  if ! grep -q -E '^[[:space:]]*dependencies[[:space:]]*\{' "$BUILD_FILE"; then
    echo "ℹ️  No 'dependencies {' block found in $BUILD_FILE. Skipping dependency check for this file."
    continue
  fi

  # Check if the dependency already exists using the simpler pattern
  if grep -E -q -- "$EXISTING_DEP_PATTERN" "$BUILD_FILE"; then
    echo "✅ Found existing dependency for $GROUP_ID:$ARTIFACT_ID with scope $SCOPE."
    echo "   Attempting to update line in $BUILD_FILE..."

    pattern="[\"']$GROUP_ID:$ARTIFACT_ID:[^'\"]+[\"']"
    replacement="'$GROUP_ID:$ARTIFACT_ID:$VERSION'"

    echo "   patter: $pattern , replacement: $replacement"
    # 使用 sed 进行替换（修改原文件，使用扩展正则）
    sed -E -i '' "s/${pattern}/${replacement}/g" "$BUILD_FILE"

  else
    # Dependency does NOT exist in this file
    echo "ℹ️  Dependency $GROUP_ID:$ARTIFACT_ID ($SCOPE) not found in $BUILD_FILE."
    ((not_found_count++))
  fi
  echo "---" # Separator between files
done

# Clean exit removes the trap
trap - EXIT

# 4. Final Summary
echo "====== Summary ======"
echo "Processed ${#build_files[@]} build file(s)."
echo "✅ Successfully updated: $updated_count file(s)."
echo "ℹ️ Dependency not found (or not updated): $not_found_count file(s)."
echo "❌ Errors encountered (updates skipped/failed): $error_count file(s)."

if [ $error_count -gt 0 ]; then
  notify "Script Finished with Errors" "Updated $updated_count, Not Found $not_found_count, Errors $error_count dependencies."
  exit 1
elif [ $updated_count -gt 0 ]; then
  notify "Script Finished Successfully" "Updated $updated_count dependencies in $PROJECT_DIR."
  exit 0
else
  notify "Script Finished" "No matching dependencies found to update in $PROJECT_DIR."
  exit 0
fi

#!/bin/zsh

# 参数说明：
# $1 = 目标文件路径
# $2 = 要匹配的正则表达式（使用sed支持的格式）
# $3 = 替换后的内容

if [[ $# -ne 3 ]]; then
  echo "用法: $0 文件路径 匹配模式 替换内容"
  exit 1
fi
