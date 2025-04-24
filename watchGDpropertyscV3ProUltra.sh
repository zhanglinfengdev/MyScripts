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
LOG_FILE="/tmp/sketchybar_gdversions_v3_stateful.log" # New log file

# --- Colors ---
COLOR_WHITE="0xffffffff"  # Default color
COLOR_RED="0xffff5555"    # Color for changed items (e.g., a noticeable red)
COLOR_GREEN="0xff90ee90"  # Color for clicked items (same as in click script)

# --- Global Caches ---
declare -a cached_gradle_files=()         # Stores file paths found initially
declare -A item_state_cache=()            # Stores [item_name]="label_content|color_code" for state tracking

# --- Sketchybar Item Template Defaults ---
typeset -A version_item_defaults
version_item_defaults=(
  [icon.drawing]=off
  [icon.padding_left]=5
  [label.padding_right]=5
  [height]=20
  [background.padding_left]=5
  [background.padding_right]=5
  # [label.color]=$COLOR_WHITE # Set default color here if desired, or rely on Sketchybar's default
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
    log "Running initial find in '$search_dir' to populate file cache..."
    cached_gradle_files=() # Clear

    local find_output
    find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "$search_suffix" -mtime "-$search_days" \
                     -exec stat -f '%m %N' {} + 2>/dev/null | sort -rnk1 | cut -d' ' -f2- || true)

    if [[ -z "$find_output" ]]; then
        log "Initial find command found no matching files."
    else
        while IFS= read -r file_path; do
            [[ -n "$file_path" ]] && cached_gradle_files+=("$file_path")
        done <<< "$find_output"
    fi
    log "Initial file cache populated with ${#cached_gradle_files[@]} files."
    log "--- populate_initial_cache function finished ---"
}


