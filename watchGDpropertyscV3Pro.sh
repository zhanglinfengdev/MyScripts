#!/bin/zsh

# Strict mode
set -euo pipefail

# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
fswatch_cmd="/usr/local/bin/fswatch"
search_dir="/Users/didi/AndroidStudioProjects"
search_suffix="gradle.properties"
keyword1="ARTIFACT_ID"
keyword2="VERSION"
keyword3="GROUP_ID"
search_depth=4
search_days=61
item_prefix="com.versions.item."
main_item_name="com.versions"
popup_name="popup.$main_item_name"
ADD_DEPENDENCY_SCRIPT="/Users/didi/scripts/watchGDadd_dependency.sh"
PLACEHOLDER_GROUP_ID="com.example.placeholder"
DEBUG=1
LOG_FILE="/tmp/sketchybar_gdversions_v3_cached.log" # Use a different log file

# --- Global Cache ---
declare -a cached_gradle_files=() # Global array to store file paths

# --- Sketchybar Item Template Defaults ---
typeset -A version_item_defaults
version_item_defaults=(
  [icon.drawing]=off
  [icon.padding_left]=5
  [label.padding_right]=5
  [height]=20
  [background.padding_left]=5
  [background.padding_right]=5
)

# --- Helper Function: Escape for Sketchybar ---
escape_for_sketchybar() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# --- Logging Function ---
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    local log_time
    log_time=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[$log_time] [DEBUG] $1"
    echo "$msg"
    echo "$msg" >>"$LOG_FILE"
  fi
}

# --- Function to Populate Initial Cache ---
populate_initial_cache() {
    log "--- populate_initial_cache function started ---"
    log "Running initial find in '$search_dir' (depth: $search_depth, suffix: $search_suffix, age: $search_days days) to populate cache..."
    cached_gradle_files=() # Clear the array first

    # Use find with stat, sort by modification time descending, store paths in the array
    local find_output
    find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "$search_suffix" -mtime "-$search_days" \
                     -exec stat -f '%m %N' {} + 2>/dev/null | sort -rnk1 | cut -d' ' -f2- || true) # Allow find to fail gracefully if no files found

    if [[ -z "$find_output" ]]; then
        log "Initial find command found no matching files."
    else
        # Read the output line by line into the array
        while IFS= read -r file_path; do
            if [[ -n "$file_path" ]]; then # Ensure no empty lines sneak in
                cached_gradle_files+=("$file_path")
            fi
        done <<< "$find_output" # Use <<< for process substitution

        # Check pipestatus if needed, though sort/cut errors are less likely here
        # local find_pipe_status=("${pipestatus[@]}") # Capture pipestatus if using pipe | while
        # if [[ ${find_pipe_status[1]} -ne 0 || ${find_pipe_status[2]} -ne 0 ]]; then
        #    log "Warning: Error during initial 'find | sort | cut' (Exit codes: ${find_pipe_status[*]}). Cache might be incomplete."
        # fi
    fi
    log "Initial cache populated with ${#cached_gradle_files[@]} files."
    # [[ "$DEBUG" -eq 1 ]] && log "Cached files: ${(q+)cached_gradle_files}" # Log the list if debugging heavily
    log "--- populate_initial_cache function finished ---"
}


