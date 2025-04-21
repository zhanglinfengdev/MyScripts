#!/bin/zsh

# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
fswatch_cmd="/usr/local/bin/fswatch" # Adjust if installed elsewhere
search_dir="/Users/didi/AndroidStudioProjects"
search_suffix="properties" # Used for filtering in find and fswatch pattern
keyword1="ARTIFACT_ID"     # Keyword for Artifact ID in properties file
keyword2="VERSION"         # Keyword for Version in properties file
keyword3="GROUP_ID"        # Keyword for Group ID in properties file (NEW!)
search_depth=4
search_days=61
item_prefix="com.versions.item."
main_item_name="com.versions"
popup_name="popup.$main_item_name"

# --- IMPORTANT: Path to your dependency adding script ---
ADD_DEPENDENCY_SCRIPT="/Users/didi/scripts/watchGDadd_dependency.sh" # <<<--- CONFIRM THIS PATH

# --- Placeholder GroupID (if not found in file) ---
PLACEHOLDER_GROUP_ID="com.example.placeholder" # Should ideally not be needed often

# --- Debugging ---
DEBUG=1                                 # Set to 1 for verbose logging, 0 to disable
LOG_FILE="/tmp/sketchybar_versions.log" # Optional log file

# --- Sketchybar Item Template ---
version_item_defaults=(
  icon.drawing=off
  icon.padding_left=5
  label.padding_right=5
  height=20
  background.padding_left=5
  background.padding_right=5
)

# --- Helper Function ---
escape_for_sketchybar() {
  # Robust escaping for arguments within Sketchybar commands
  # Handles backslashes, double quotes, spaces, single quotes (less common but safe)
  printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/'/\\\\'/g" -e 's/ /\\ /g'
}

# --- Logging Function ---
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    local log_time=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[$log_time] [DEBUG] $1"
    echo "$msg" # Output to terminal
    # echo "$msg" >> "$LOG_FILE" # Append to log file if needed
  fi
}

