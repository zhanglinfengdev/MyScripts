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
DEBUG=0
LOG_FILE="/tmp/sketchybar_gdversions_v3_stateful_v2.log" # Updated log file name

# --- Colors ---
COLOR_WHITE="0xffffffff"  # Default color for unchanged items
COLOR_RED="0xffed8796"    # Color for items whose content changed since last update
COLOR_GREEN="0xff90ee90"  # Color for items after being clicked

# --- Global Caches ---
declare -a cached_gradle_files=()         # Stores file paths found initially
# Stores state between runs. Format: Key=item_name, Value="label_content|color_code"
# IMPORTANT: Assumes the label_content itself does not contain the '|' character.
declare -A item_state_cache=()

# --- Sketchybar Item Template Defaults ---
typeset -A version_item_defaults
# version_item_defaults=(
#   [icon.drawing]=off
#   [icon.padding_left]=5
#   [label.padding_right]=5
#   [height]=20
#   [background.padding_left]=5
#   [background.padding_right]=5
#   [label.color]=$COLOR_WHITE # Explicitly set default color
# )
version_item_defaults=(
  [icon.drawing]=off
  [icon.padding_left]=5
  [label.padding_right]=5
  [background.padding_left]=5
  [background.padding_right]=5
  [label.color]=$COLOR_WHITE # Explicitly set default color
)

# --- Helper Function: Escape for Sketchybar ---
# Escapes backslashes and double quotes for safe embedding in sketchybar commands
escape_for_sketchybar() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# --- Logging Function ---
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    local log_time msg
    log_time=$(date '+%Y-%m-%d %H:%M:%S')
    # Ensure $1 exists before using it to avoid unbound variable error with set -u
    msg=${1:-"Log message was empty"}
    echo "[$log_time] [DEBUG] $msg" >>"$LOG_FILE"
    # Optionally echo to stdout as well for interactive debugging
    # echo "[$log_time] [DEBUG] $msg"
  fi
}

# --- Function to Populate Initial Cache ---
# Finds relevant gradle.properties files once at startup and stores them.
populate_initial_cache() {
    log "--- populate_initial_cache function started ---"
    log "Running initial find in '$search_dir' (depth: $search_depth, suffix: $search_suffix, age: $search_days days) to populate file cache..."
    cached_gradle_files=() # Clear the array first

    local find_output
    # Find files, get modification time (%m) and path (%N), sort descending by time, keep only path
    find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "$search_suffix" -mtime "-$search_days" \
                     -exec stat -f '%m %N' {} + 2>/dev/null | sort -rnk1 | cut -d' ' -f2- || true) # Allow find to fail gracefully

    if [[ -z "$find_output" ]]; then
        log "Initial find command found no matching files."
    else
        # Read the output line by line into the array
        while IFS= read -r file_path; do
            if [[ -n "$file_path" ]]; then # Ensure no empty lines
                cached_gradle_files+=("$file_path")
            fi
        done <<< "$find_output" # Use Zsh process substitution
    fi
    log "Initial file cache populated with ${#cached_gradle_files[@]} files."
    log "--- populate_initial_cache function finished ---"
}