# --- Core Update Logic Function (Stateful Colors) ---
update_sketchybar() {
  log "--- update_sketchybar function started (Stateful Colors) ---"

  # --- Temporary storage for states generated in THIS run ---
  declare -A current_run_states

  # 1. --- Cleanup old dynamic items (jq based) ---
  # (Cleanup logic remains the same)
  log "Querying sketchybar for existing popup items..."
  local query_output
  query_output=$($sketchybar_cmd --query "$main_item_name" 2>/dev/null || true)
  local remove_commands=""
  local items_to_remove=() # Keep track for removing from state cache later

  if command -v jq >/dev/null && [[ -n "$query_output" ]] && jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
      jq -r --arg PREFIX "$item_prefix" \
         '.popup.items? // [] | .[] | select(type == "string" and startswith($PREFIX))' \
         <<<"$query_output" 2>/dev/null |
      while IFS= read -r item_name; do
          if [[ -n "$item_name" ]]; then
              # Don't log removal here yet, wait until after processing
              remove_commands+=" --remove \"$item_name\""
              items_to_remove+=("$item_name") # Log item name for potential state removal
          fi
      done
      # Error check jq pipe status omitted for brevity, add if needed
      log "Identified ${#items_to_remove[@]} potential old items via jq query."
  else
      log "Warning: jq not found or query failed/empty. Skipping precise cleanup."
      # Fallback? Could try removing all items with prefix, but risky.
      items_to_remove=() # Ensure it's empty if jq fails
  fi
  # Removal execution happens *after* processing current items if needed,
  # OR we can remove them now. Removing now is simpler.
  if [[ -n "$remove_commands" ]]; then
      log "Executing sketchybar removal for ${#items_to_remove[@]} item(s) identified by query..."
      if eval "$sketchybar_cmd $remove_commands"; then
          log "Sketchybar removal command executed successfully."
          # Now remove these from our state cache too
          for item in "${items_to_remove[@]}"; do
              if [[ -v item_state_cache[$item] ]]; then
                  unset 'item_state_cache[$item]' # Remove from associative array
                  log "  Removed '$item' from state cache."
              fi
          done
      else
          log "Error executing sketchybar removal command."
      fi
  else
      log "No old dynamic items found/removed via query."
  fi
  # --- End Cleanup ---


  # 2. --- Process files from the CACHED list ---
  log "Processing ${#cached_gradle_files[@]} files from the initial cache..."
  local -a sketchybar_add_commands # Array for batching add/set commands
  # (Variables for tracking 'most recent' remain the same)
  local current_latest_mtime=0 current_latest_file=""
  local current_latest_group_id="" current_latest_artifact_id="" current_latest_version=""
  local current_latest_mod_formatted="" current_latest_branch_name="-"

  local file_count=0
  local processed_count=0
  local -a processed_item_names # Track item names processed in THIS run

  # Iterate through the cached list of files
  for file in "${cached_gradle_files[@]}"; do
    file_count=$((file_count + 1))

    # Check if file exists
    if [[ ! -f "$file" ]]; then
      log "  Skipping cached file '$file' - no longer exists."
      # If it doesn't exist, ensure its state is potentially removed later
      continue
    fi

    log "Processing cached file #${file_count}: '$file'"

    # Extract keywords (same awk logic)
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
      log "  Error running awk or required keywords missing in '$file'. Skipping."
      continue
    fi

    local group_id artifact_id version
    { read -r group_id; read -r artifact_id; read -r version; } <<<"$awk_output"

    # Process if keywords found
    if [[ -n "$artifact_id" && -n "$version" ]]; then
      processed_count=$((processed_count + 1))
      [[ -z "$group_id" ]] && group_id="$PLACEHOLDER_GROUP_ID" # Handle missing group ID
      log "  Found: G:'$group_id', A:'$artifact_id', V:'$version'"

      # --- Determine Git context (same logic) ---
      local file_dir git_root branch_name
      file_dir=$(dirname "$file")
      branch_name="-"
      git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)
      if [[ -n "$git_root" && -d "$git_root" ]]; then
        local current_branch commit_hash
        current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          branch_name="$current_branch"
        else
          commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null || true)
          [[ -n "$commit_hash" ]] && branch_name="($commit_hash)"
        fi
      fi
      # --- End Git Context ---

      # --- Prepare Item Details & Generate Current Label ---
      local mod_unix_time modified_time current_label_content item_name
      mod_unix_time=$(stat -f "%m" "$file")
      modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")
      current_label_content="$modified_time [$branch_name] ${group_id}:${artifact_id}:${version}"
      item_name="${item_prefix}$(echo -n "$file" | md5)"
      processed_item_names+=("$item_name") # Track items processed this run
      log "  Item Name: '$item_name'"
      log "  Current Label Content: '$current_label_content'"

      # --- Compare with Previous State & Determine Color ---
      local previous_label=""
      local previous_color=""
      local target_color="$COLOR_WHITE" # Default to white

      if [[ -v item_state_cache[$item_name] ]]; then
          # Previous state exists, parse it
          local previous_state="${item_state_cache[$item_name]}"
          # Robust parsing using IFS
          IFS='|' read -r previous_label previous_color <<< "$previous_state"
          log "  Previous State Found: Label='${previous_label}', Color='${previous_color}'"

          if [[ "$current_label_content" != "$previous_label" ]]; then
              log "  State Changed: Label differs. Setting color to RED."
              target_color="$COLOR_RED"
          elif [[ "$previous_color" == "$COLOR_GREEN" ]]; then
              log "  State Unchanged: Label same, previous color was GREEN. Keeping GREEN."
              target_color="$COLOR_GREEN" # Keep green if unchanged and previously green
          else
              log "  State Unchanged: Label same, previous color not GREEN. Setting color to WHITE."
              target_color="$COLOR_WHITE" # Otherwise default to white if unchanged
          fi
      else
          log "  No Previous State Found for '$item_name'. Setting color to WHITE (first appearance)."
          target_color="$COLOR_WHITE" # New item, default white
      fi

      # --- Store the NEW state for the *next* run in the temporary array ---
      # Store the calculated target color, *not* the previous color
      current_run_states[$item_name]="$current_label_content|$target_color"
      log "  Storing New State for Next Run: Label='${current_label_content}', Color='${target_color}'"

      # --- Dynamically track most recent file (same logic) ---
      if [[ "$mod_unix_time" -gt "$current_latest_mtime" ]]; then
          log "  *** This file is currently the most recent. Updating main label candidate. ***"
          current_latest_mtime="$mod_unix_time"
          current_latest_file="$file"
          current_latest_group_id="$group_id"
          current_latest_artifact_id="$artifact_id"
          current_latest_version="$version"
          current_latest_mod_formatted="$modified_time"
          current_latest_branch_name="$branch_name"
      fi

      # --- Prepare click_script (Sets color to GREEN on click) ---
      cur_as_project_path="$(/Users/didi/scripts/get_as_project_dir.sh)"
      local escaped_click_script_final=""
      if [[ -n "$cur_as_project_path" && -f "$ADD_DEPENDENCY_SCRIPT" && -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
          local popup_off_cmd_str="$sketchybar_cmd --set \"$main_item_name\" popup.drawing=off"
          # Command to change THIS item's color to GREEN
          local change_color_cmd_str="$sketchybar_cmd --set \"$item_name\" label.color=$COLOR_GREEN"
          local click_command
          click_command=$(printf '%s %s %s %s %s && %s && %s' \
              "$ADD_DEPENDENCY_SCRIPT" "$cur_as_project_path" "$group_id" "$artifact_id" "$version" \
              "$change_color_cmd_str" "$popup_off_cmd_str"
          )
          escaped_click_script_final=$(escape_for_sketchybar "$click_command")
          log "  Prepared click script (sets color to GREEN)."
      else
           if [[ -z "$cur_as_project_path" ]]; then log "  Skipping click_script: Project dir not determined.";
           else log "  Skipping click_script: Adder script '$ADD_DEPENDENCY_SCRIPT' not found/executable."; fi
      fi
      # --- End Prepare click_script ---

      # --- Build Sketchybar --add and --set commands ---
      local add_set_command
      local escaped_label=$(escape_for_sketchybar "$current_label_content") # Use current label
      local escaped_popup=$(escape_for_sketchybar "$popup_name")
      local escaped_item_name=$(escape_for_sketchybar "$item_name") # Escape item name just in case

      # Use the unescaped item_name for add/set target
      add_set_command="--add item $item_name $escaped_popup"
      # Set the label AND the calculated target color
      add_set_command+=" --set $item_name label=\"$escaped_label\" label.color=$target_color"

      # Add click script if prepared
      if [[ -n "$escaped_click_script_final" ]]; then
          add_set_command+=" click_script=\"$escaped_click_script_final\""
      fi

      # Apply default settings
      for key value in ${(kv)version_item_defaults}; do
          local escaped_value=$(escape_for_sketchybar "$value")
          add_set_command+=" $key=\"$escaped_value\"" # Quote defaults for safety
      done

      sketchybar_add_commands+=("$add_set_command")
      log "  Prepared add/set commands for '$item_name' with target color $target_color."
      # --- End Build Sketchybar Commands ---

    fi # End check for essential keywords

  done # End of for loop processing CACHED files

  log "Finished processing loop. $processed_count files from cache had required keywords."

  # --- Update the master state cache with the states from THIS run ---
  # This replaces the old cache entirely, implicitly removing items for deleted files
  # or files that no longer meet criteria (e.g., older than search_days now)
  log "Updating master state cache with ${#current_run_states[@]} current states..."
  # Use Zsh specific syntax for efficient associative array copy/assignment
  item_state_cache=("${(@kv)current_run_states}")
  log "Master state cache updated."
  # [[ "$DEBUG" -eq 1 ]] && log "Current State Cache: ${(k)item_state_cache}" # Log keys if needed

  # 3. --- Execute batch Sketchybar add/set commands ---
  if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
    log "Constructing and executing batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
    local full_add_command="${sketchybar_add_commands[*]}"
    if eval "$sketchybar_cmd $full_add_command"; then
        log "Batch sketchybar add/set command executed successfully."
    else
        log "Error executing batch sketchybar add/set command."
    fi
  else
    log "No valid items processed in this run to add/update in sketchybar popup."
  fi
  # --- End Batch Execution ---

  # 4. --- Update the main sketchybar item's label (using most recent found) ---
  # (Logic remains the same)
  local summary_label="GD: N/A"
  if [[ "$current_latest_mtime" -gt 0 && -n "$current_latest_artifact_id" ]]; then
    summary_label="GD: ${current_latest_artifact_id}:${current_latest_version}"
    log "Updating main label with latest version: '$summary_label'"
  else
    log "Updating main label: No valid cached file found during this update."
  fi
  local escaped_summary_label=$(escape_for_sketchybar "$summary_label")
  if $sketchybar_cmd --set "$main_item_name" label="$escaped_summary_label"; then
      log "Main sketchybar label updated successfully."
  else
      log "Error setting main sketchybar label."
  fi
  # --- End Update Main Label ---

  # 5. --- Set popup items order (using items processed in THIS run) ---
   if [[ ${#processed_item_names[@]} -gt 0 ]]; then
      log "Setting order for ${#processed_item_names[@]} items in popup '$popup_name'..."
      local order_command_part="items="
      local item_name_str=""
      # Ensure order matches the processing order (usually sorted by time initially)
      for item in "${processed_item_names[@]}"; do
          item_name_str+=" \"$(escape_for_sketchybar "$item")\""
      done
      item_name_str="${item_name_str# }"
      order_command_part+="$item_name_str"

      if $sketchybar_cmd --set "$popup_name" "$order_command_part"; then
          log "Successfully set popup item order."
      else
          log "Error setting popup item order."
      fi
  else
      log "No items processed in this run, clearing popup item order."
      $sketchybar_cmd --set "$popup_name" items="" # Explicitly clear
  fi
  # --- End Setting Order ---

  log "--- update_sketchybar function finished (Stateful Colors) ---"
} # End of update_sketchybar function

# --- Main Execution Logic ---

# Setup Log file
log_dir=$(dirname "$LOG_FILE")
mkdir -p "$log_dir"
[[ "$DEBUG" -eq 1 ]] && >|"$LOG_FILE"

log "Script started (Stateful Colors Version)."
log "WARNING: Uses initial file cache; won't detect newly created files after start."
log "Colors: Default=$COLOR_WHITE, Changed=$COLOR_RED, Clicked=$COLOR_GREEN"

# --- Dependency Checks ---
# (Checks remain the same)
log "Checking dependencies..."
echo "Checking dependencies..."
local dependency_error=0
if ! command -v "$sketchybar_cmd" &>/dev/null; then echo "Error: sketchybar not found: '$sketchybar_cmd'." >&2; dependency_error=1; fi
if ! command -v "$fswatch_cmd" &>/dev/null; then echo "Error: fswatch not found: '$fswatch_cmd'." >&2; dependency_error=1; fi
if ! command -v jq &>/dev/null; then echo "Warning: jq not found. Popup cleanup might be imprecise." >&2; log "jq command not found (warning issued)."; fi
if ! command -v git &>/dev/null; then echo "Error: git command not found." >&2; dependency_error=1; fi
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then echo "Error: Adder script not found: '$ADD_DEPENDENCY_SCRIPT'." >&2; dependency_error=1;
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
  if chmod +x "$ADD_DEPENDENCY_SCRIPT"; then log "Made adder script executable: '$ADD_DEPENDENCY_SCRIPT'.";
  else echo "Error: Adder script not executable, failed auto-chmod: '$ADD_DEPENDENCY_SCRIPT'" >&2; dependency_error=1; fi
fi
if [[ $dependency_error -eq 1 ]]; then log "Exiting due to missing dependencies."; exit 1; fi
log "Dependencies checked."
# --- End Dependency Checks ---

# --- Initial Cache Population ---
log "Populating initial file cache..."
populate_initial_cache
# --- End Initial Cache Population ---

# --- Initial Update ---
log "Performing initial sketchybar update..."
update_sketchybar # First run will set initial states and colors (likely all white)
# --- End Initial Update ---


# --- Start File System Watch ---
log "Starting file system watch on '$search_dir'..."
# (fswatch setup remains the same)
local -a fswatch_args
fswatch_args=( -r -o --event Updated --include="\\.${search_suffix}$" --exclude='/\.git/' --exclude='/build/' --exclude='/src/' --exclude='/\.gradle/' --exclude='/\.idea/' --exclude='build.gradle' --latency 0.5 "$search_dir" )

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
  log "fswatch detected changes batch."
  log "Triggering stateful sketchybar update..."
  update_sketchybar # Call the stateful update function
done

local ret_code=${pipestatus[1]}
log "fswatch process terminated with exit code $ret_code."
[[ $ret_code -ne 0 ]] && echo "Error: fswatch terminated unexpectedly (Code: $ret_code). Check logs: '$LOG_FILE'." >&2
log "Script finished."
exit $ret_code
# --- End File System Watch ---