# --- Core Update Logic Function ---
update_sketchybar() {
  log "--- update_sketchybar function started ---"

  # 1. Cleanup old items (Code is good, no changes needed here)
  # ... (existing code for querying and removing old items) ...
  log "Querying sketchybar for existing items..."
  existing_items=""
  query_output=$($sketchybar_cmd --query "com.versions" 2>/dev/null)
  echo "$query_output" >/Users/didi/testtestaaa.json

  jq_available=false
  if command -v jq >/dev/null; then
    jq_available=true
    log "jq command found."
    if ! jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
      log "Warning: sketchybar query output is not valid JSON. Skipping jq processing."
      # query_output=""
    fi
  else
    log "Warning: jq command not found. Popup item cleanup might be less precise."
  fi

  # log ">>>>$query_output"
  if $jq_available && [[ -n "$query_output" ]]; then
    # existing_items=$(jq -r --arg POPUP "$popup_name" --arg PREFIX "$item_prefix" \
    #   '.popup.items? // [] | .[] | select(.popup? == $POPUP and (.name? // "" | startswith($PREFIX))) | .name' <<<"$query_output" 2>/dev/null)
    existing_items=$(jq '[.popup.items[] | select(startswith("com.versions.item"))]' <<<"$query_output" 2>/dev/null)
    if [[ $? -ne 0 ]]; then
      log "Error running jq to find existing items. Output was: $query_output"
      existing_items=""
    fi
  fi
  log ">>>>$existing_items"

  remove_commands=""
  items_to_remove=()
  # while IFS= read -r item; do
  #   if [[ -n "$item" ]]; then
  #     if [[ "$item" == ${item_prefix}* ]]; then
  #       log "Identified old item for removal: '$item'"
  #       escaped_item_name=$(escape_for_sketchybar "$item")
  #       remove_commands+=" --remove $escaped_item_name"
  #       items_to_remove+=("$item")
  #     else
  #       log "Skipping removal of item '$item' - does not match prefix '$item_prefix'."
  #     fi
  #   fi
  # done <<<"$existing_items"
  #

  jq -r --arg prefix "$item_prefix" '.[] | select(startswith($prefix))' <<<"$existing_items" | while IFS= read -r item; do
    # No need to check for empty string if jq handles it, but doesn't hurt
    # No need to check prefix match, jq already did that
    if [[ -n "$item" ]]; then
      log "Identified old item for removal: '$item'"
      escaped_item_name=$(escape_for_sketchybar "$item")
      remove_commands+=" --remove $escaped_item_name"
      items_to_remove+=("$item")
      log "cc='$items_to_remove'"
    # else
    #   log "Skipping removal of item '$item' - does not match prefix '$item_prefix'."
      # as jq only sends matching items to the loop.
      # If you *need* to log skipped items, you could run a separate jq command:
      # jq -r --arg prefix "$item_prefix" '.[] | select(startswith($prefix) | not)' <<< "$existing_items_json" | while ... log ... ; done
    fi
  done

  log ">>>>-=-=-='$remove_commands'"

  if [[ -n "$remove_commands" ]]; then
    log "Constructed removal command fragment: $remove_commands"
    log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
    # Using eval carefully with properly escaped item names
    eval "$sketchybar_cmd $remove_commands"
    if [[ $? -ne 0 ]]; then log "Error executing sketchybar removal command."; else log "Sketchybar removal command executed."; fi
  else
    log "No old dynamic items found to remove."
  fi
  # --- End Cleanup ---

  # 2. Find files and process them
  log "Starting find command in '$search_dir'..."
  declare -a sketchybar_add_commands
  recent_artifact_id=""
  recent_version=""
  recent_modified_time=""
  recent_modified_branch=""
  first_file_processed=true
  file_count=0
  processed_count=0

  # --- 使用 -printf 优化的 find 命令 ---
  # find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -printf '%T@ %p\n' | sort -rnk1 | cut -d' ' -f2-)
  # find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -exec stat -f "%m %N" {} \; | sort -rnk1 | cut -d' ' -f2-)
  # --- 使用 gfind (GNU find) 的命令 ---
  # 确保 coreutils 已安装 (brew install coreutils)
  # find_output=$(gfind "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -printf '%T@ %p\n' | sort -rnk1 | cut -d' ' -f2-)
  # --- 使用 find -exec stat 优化的命令 (macOS 兼容) ---
  find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -exec stat -f '%m %N' {} + | sort -rnk1 | cut -d' ' -f2-)

  # find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -printf '%T@ %p\n' | sort -rnk1 | cut -d' ' -f2-)
  log "Find command finished. Processing results..."

  while IFS= read -r file; do
    file_count=$((file_count + 1))
    [[ -z "$file" ]] && continue
    log "Processing file #${file_count}: '$file'"

    awk_output=$(awk -v k1="^ *${keyword1} *=" -v k2="^ *${keyword2} *=" -v k3="^ *${keyword3} *=" '
        BEGIN { gid=""; aid=""; ver=""; gid_found=0; aid_found=0; ver_found=0 }
        $0 ~ k1 {sub(k1, ""); aid=$0; gsub(/^ *| *$/, "", aid); aid_found=1}
        $0 ~ k2 {sub(k2, ""); ver=$0; gsub(/^ *| *$/, "", ver); ver_found=1}
        $0 ~ k3 {sub(k3, ""); gid=$0; gsub(/^ *| *$/, "", gid); gid_found=1}
        END {if (aid_found && ver_found) print gid "\n" aid "\n" ver}
      ' "$file" 2>/dev/null)

    if [[ $? -ne 0 ]]; then
      log "  Error running awk on file '$file'."
      continue
    fi

    {
      read -r group_id
      read -r artifact_id
      read -r version
    } <<<"$awk_output"

    if [[ -n "$artifact_id" && -n "$version" ]]; then
      processed_count=$((processed_count + 1))

      if [[ -z "$group_id" ]]; then
        log "  Warning: Keyword '$keyword3' not found in '$file'. Using placeholder: '$PLACEHOLDER_GROUP_ID'"
        group_id="$PLACEHOLDER_GROUP_ID" # Use placeholder if not found
      else
        log "  Found keywords: GROUP_ID='$group_id', ARTIFACT_ID='$artifact_id', VERSION='$version'"
      fi

      file_dir=$(dirname "$file")
      git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null)
      branch_name="-" # Default branch name

      # --- Determine Project Directory to use for the adder script ---
      project_dir_for_adder=""
      if [[ $? -eq 0 && -n "$git_root" ]]; then
        log "  Git root found: '$git_root'. Using this as project directory."
        project_dir_for_adder="$git_root"
        # Get branch name only if git root was found
        current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
        if [[ $? -eq 0 && -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          branch_name="$current_branch"
        else
          commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null)
          if [[ $? -eq 0 && -n $commit_hash ]]; then branch_name="($commit_hash)"; fi
        fi
        log "  Git info: Branch/Commit '$branch_name' in root '$git_root'"
      else
        log "  Warning: Could not determine Git root for '$file'. Falling back to file's directory '$file_dir' as project directory (might be inaccurate)."
        project_dir_for_adder="$file_dir" # Fallback: Use the directory containing the properties file
        log "  Git info: Not a git repository or failed to get root/branch for '$file_dir'."
      fi
      # --- End Determine Project Directory ---

      mod_unix_time=$(stat -f "%m" "$file")
      modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")
      label_content="$modified_time [$branch_name] ${artifact_id}:${version}"
      log "  Constructed label: '$label_content'"

      if $first_file_processed; then
        log "  This is the most recent file matching criteria."
        recent_artifact_id="$artifact_id"
        recent_version="$version"
        recent_modified_time="$modified_time"
        recent_modified_branch="$branch_name"
        first_file_processed=false
      fi

      item_name="${item_prefix}$(echo -n "$file" | md5)"
      log "  Generated sketchybar item name: '$item_name'"

      # --- Prepare click_script command (*** KEY CHANGE AREA ***) ---
      escaped_click_script_final=""
      if [[ -n "$project_dir_for_adder" ]]; then # Only make clickable if we have a project dir
        escaped_add_script_path=$(escape_for_sketchybar "$ADD_DEPENDENCY_SCRIPT")
        escaped_project_dir=$(escape_for_sketchybar "$project_dir_for_adder") # Use determined dir
        escaped_group=$(escape_for_sketchybar "$group_id")
        escaped_artifact=$(escape_for_sketchybar "$artifact_id")
        escaped_version=$(escape_for_sketchybar "$version")
        # Scope is defaulted inside the add script, but could be passed here if needed:
        # escaped_scope=$(escape_for_sketchybar "implementation")

        popup_off_cmd_str="$sketchybar_cmd --set $main_item_name popup.drawing=off"
        escaped_popup_off_cmd=$(escape_for_sketchybar "$popup_off_cmd_str")

        # Build the command: adder_script <proj_dir> <group> <artifact> <version> [scope] && close_popup
        # Order: project_dir, groupId, artifactId, version (matching add script)
        click_command=$(
          printf "%s %s %s %s %s && %s" \
            "$escaped_add_script_path" \
            "$escaped_project_dir" \
            "$escaped_group" \
            "$escaped_artifact" \
            "$escaped_version"
          # "$escaped_scope" \ # Add if passing scope
          "$escaped_popup_off_cmd"
        )

        # Escape the *entire* command string again for the click_script attribute
        escaped_click_script_final=$(escape_for_sketchybar "$click_command")
        log "  Generated click script command: $click_command"
        log "  Final escaped click script: $escaped_click_script_final"
      else
        log "  Skipping click_script for item '$item_name' as project directory could not be determined."
      fi
      # --- End Prepare click_script ---

      # --- Prepare the sketchybar add/set commands ---
      cmd_part=""
      if [[ -n "$escaped_click_script_final" ]]; then
        # Add clickable item
        cmd_part=$(
          printf -- "--add item %s %s --set %s label=%s click_script=%s " \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$popup_name")" \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$label_content")" \
            "$escaped_click_script_final" \ # Use the fully prepared click script command
        )
      else
        # Add non-clickable item (if project dir was missing)
        cmd_part=$(
          printf -- "--add item %s %s --set %s label=%s " \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$popup_name")" \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$label_content")"
        )
      fi

      # Add default settings
      setting_cmds=""
      for key in "${!version_item_defaults[@]}"; do
        value="${version_item_defaults[$key]}"
        escaped_key=$(escape_for_sketchybar "$key")
        escaped_value=$(escape_for_sketchybar "$value")
        setting_cmds+=$(printf -- "--set %s %s=%s " "$(escape_for_sketchybar "$item_name")" "$escaped_key" "$escaped_value")
      done

      sketchybar_add_commands+=("$cmd_part $setting_cmds")
      log "  Added commands for item '$item_name' to batch."
      # --- End Prepare sketchybar add/set ---

    else
      log "  Required keywords ('$keyword1', '$keyword2') not found or incomplete in '$file'."
    fi
  done <<<"$find_output"

  log "Finished processing $file_count files found by 'find'. $processed_count files had required keywords."

  # 3. Execute batch sketchybar add/set commands (Code is good)
  # ... (existing code for executing batch commands) ...
  if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
    log "Constructing final batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
    full_command="${sketchybar_add_commands[*]}"
    log "Executing batch command: $sketchybar_cmd $full_command" # Be cautious logging potentially huge commands
    eval "$sketchybar_cmd $full_command"
    if [[ $? -ne 0 ]]; then log "Error executing batch sketchybar add/set command."; else log "Batch sketchybar add/set command executed."; fi
  else
    log "No new items to add to sketchybar popup."
  fi

  # 4. Update main label (Code is good)
  # ... (existing code for updating main label) ...
  # current_time=$(TZ="Asia/Shanghai" date "+%H:%M:%S") # Adjust TZ if needed
  if [[ -n "$recent_artifact_id" ]]; then
    summary_label="$recent_modified_time$recent_modified_branch${recent_artifact_id}:${recent_version}"
    log "Updating main label with latest version: '$summary_label'"
  else
    summary_label="$current_time: N/A"
    log "Updating main label: No recent version found."
  fi

  cmdPart = $(
    printf -- "--set $main_item_name label=%s" \
      "$(escape_for_sketchybar "$summary_label")"
  )

  eval "$sketchybar_cmd $cmdPart"

  # $sketchybar_cmd --set "$main_item_name" label="$(escape_for_sketchybar "$summary_label")"
  if [[ $? -ne 0 ]]; then log "Error setting main sketchybar label."; else log "Main sketchybar label updated."; fi

  log "--- update_sketchybar function finished ---"
}