# --- Core Update Logic Function (Stateful Colors) ---
# Updates Sketchybar based on the cached file list and maintains item color state.
update_sketchybar() {
  log "--- update_sketchybar function started (Stateful Colors) ---"

  # --- Temporary storage for states generated in THIS run ---
  # This ensures consistency during the update process.
  declare -A current_run_states

  # 1. --- Cleanup old dynamic items (jq based) ---
  log "Querying sketchybar for existing popup items to clean up..."
  local query_output remove_commands items_to_remove
  query_output=$($sketchybar_cmd --query "$main_item_name" 2>/dev/null || true)
  remove_commands=""
  items_to_remove=() # Keep track for removing from state cache later

  # Use jq for precise cleanup if available and output is valid JSON
  if command -v jq >/dev/null && [[ -n "$query_output" ]] && jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
      jq -r --arg PREFIX "$item_prefix" \
         '.popup.items? // [] | .[] | select(type == "string" and startswith($PREFIX))' \
         <<<"$query_output" 2>/dev/null |
      while IFS= read -r item_name; do
          if [[ -n "$item_name" ]]; then
              remove_commands+=" --remove \"$item_name\""
              items_to_remove+=("$item_name") # Store name for state cache removal
          fi
      done
      # Consider checking jq pipe status here if strict error handling is needed
      log "Identified ${#items_to_remove[@]} potential old items via jq query."
  else
      log "Warning: jq not found or query failed/empty. Precise cleanup skipped."
      items_to_remove=() # Ensure it's empty if jq fails
  fi

  # Execute removal from Sketchybar and state cache
  if [[ -n "$remove_commands" ]]; then
      log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
      # Using eval here for batch removal. Assumes item names don't contain problematic characters after escaping.
      if eval "$sketchybar_cmd $remove_commands"; then
          log "Sketchybar removal command executed successfully."
          # Remove corresponding entries from our state cache
          for item in "${items_to_remove[@]}"; do
              # Use -v for checking key existence in Zsh associative array
              if [[ -v item_state_cache[$item] ]]; then
                  unset 'item_state_cache[$item]'
                  log "  Removed '$item' from state cache."
              fi
          done
      else
          log "Error executing sketchybar removal command. Command fragment: $remove_commands"
      fi
  else
      log "No old dynamic items found/removed via query."
  fi
  # --- End Cleanup ---


  # 2. --- Process files from the CACHED list ---
  log "Processing ${#cached_gradle_files[@]} files from the initial cache..."
  local -a sketchybar_add_commands # Array for batching add/set commands
  # Variables for tracking the MOST RECENT file found during this update run
  local current_latest_mtime=0 current_latest_file=""
  local current_latest_group_id="" current_latest_artifact_id="" current_latest_version=""
  local current_latest_mod_formatted="" current_latest_branch_name="-"

  local file_count=0 processed_count=0
  local -a processed_item_names # Track item names processed in THIS run

  # Iterate through the initially cached list of files
  for file in "${cached_gradle_files[@]}"; do
    file_count=$((file_count + 1))

    # CRITICAL: Check if the cached file still exists before processing
    if [[ ! -f "$file" ]]; then
      log "  Skipping cached file '$file' - no longer exists."
      # State cache for this item will be implicitly removed when `item_state_cache` is updated later.
      continue
    fi

    log "Processing cached file #${file_count}: '$file'"

    # Extract keywords using awk for efficiency
    local awk_output awk_exit_code
    awk_output=$(awk -v k1="^ *${keyword1} *=" -v k2="^ *${keyword2} *=" -v k3="^ *${keyword3} *=" '
        function trim(s) { sub(/^ */, "", s); sub(/ *$/, "", s); return s }
        BEGIN { gid=""; aid=""; ver=""; gid_found=0; aid_found=0; ver_found=0 }
        $0 ~ k1 {sub(k1, ""); aid=trim($0); aid_found=1}
        $0 ~ k2 {sub(k2, ""); ver=trim($0); ver_found=1}
        $0 ~ k3 {sub(k3, ""); gid=trim($0); gid_found=1}
        END {if (aid_found && ver_found) print gid "\n" aid "\n" ver}
      ' "$file" 2>/dev/null)
    awk_exit_code=$? # Capture awk exit code

    # Check if awk failed or didn't find required keywords
    if [[ $awk_exit_code -ne 0 || -z "$awk_output" ]]; then
      log "  Skipping '$file': awk failed (Code: $awk_exit_code) or required keywords ($keyword1, $keyword2) not found/extracted."
      continue
    fi

    # Read extracted values
    local group_id artifact_id version
    { read -r group_id; read -r artifact_id; read -r version; } <<<"$awk_output"

    # Double-check, although awk END should ensure these are non-empty if output exists
    if [[ -n "$artifact_id" && -n "$version" ]]; then
      processed_count=$((processed_count + 1))
      # Handle potentially missing Group ID
      if [[ -z "$group_id" ]]; then
        log "  Warning: Keyword '$keyword3' (GROUP_ID) not found or empty in '$file'. Using placeholder: '$PLACEHOLDER_GROUP_ID'"
        group_id="$PLACEHOLDER_GROUP_ID"
      fi
      log "  Found: G:'$group_id', A:'$artifact_id', V:'$version'"

      # --- Determine Git context (Branch or Commit Hash) ---
      local file_dir git_root branch_name current_branch commit_hash
      file_dir=$(dirname "$file")
      branch_name="-" # Default if not in git repo or branchless
      git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)
      if [[ -n "$git_root" && -d "$git_root" ]]; then
        current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          branch_name="$current_branch" # Use branch name if available
        else
          # Fallback to commit hash if in detached HEAD state
          commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null || true)
          [[ -n "$commit_hash" ]] && branch_name="($commit_hash)"
        fi
        # log "  Git info: Branch/Commit '$branch_name' in root '$git_root'" # Optional detailed log
      fi
      # --- End Git Context ---

      # --- Prepare Item Details & Generate Current Label ---
      local mod_unix_time modified_time current_label_content item_name
      mod_unix_time=$(stat -f "%m" "$file")
      modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")
      current_label_content="$modified_time [$branch_name] ${group_id}:${artifact_id}:${version}"
      # Generate unique, stable item name based on file path
      item_name="${item_prefix}$(echo -n "$file" | md5)"
      processed_item_names+=("$item_name") # Track items processed this run
      log "  Item Name: '$item_name'"
      log "  Current Label Content: '$current_label_content'"

      # --- Compare with Previous State & Determine Target Color ---
      local previous_label="" previous_color="" target_color="$COLOR_WHITE" # Default to white
      local previous_state=""

      if [[ -v item_state_cache[$item_name] ]]; then
          previous_state="${item_state_cache[$item_name]}"
          # Parse previous state (Label|Color) using IFS
          IFS='|' read -r previous_label previous_color <<< "$previous_state"
          log "  Previous State Found: Label='${previous_label}', Color='${previous_color}'"

          if [[ "$current_label_content" != "$previous_label" ]]; then
              log "  State Changed: Label differs. Setting color to RED."
              target_color="$COLOR_RED"
          elif [[ "$previous_color" == "$COLOR_GREEN" ]]; then
              # Label is the same, and it was previously green (clicked)
              log "  State Unchanged: Label same, previous color was GREEN. Keeping GREEN."
              target_color="$COLOR_GREEN"
          else
              # Label is the same, and it was previously not green (e.g., white or red)
              log "  State Unchanged: Label same, previous color not GREEN. Setting color to WHITE."
              target_color="$COLOR_WHITE" # Reset to white if unchanged and wasn't green
          fi
      else
          log "  No Previous State Found for '$item_name'. Setting color to WHITE (first appearance)."
          target_color="$COLOR_WHITE" # New item defaults to white
      fi

      # --- Store the NEW state (current label + target color) for the *next* run ---
      # This populates the temporary cache for this run.
      current_run_states[$item_name]="$current_label_content|$target_color"
      log "  Storing New State for Next Run: Label='${current_label_content}', Color='${target_color}'"

      # --- Track the most recently modified file among processed files ---
      if [[ "$mod_unix_time" -gt "$current_latest_mtime" ]]; then
          log "  *** This file is currently the most recent (Mod time: $mod_unix_time). Updating main label candidate. ***"
          current_latest_mtime="$mod_unix_time"
          current_latest_file="$file"
          current_latest_group_id="$group_id"
          current_latest_artifact_id="$artifact_id"
          current_latest_version="$version"
          current_latest_mod_formatted="$modified_time"
          current_latest_branch_name="$branch_name"
      fi

      # --- Prepare click_script (Action to perform when item is clicked) ---
      # This script adds the dependency and turns the clicked item GREEN immediately.
      cur_as_project_path="$(/Users/didi/scripts/get_as_project_dir.sh)" # Get current AS project
      local escaped_click_script_final="" click_command popup_off_cmd_str change_color_cmd_str
      if [[ -n "$cur_as_project_path" && -f "$ADD_DEPENDENCY_SCRIPT" && -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
          # Command to close the popup after action
          popup_off_cmd_str="$sketchybar_cmd --set \"$main_item_name\" popup.drawing=off"
          # Command to change THIS item's color to GREEN upon successful click
          change_color_cmd_str="$sketchybar_cmd --set \"$item_name\" label.color=$COLOR_GREEN"

          # Build the combined command string to be executed on click
          click_command=$(printf '%s %s %s %s %s && %s && %s' \
              "$ADD_DEPENDENCY_SCRIPT" "$cur_as_project_path" "$group_id" "$artifact_id" "$version" \
              "$change_color_cmd_str" "$popup_off_cmd_str"
          )
          # Escape the whole command string for the sketchybar click_script attribute
          escaped_click_script_final=$(escape_for_sketchybar "$click_command")
          log "  Prepared click script (adds dependency, sets color to GREEN, closes popup)."
      else
           if [[ -z "$cur_as_project_path" ]]; then log "  Skipping click_script for '$item_name': Android Studio Project dir not determined.";
           else log "  Skipping click_script for '$item_name': Adder script '$ADD_DEPENDENCY_SCRIPT' not found or not executable."; fi
      fi
      # --- End Prepare click_script ---

      # --- Build Sketchybar --add and --set commands for this item ---
      local add_set_command escaped_label escaped_popup escaped_item_name key value escaped_value
      escaped_label=$(escape_for_sketchybar "$current_label_content")
      escaped_popup=$(escape_for_sketchybar "$popup_name")
      escaped_item_name=$(escape_for_sketchybar "$item_name") # Mostly for consistency, MD5 hash is safe

      # Start with adding the item to the popup
      # Use the *unescaped* item_name as the identifier for sketchybar add/set commands
      add_set_command="--add item $item_name $escaped_popup"
      # Set the label content AND the determined target color
      add_set_command+=" --set $item_name label=\"$escaped_label\" label.color=$target_color"

      # Add the click script if it was prepared
      if [[ -n "$escaped_click_script_final" ]]; then
          add_set_command+=" click_script=\"$escaped_click_script_final\""
      fi

      # Apply default appearance settings from the associative array
      for key value in ${(kv)version_item_defaults}; do
          escaped_value=$(escape_for_sketchybar "$value")
          # Add default setting, ensuring value is quoted
          add_set_command+=" $key=\"$escaped_value\""
      done

      # Add the fully constructed command string for this item to the batch array
      sketchybar_add_commands+=("$add_set_command")
      log "  Prepared add/set commands for '$item_name' with target color $target_color."
      # --- End Build Sketchybar Commands ---

    else
       # This case should ideally not be reached due to the awk check, but is a safeguard
       log "  Skipping file '$file' post-awk: Essential keywords still considered missing."
    fi # End check for essential keywords

  done # End of for loop processing CACHED files

  log "Finished processing loop. $processed_count files from cache parsed successfully."

  # --- Update the master state cache with the states generated THIS run ---
  # This completely replaces the old state cache. Items not processed in this run
  # (e.g., due to file deletion or age) are implicitly removed from the state.
  log "Updating master state cache with ${#current_run_states[@]} current states..."
  item_state_cache=("${(@kv)current_run_states}") # Zsh efficient associative array assignment
  log "Master state cache updated."
  # [[ "$DEBUG" -eq 1 ]] && print -rl "Current State Cache Keys:" ${(k)item_state_cache} # Detailed debug

  # 3. --- Execute batch Sketchybar add/set commands ---
  if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
    log "Constructing and executing batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
    # Concatenate all add/set commands into one string for eval
    local full_add_command="${sketchybar_add_commands[*]}"
    # Using eval for batching multiple --add/--set operations in one call.
    # Assumes commands and arguments are properly escaped.
    log "Executing batch command via eval..." # Add log before potential error source
    if eval "$sketchybar_cmd $full_add_command"; then
        log "Batch sketchybar add/set command executed successfully."
    else
        log "ERROR executing batch sketchybar add/set command. Check command syntax/escaping."
        # Optionally log the command string itself for debugging, but be wary of length/secrets
        # log "Failed command string (potentially long): $full_add_command"
    fi
  else
    log "No valid items processed in this run to add/update in sketchybar popup."
  fi
  # --- End Batch Execution ---

  # 4. --- Update the main sketchybar item's label (using most recent found) ---
  local summary_label="GD: N/A" # Default label
  if [[ "$current_latest_mtime" -gt 0 && -n "$current_latest_artifact_id" ]]; then
    # Use details from the most recently modified file processed in this run
    summary_label="GD: ${current_latest_artifact_id}:${current_latest_version}"
    log "Updating main label with latest version: '$summary_label' (from file '$current_latest_file')"
  else
    log "Updating main label: No valid/recent files found during this update cycle."
  fi
  local escaped_summary_label=$(escape_for_sketchybar "$summary_label")
  if $sketchybar_cmd --set "$main_item_name" label="$escaped_summary_label"; then
      log "Main sketchybar label updated successfully."
  else
      log "ERROR setting main sketchybar label for '$main_item_name'."
  fi
  # --- End Update Main Label ---

  # 5. --- Set popup items order (reflects processing order, usually time-sorted) ---
   if [[ ${#processed_item_names[@]} -gt 0 ]]; then
      log "Setting order for ${#processed_item_names[@]} items in popup '$popup_name'..."
      local order_command_part="items=" item_name_str="" item
      # Build the space-separated list of quoted item names
      for item in "${processed_item_names[@]}"; do
          item_name_str+=" \"$(escape_for_sketchybar "$item")\""
      done
      item_name_str="${item_name_str# }" # Remove leading space
      order_command_part+="$item_name_str"

      # Set the order for the popup itself
      if $sketchybar_cmd --set "$popup_name" "$order_command_part"; then
          log "Successfully set popup item order."
      else
          log "ERROR setting popup item order for '$popup_name'."
      fi
  else
      log "No items processed in this run, clearing popup item order."
      # Explicitly clear items if none were found/processed to avoid stale items showing
      $sketchybar_cmd --set "$popup_name" items="" &>/dev/null || log "Warning: Failed to clear popup items for $popup_name"
  fi
  # --- End Setting Order ---

  log "--- update_sketchybar function finished (Stateful Colors) ---"
} # End of update_sketchybar function

# --- Main Execution Logic ---

# Setup Log file directory and clear log if debug is on
log_dir=$(dirname "$LOG_FILE")
mkdir -p "$log_dir"
# [[ "$DEBUG" -eq 1 ]] && >|"$LOG_FILE" # Clear log file on start

log "Script started (Stateful Colors Version 2)."
log "Monitoring '$search_dir' for changes to '$search_suffix' files."
log "Using initial file cache; won't detect newly created files after start."
log "Colors: Default=$COLOR_WHITE, Changed=$COLOR_RED, Clicked=$COLOR_GREEN"

# --- Dependency Checks ---
log "Checking dependencies..."
echo "Checking dependencies..." # User feedback
local dependency_error=0 check_command error_msg
for check_command in "$sketchybar_cmd" "$fswatch_cmd" git jq; do
    # Use 'local' inside loop if needed, though top-level is fine too
    if ! command -v "$check_command" &>/dev/null; then
        error_msg="ERROR: Required command '$check_command' not found in PATH."
        if [[ "$check_command" == "jq" ]]; then
            error_msg="WARNING: Optional command 'jq' not found. Popup cleanup might be imprecise."
            log "$error_msg"
            echo "$error_msg" >&2
        else
            log "$error_msg"
            echo "$error_msg" >&2
            dependency_error=1
        fi
    fi
done

# Check adder script separately for existence and executability
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then
    error_msg="ERROR: Adder script not found: '$ADD_DEPENDENCY_SCRIPT'."
    log "$error_msg"; echo "$error_msg" >&2; dependency_error=1;
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
    log "Adder script '$ADD_DEPENDENCY_SCRIPT' not executable. Attempting to chmod +x..."
    if chmod +x "$ADD_DEPENDENCY_SCRIPT"; then
        log "Made adder script executable successfully."
    else
        error_msg="ERROR: Failed to make adder script executable: '$ADD_DEPENDENCY_SCRIPT'. Please check permissions."
        log "$error_msg"; echo "$error_msg" >&2; dependency_error=1;
    fi
fi

if [[ $dependency_error -eq 1 ]]; then
    log "Exiting due to missing critical dependencies or script issues."
    exit 1
fi
log "All critical dependencies checked."
# --- End Dependency Checks ---

# --- Initial Cache Population ---
log "Populating initial file cache..."
populate_initial_cache
# --- End Initial Cache Population ---

# --- Initial Update ---
log "Performing initial sketchybar update..."
update_sketchybar # First run populates Sketchybar and sets initial states/colors
# --- End Initial Update ---


# --- Start File System Watch ---
log "Starting file system watch using fswatch on '$search_dir'..."
# Watch only for file updates, as new files aren't handled by the cache logic.
# Use sensible excludes to reduce noise.
local -a fswatch_args
fswatch_args=(
  -r # Recursive
  -o # Batch events
  --event Updated # Only trigger on updates relevant to cached files
  --include="\\.${search_suffix}$" # Include only our target files
  --exclude='/\.git/'    # Exclude common build/VCS directories
  --exclude='/build/'
  --exclude='/src/'      # Exclude src unless gradle.properties is there
  --exclude='/\.gradle/'
  --exclude='/\.idea/'
  --exclude='\.class$'   # Exclude compiled Java/Kotlin files
  --exclude='\.jar$'     # Exclude Jar files
  --exclude='build\.gradle\.kts$' # Exclude build scripts
  --exclude='build\.gradle$'
  --latency 0.5          # Latency to batch events slightly
  "$search_dir"
)

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

# Pipe fswatch output to the loop. Loop continues as long as fswatch provides input.
# || [[ -n "$event_batch_info" ]] handles potential final unterminated line from fswatch.
"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
  # Log raw event info if needed: log "fswatch event data: $event_batch_info"
  log "fswatch detected changes batch. Triggering stateful sketchybar update..."
  update_sketchybar # Call the stateful update function
done

# Check the exit status of fswatch (the first command in the pipe)
local fswatch_exit_code=${pipestatus[1]}
log "fswatch process terminated with exit code $fswatch_exit_code."

if [[ $fswatch_exit_code -ne 0 && $fswatch_exit_code -ne 130 ]]; then # 130 is common for Ctrl+C / SIGINT
    error_msg="ERROR: fswatch process terminated unexpectedly (Code: $fswatch_exit_code). Check logs at '$LOG_FILE'."
    log "$error_msg"
    echo "$error_msg" >&2
fi

log "Script finished."
exit $fswatch_exit_code
# --- End File System Watch ---


