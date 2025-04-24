#!/bin/zsh

# Script Function: Finds Gradle build files (.gradle/.kts) in a project directory
#                  and updates the version number of a specific dependency
#                  (groupId:artifactId) IN-PLACE using sed, preserving scope
#                  and quoting style.
#                  WARNING: Modifies files directly. Assumes Git or backups exist.

# --- Strict Mode & Options ---
set -euo pipefail # Exit on error, unset var, pipe failure

# --- Helper Functions ---

# Function to display error messages and exit
error_exit() {
  echo "❌ Error: $1" >&2
  exit 1
}

# Notification function (optional, checks for osascript)
notify() {
  local title="$1"
  local message="$2"
  if command -v osascript >/dev/null 2>&1; then
    osascript -e "display notification \"${message}\" with title \"${title}\"" &>/dev/null || true
  else
    echo "ℹ️ Notification: ${title} - ${message} (osascript not found)"
  fi
}

# --- Main Script Logic ---

# 1. Check Arguments (Requires 4)
if [ "$#" -ne 4 ]; then
  echo "Usage: $0 <project_directory> <groupId> <artifactId> <new_version>"
  echo "Example: $0 ~/Projects/MyAwesomeApp com.google.code.gson gson 2.9.1"
  exit 1
fi

PROJECT_DIR="$1"
GROUP_ID="$2"
ARTIFACT_ID="$3"
NEW_VERSION="$4"

# 2. Input Validation
if [[ -z "$PROJECT_DIR" || -z "$GROUP_ID" || -z "$ARTIFACT_ID" || -z "$NEW_VERSION" ]]; then
  error_exit "Project Directory, GroupId, ArtifactId, and New Version cannot be empty."
fi
if [ ! -d "$PROJECT_DIR" ]; then
  error_exit "Project directory '$PROJECT_DIR' not found or is not a directory."
fi
# Basic validation for common invalid chars
if [[ "$GROUP_ID" =~ [[:space:]\'\"] || "$ARTIFACT_ID" =~ [[:space:]\'\"] ]]; then
  error_exit "GroupId and ArtifactId should not contain spaces, single quotes, or double quotes."
fi
# Basic version validation
if ! [[ "$NEW_VERSION" =~ ^[a-zA-Z0-9._+-]+$ ]]; then
   error_exit "New Version '$NEW_VERSION' contains potentially invalid characters."
fi

# Escape GroupId and ArtifactId for regex usage (dots are special in regex)
# Using Zsh parameter expansion for efficiency
ESCAPED_GROUP_ID=${GROUP_ID//./\\.}
ESCAPED_ARTIFACT_ID=${ARTIFACT_ID//./\\.}
# Version doesn't usually need escaping in the replacement part, but escape for sed pattern if needed
ESCAPED_NEW_VERSION=${NEW_VERSION//&/\\&} # Escape & for replacement
ESCAPED_NEW_VERSION=${ESCAPED_NEW_VERSION//\//\\/} # Escape / for replacement (if using / as delimiter)

echo "🔍 Searching for build files in: $PROJECT_DIR"
echo "🎯 Targeting Dependency: Group='$GROUP_ID', Artifact='$ARTIFACT_ID', New Version='$NEW_VERSION'"
echo "⚠️ WARNING: Modifying files directly in-place!"
echo "---"

# 3. Find all build.gradle or build.gradle.kts files recursively
build_files=( "$PROJECT_DIR"/**/(build.gradle|build.gradle.kts)(.N) )

if [ ${#build_files[@]} -eq 0 ]; then
  notify "Script Info" "No build.gradle or build.gradle.kts files found within '$PROJECT_DIR'."
  echo "ℹ️ No build.gradle or build.gradle.kts files found within '$PROJECT_DIR'."
  exit 0 # Nothing to do
fi

echo "✅ Found ${#build_files[@]} build file(s):"
printf "   %s\n" "${build_files[@]}"
echo "---"

# 4. Process each build file using sed
processed_count=0
attempted_updates=0
not_found_count=0
error_count=0

# Define the core pattern and replacement for sed
# Pattern captures: (1: scope+space), (2: quote), (3: old_version), (4: quote matching 2)
# Note the careful quoting to insert shell vars into the sed script
# Using '#' as delimiter for sed's 's' command to avoid clash with '/' in versions
SED_PATTERN="s#\([^[:space:]]\+[[:space:]]*\)\(['\"]\)${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^'\"]\+\(\2\)#\1\2${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:${ESCAPED_NEW_VERSION}\3#"
GREP_PATTERN="['\"]${ESCAPED_GROUP_ID}:${ESCAPED_ARTIFACT_ID}:[^'\"]+['\"]" # Simpler pattern just to check existence

for BUILD_FILE in "${build_files[@]}"; do
  ((processed_count++))
  echo "📄 Processing File ($processed_count/${#build_files[@]}): $BUILD_FILE"

  # Check if the dependency seems to exist in the file first (optional, but good for reporting)
  if grep -q -E "$GREP_PATTERN" "$BUILD_FILE"; then
    echo "   Found potential dependency line(s). Attempting in-place update..."
    # Use sed with -i '' for in-place editing without backup (macOS/BSD style)
    # For GNU sed, just -i is needed. Adding '' makes it portable.
    if sed -E -i '' "$SED_PATTERN" "$BUILD_FILE"; then
      # sed exit code 0 means command ran, but doesn't guarantee a change was made
      # (e.g., if the version was already correct)
      echo "   ✅ sed command executed successfully for $BUILD_FILE."
      ((attempted_updates++))
    else
      echo "   ❌ sed command failed for $BUILD_FILE (Exit code: $?). File might be unchanged or corrupted."
      ((error_count++))
    fi
  else
    echo "   ℹ️ Dependency pattern '$GROUP_ID:$ARTIFACT_ID' not found in this file."
    ((not_found_count++))
  fi
  echo "---"
done

# 5. Final Summary
echo "====== Summary ======"
echo "Processed ${processed_count} build file(s)."
echo "🚀 Update attempted on: $attempted_updates file(s) (check diffs for actual changes)."
echo "ℹ️ Dependency pattern not found in: $not_found_count file(s)."
echo "❌ Errors during sed execution: $error_count file(s)."

# Determine final notification and exit code
if [ $error_count -gt 0 ]; then
  notify "Dependency Update Finished with Errors" "Attempted $attempted_updates, Not Found $not_found_count, Errors $error_count. Review changes!"
  exit 1
elif [ $attempted_updates -gt 0 ]; then
  notify "Dependency Update Finished" "Attempted update for $GROUP_ID:$ARTIFACT_ID in $attempted_updates file(s). Verify with 'git diff'."
  exit 0
else
  notify "Dependency Update Finished" "No matching dependencies found to attempt update for $GROUP_ID:$ARTIFACT_ID."
  exit 0
fi