# --- Main Execution ---

log "Script started."
# Clear log file on start if using one
# [[ "$DEBUG" -eq 1 && -n "$LOG_FILE" ]] && > "$LOG_FILE"

# Check dependencies (Code is good)
# ... (existing dependency check code) ...
log "Checking dependencies..."
dependency_error=0
# Check for sketchybar
if ! command -v "$sketchybar_cmd" &>/dev/null; then
  echo "Error: sketchybar not found at '$sketchybar_cmd'." >&2
  dependency_error=1
fi
# Check for fswatch
if ! command -v "$fswatch_cmd" &>/dev/null; then
  echo "Error: fswatch not found at '$fswatch_cmd'." >&2
  dependency_error=1
fi
# Check for jq (optional)
if ! command -v jq &>/dev/null; then
  echo "Warning: jq not found. Popup cleanup might be less precise." >&2
  log "jq command not found (warning issued)."
fi
# Check for git
if ! command -v git &>/dev/null; then
  echo "Error: git not found. Cannot reliably determine project root/branch." >&2
  dependency_error=1
fi
# Check for the add_dependency script
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then
  echo "Error: Dependency script not found at '$ADD_DEPENDENCY_SCRIPT'." >&2
  dependency_error=1
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
  echo "Error: Dependency script '$ADD_DEPENDENCY_SCRIPT' is not executable (chmod +x)." >&2
  dependency_error=1
fi

if [[ $dependency_error -eq 1 ]]; then
  log "Exiting due to missing critical dependencies or script issues."
  exit 1
fi
log "Dependencies checked."

# Initial update (Code is good)
log "Performing initial sketchybar update..."
update_sketchybar

# Start fswatch (Code is good)
# ... (existing fswatch setup and execution loop) ...
log "Starting file system watch on '$search_dir' for '*.$search_suffix' files..."
fswatch_args=(-r -o --event Created --event Updated --event Renamed --event MovedTo --include="\\.${search_suffix}$" --exclude='/\.git/' --exclude='/build/' --exclude='/\.gradle/' --exclude='/\.idea/' --latency 0.5 "$search_dir")
log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
  log "fswatch detected changes batch:"
  # Optional: Log details from event_batch_info if needed for debugging fswatch itself
  # printf '%s\n' "$event_batch_info" | while IFS= read -r line; do log "  Event detail: $line"; done
  log "Triggering sketchybar update due to fswatch event batch."
  update_sketchybar
done

ret_code=$?
log "fswatch process terminated with exit code $ret_code."
echo "Error: fswatch process terminated unexpectedly (Code: $ret_code)." >&2
exit $ret_code