# --- Core Update Logic Function (Modified) ---
update_sketchybar() {
  log "--- update_sketchybar function started (Using Cached Files) ---"

  # 1. --- Cleanup old dynamic items ---
  # (Cleanup logic remains the same - it queries sketchybar directly)
  log "Querying sketchybar for existing popup items for '$main_item_name'..."
  local query_output
  query_output=$($sketchybar_cmd --query "$main_item_name" 2>/dev/null || true)
  local remove_commands=""
  local items_to_remove=()

  if command -v jq >/dev/null && [[ -n "$query_output" ]] && jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
      log "jq found. Processing query output to find old items with prefix '$item_prefix'..."
      jq -r --arg PREFIX "$item_prefix" \
         '.popup.items? // [] | .[] | select(type == "string" and startswith($PREFIX))' \
         <<<"$query_output" 2>/dev/null |
      while IFS= read -r item_name; do
          if [[ -n "$item_name" ]]; then
              log "Identified old item for removal: '$item_name'"
              remove_commands+=" --remove \"$item_name\""
              items_to_remove+=("$item_name")
          fi
      done
      if [[ ${pipestatus[1]} -ne 0 ]]; then
          log "Error: jq command failed during item cleanup processing. Skipping removal."
          remove_commands=""
          items_to_remove=()
      fi
      log "Found ${#items_to_remove[@]} old dynamic items potentially matching the prefix via jq."
  else
      if ! command -v jq >/dev/null; then
          log "Warning: jq command not found. Skipping precise cleanup."
      elif [[ -z "$query_output" ]]; then
           log "Warning: Sketchybar query returned empty output for '$main_item_name'. Skipping cleanup."
      else
           log "Warning: Sketchybar query output is not valid JSON. Skipping cleanup. Output was: $query_output"
      fi
  fi

  if [[ -n "$remove_commands" ]]; then
    log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
    if eval "$sketchybar_cmd $remove_commands"; then
        log "Sketchybar removal command executed successfully."
    else
        log "Error executing sketchybar removal command. Command was: $sketchybar_cmd $remove_commands"
    fi
  else
    log "No old dynamic items found to remove or cleanup skipped."
  fi
  # --- End Cleanup ---


  # 2. --- Process files from the CACHED list ---
  log "Processing ${#cached_gradle_files[@]} files from the initial cache..."
  local -a sketchybar_add_commands # Array for batching add/set commands
  local recent_artifact_id=""
  local recent_version=""
  local recent_modified_time=""
  local recent_group_id=""
  local recent_branch_name="-"
  local file_count=0
  local processed_count=0
  local -a processed_item_names # Array to hold names of items added/updated in this run

  # --- Variables to track the MOST RECENT file dynamically during THIS update run ---
  local current_latest_mtime=0      # Unix timestamp of the latest file found so far
  local current_latest_file=""      # Path of the latest file found so far
  # Store details corresponding to current_latest_file
  local current_latest_group_id=""
  local current_latest_artifact_id=""
  local current_latest_version=""
  local current_latest_mod_formatted=""
  local current_latest_branch_name="-"
  # ---

  # Iterate through the cached list of files
  for file in "${cached_gradle_files[@]}"; do
    file_count=$((file_count + 1))

    # *** CRITICAL: Check if the cached file still exists ***
    if [[ ! -f "$file" ]]; then
      log "  Skipping cached file '$file' - no longer exists."
      continue # Skip to the next file in the cache
    fi

    log "Processing cached file #${file_count}: '$file'"

    # Use awk to extract keywords (same logic as before)
    local awk_output
    awk_output=$(awk -v k1="^ *${keyword1} *=" -v k2="^ *${keyword2} *=" -v k3="^ *${keyword3} *=" '
        function trim(s) { sub(/^ */, "", s); sub(/ *$/, "", s); return s }
        BEGIN { gid=""; aid=""; ver=""; gid_found=0; aid_found=0; ver_found=0 }
        $0 ~ k1 {sub(k1, ""); aid=trim($0); aid_found=1}
        $0 ~ k2 {sub(k2, ""); ver=trim($0); ver_found=1}
        $0 ~ k3 {sub(k3, ""); gid=trim($0); gid_found=1}
        END {if (aid_found && ver_found) print gid "\n" aid "\n" ver}
      ' "$file" 2>/dev/null)

    if [[ $? -ne 0 || -z "$awk_output" ]]; then
      log "  Error running awk on file '$file' or required keywords not found. Skipping."
      continue
    fi

    local group_id artifact_id version
    {
      read -r group_id
      read -r artifact_id
      read -r version
    } <<<"$awk_output"

    # Check if essential keywords were extracted (redundant check given awk END block, but safe)
    if [[ -n "$artifact_id" && -n "$version" ]]; then
      processed_count=$((processed_count + 1))

      if [[ -z "$group_id" ]]; then
        log "  Warning: Keyword '$keyword3' (GROUP_ID) not found or empty in '$file'. Using placeholder: '$PLACEHOLDER_GROUP_ID'"
        group_id="$PLACEHOLDER_GROUP_ID"
      fi
      log "  Found: GROUP_ID='$group_id', ARTIFACT_ID='$artifact_id', VERSION='$version'"

      # --- Determine Git context and Project Directory (same logic) ---
      local file_dir project_dir_for_adder git_root current_branch branch_name commit_hash
      file_dir=$(dirname "$file")
      project_dir_for_adder=""
      branch_name="-"
      git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)

      if [[ -n "$git_root" && -d "$git_root" ]]; then
        project_dir_for_adder="$git_root"
        current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          branch_name="$current_branch"
        else
          commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null || true)
          [[ -n "$commit_hash" ]] && branch_name="($commit_hash)"
        fi
        log "  Git info: Branch/Commit '$branch_name' in root '$git_root'"
      else
        log "  Warning: Could not determine Git root for '$file'. Falling back to file's directory '$file_dir'."
        project_dir_for_adder="$file_dir"
      fi
      # --- End Git Context ---

      # --- Prepare Item Details ---
      local mod_unix_time modified_time label_content item_name escaped_item_name
      # *** Get current modification time ***
      mod_unix_time=$(stat -f "%m" "$file")
      modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")

      label_content="$modified_time [$branch_name] ${group_id}:${artifact_id}:${version}"
      log "  Constructed label: '$label_content'"

      item_name="${item_prefix}$(echo -n "$file" | md5)"
      processed_item_names+=("$item_name") # Track items added in this run
      log "  Generated sketchybar item name: '$item_name'"
      escaped_item_name=$(escape_for_sketchybar "$item_name")

      # --- Dynamically track the MOST RECENT file based on current mod time ---
      if [[ "$mod_unix_time" -gt "$current_latest_mtime" ]]; then
          log "  *** This file is currently the most recent (Mod time: $mod_unix_time > $current_latest_mtime). Updating main label candidate. ***"
          current_latest_mtime="$mod_unix_time"
          current_latest_file="$file"
          current_latest_group_id="$group_id"
          current_latest_artifact_id="$artifact_id"
          current_latest_version="$version"
          current_latest_mod_formatted="$modified_time"
          current_latest_branch_name="$branch_name"
      fi
      # --- End tracking most recent ---

      # --- Prepare click_script (same logic) ---
      cur_as_project_path="$(/Users/didi/scripts/get_as_project_dir.sh)"
      local escaped_click_script_final=""
      local clicked_label_color="0xff90ee90" # Light green, adjust as needed (e.g., 0xff00ff00 for bright green)
      if [[ -n "$cur_as_project_path" && -f "$ADD_DEPENDENCY_SCRIPT" && -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
          local popup_off_cmd_str="$sketchybar_cmd --set \"$main_item_name\" popup.drawing=off"
          local change_color_cmd_str="$sketchybar_cmd --set \"$item_name\" label.color=$clicked_label_color"
          local click_command
          # click_command=$(printf '%s %s %s %s %s && %s' \
          #     "$ADD_DEPENDENCY_SCRIPT" \
          #     "$cur_as_project_path" \
          #     "$group_id" \
          #     "$artifact_id" \
          #     "$version" \
          #     "$popup_off_cmd_str"
          # )
          # Use printf for safe concatenation of the multiple command parts
          click_command=$(printf '%s %s %s %s %s && %s && %s' \
              "$ADD_DEPENDENCY_SCRIPT" \
              "$cur_as_project_path" \
              "$group_id" \
              "$artifact_id" \
              "$version" \
              "$change_color_cmd_str" \  # <-- Add the color change command string
              "$popup_off_cmd_str"       # <-- Keep the popup close command string
          )
          escaped_click_script_final=$(escape_for_sketchybar "$click_command")
          log "  Prepared click script."
      else
          # Log reason for skipping click script (same as before)
          if [[ -z "$cur_as_project_path" ]]; then log "  Skipping click_script for '$item_name': Project dir not determined.";
          else log "  Skipping click_script for '$item_name': Adder script '$ADD_DEPENDENCY_SCRIPT' not found/executable."; fi
      fi
      # --- End Prepare click_script ---

      # --- Build Sketchybar --add and --set commands (same logic) ---
      local add_set_command
      local escaped_label=$(escape_for_sketchybar "$label_content")
      local escaped_popup=$(escape_for_sketchybar "$popup_name")

      add_set_command="--add item $escaped_item_name $escaped_popup"
      add_set_command+=" --set $escaped_item_name label=\"$escaped_label\""

      if [[ -n "$escaped_click_script_final" ]]; then
          add_set_command+=" click_script=\"$escaped_click_script_final\""
      fi

      for key value in ${(kv)version_item_defaults}; do
          local escaped_value=$(escape_for_sketchybar "$value")
          add_set_command+=" $key=$escaped_value"
      done

      sketchybar_add_commands+=("$add_set_command")
      log "  Prepared add/set commands for item '$item_name'."
      # --- End Build Sketchybar Commands ---

    else
      local missing_keys=""
      [[ -z "$artifact_id" ]] && missing_keys+=" '$keyword1'"
      [[ -z "$version" ]] && missing_keys+=" '$keyword2'"
      log "  Skipping file '$file': Required keywords missing or empty:$missing_keys (This shouldn't happen with the awk check)"
    fi

  done # End of for loop processing CACHED files

  log "Finished processing $processed_count files from the cache that still exist and had required keywords."

  # 3. --- Execute batch Sketchybar add/set commands ---
  # (Same logic as before)
  if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
    log "Constructing final batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
    local full_add_command="${sketchybar_add_commands[*]}"
    log "Executing batch sketchybar add/set command..."
    if eval "$sketchybar_cmd $full_add_command"; then
        log "Batch sketchybar add/set command executed successfully."
    else
        log "Error executing batch sketchybar add/set command."
    fi
  else
    log "No valid items from cache to add or update in sketchybar popup."
  fi
  # --- End Batch Execution ---


  # 4. --- Update the main sketchybar item's label using the dynamically found latest file ---
  local summary_label="GD: N/A" # Default label
  # Use the details stored for the file with current_latest_mtime
  if [[ "$current_latest_mtime" -gt 0 && -n "$current_latest_artifact_id" ]]; then
    # summary_label="$current_latest_mod_formatted [$current_latest_branch_name] ${current_latest_artifact_id}:${current_latest_version}"
    summary_label="GD: ${current_latest_artifact_id}:${current_latest_version}" # Simpler version
    log "Updating main label with latest version found during this update: '$summary_label' (from file '$current_latest_file')"
  else
    log "Updating main label: No valid cached file found during this update or none exist anymore."
  fi

  local escaped_summary_label
  escaped_summary_label=$(escape_for_sketchybar "$summary_label")
  log "Setting main item '$main_item_name' label to $escaped_summary_label"
  if $sketchybar_cmd --set "$main_item_name" label="$escaped_summary_label"; then
      log "Main sketchybar label updated successfully."
  else
      log "Error setting main sketchybar label."
  fi
  # --- End Update Main Label ---

  # 5. --- Set popup items order (using processed_item_names from this run) ---
  # (Same logic as before, order reflects cached items processed in this run)
   if [[ ${#processed_item_names[@]} -gt 0 ]]; then
      log "Setting order of items in popup '$popup_name'..."
      local order_command_part="items="
      local item_name_str=""
      for item in "${processed_item_names[@]}"; do
          item_name_str+=" \"$(escape_for_sketchybar "$item")\""
      done
      item_name_str="${item_name_str# }"
      order_command_part+="$item_name_str"

      log "Executing command to set popup item order for ${#processed_item_names[@]} items..."
      if $sketchybar_cmd --set "$popup_name" "$order_command_part"; then
          log "Successfully set popup item order."
      else
          log "Error setting popup item order. Command part was: --set \"$popup_name\" $order_command_part"
      fi
  else
      log "No items processed in this run, clearing popup item order."
      # Explicitly clear items if none were found/processed
      $sketchybar_cmd --set "$popup_name" items=""
  fi
  # --- End Setting Order ---

  log "--- update_sketchybar function finished (Using Cached Files) ---"
} # End of update_sketchybar function

# --- Main Execution Logic ---

# Create log directory and initialize log file
log_dir=$(dirname "$LOG_FILE")
mkdir -p "$log_dir"
[[ "$DEBUG" -eq 1 ]] && >|"$LOG_FILE" # Clear log file on start if debug is on

log "Script started (Cached Version)."
log "WARNING: This version caches files at startup and will NOT detect newly created gradle.properties files."

# --- Dependency Checks ---
log "Checking dependencies..."
echo "Checking dependencies..."
local dependency_error=0
# (Dependency check logic remains the same)
if ! command -v "$sketchybar_cmd" &>/dev/null; then echo "Error: sketchybar not found at '$sketchybar_cmd'." >&2; dependency_error=1; fi
if ! command -v "$fswatch_cmd" &>/dev/null; then echo "Error: fswatch not found at '$fswatch_cmd'." >&2; dependency_error=1; fi
if ! command -v jq &>/dev/null; then echo "Warning: jq not found. Popup cleanup might be imprecise." >&2; log "jq command not found (warning issued)."; fi
if ! command -v git &>/dev/null; then echo "Error: git command not found." >&2; dependency_error=1; fi
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then
  echo "Error: Adder script not found: '$ADD_DEPENDENCY_SCRIPT'." >&2; dependency_error=1;
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
  if chmod +x "$ADD_DEPENDENCY_SCRIPT"; then log "Made adder script executable: '$ADD_DEPENDENCY_SCRIPT'.";
  else echo "Error: Adder script not executable, failed auto-chmod: '$ADD_DEPENDENCY_SCRIPT'" >&2; dependency_error=1; fi
fi

if [[ $dependency_error -eq 1 ]]; then
  log "Exiting due to missing critical dependencies or script issues."
  exit 1
fi
log "All critical dependencies checked."
# --- End Dependency Checks ---

# --- Initial Cache Population ---
log "Populating initial file cache..."
populate_initial_cache # Run find ONCE here
# --- End Initial Cache Population ---

# --- Initial Update ---
log "Performing initial sketchybar update based on cached files..."
update_sketchybar
# --- End Initial Update ---


# --- Start File System Watch ---
log "Starting file system watch using fswatch on '$search_dir'..."
log "NOTE: fswatch events will trigger processing of the *cached* file list, not a new 'find'."
# (fswatch arguments remain the same)
local -a fswatch_args
fswatch_args=(
  -r
  -o
  # --event Created # Even if fswatch sees a create, we won't process the new file
  --event Updated
  # --event Renamed
  # --event MovedTo
  --include="\\.${search_suffix}$"
  --exclude='/\.git/'
  --exclude='/build/'
  --exclude='/src/'
  --exclude='/\.gradle/'
  --exclude='/\.idea/'
  --exclude='build.gradle'
  --latency 0.5
  "$search_dir"
)

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
  log "fswatch detected changes batch."
  log "Triggering sketchybar update using the PRE-CACHED file list."
  update_sketchybar # Call the modified update function
done

local ret_code=${pipestatus[1]}
log "fswatch process terminated with exit code $ret_code."

if [[ $ret_code -ne 0 ]]; then
    echo "Error: fswatch process terminated unexpectedly (Code: $ret_code). Check logs at '$LOG_FILE'." >&2
fi

log "Script finished."
exit $ret_code
# --- End File System Watch ---

