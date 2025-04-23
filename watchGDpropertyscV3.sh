#!/bin/zsh

# Strict mode (consider 'set -eo pipefail' if 'nounset' causes issues in interactive use)
set -euo pipefail

# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
fswatch_cmd="/usr/local/bin/fswatch"   # Adjust if installed elsewhere
search_dir="/Users/didi/AndroidStudioProjects" # Directory to search within
search_suffix="gradle.properties"             # File suffix to look for (e.g., gradle.properties)
keyword1="ARTIFACT_ID"                 # Keyword for Artifact ID in properties file
keyword2="VERSION"                     # Keyword for Version in properties file
keyword3="GROUP_ID"                    # Keyword for Group ID in properties file
search_depth=4                         # How many directories deep to search
search_days=61                         # How recent (in days) the files should be
item_prefix="com.versions.item."       # Prefix for generated sketchybar item names
main_item_name="com.versions"          # Name of the main sketchybar item
popup_name="popup.$main_item_name"     # Name of the popup associated with the main item

# --- IMPORTANT: Path to your dependency adding script ---
# Ensure this script exists, is executable (chmod +x), and accepts arguments:
# <project_directory> <group_id> <artifact_id> <version> [optional_scope]
ADD_DEPENDENCY_SCRIPT="/Users/didi/scripts/watchGDadd_dependency.sh" # <<<--- CONFIRM THIS PATH

# --- Placeholder GroupID (if GROUP_ID keyword is not found) ---
PLACEHOLDER_GROUP_ID="com.example.placeholder" # A sensible default

# --- Debugging ---
DEBUG=1                                 # Set to 1 for verbose logging, 0 to disable
LOG_FILE="/tmp/sketchybar_gdversions.log" # Optional log file

# --- Sketchybar Item Template Defaults ---
typeset -A version_item_defaults # Use associative array for clarity
version_item_defaults=(
  [icon.drawing]=off
  [icon.padding_left]=5
  [label.padding_right]=5
  [height]=20
  [background.padding_left]=5
  [background.padding_right]=5
)

# --- Helper Function: Escape for Sketchybar ---
# Robust escaping for arguments passed to sketchybar commands
escape_for_sketchybar() {
    # Using printf %q is generally safer and simpler in Zsh for escaping for shell command context
    # However, sketchybar might have its own specific needs, especially around quotes within labels/scripts.
    # Let's stick with the more explicit sed approach which seemed to work for you,
    # ensuring backslashes and double quotes are handled.
    # printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/'/\\\\'/g" -e 's/ /\\ /g' # Original complex sed
    # Simpler sed focusing on critical chars for --set label="value" or click_script="..."
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g'
}

# --- Logging Function ---
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    local log_time
    # Use %s.%N for sub-second precision if needed, requires GNU date or zsh specific features
    # log_time=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    log_time=$(date '+%Y-%m-%d %H:%M:%S')
    local msg="[$log_time] [DEBUG] $1"
    echo "$msg"                       # Output to terminal
    echo "$msg" >>"$LOG_FILE" # Append to log file
  fi
}

# --- Core Update Logic Function ---
update_sketchybar() {
  log "--- update_sketchybar function started ---"

  # 1. --- Cleanup old dynamic items ---
  log "Querying sketchybar for existing popup items for '$main_item_name'..."
  local query_output
  # Run query, allow failure without script exit, capture output
  query_output=$($sketchybar_cmd --query "$main_item_name" 2>/dev/null || true)

  # Optional: Save raw output for debugging complex cases
  # echo "$query_output" > "/tmp/sketchybar_${main_item_name}_query.json"

  local remove_commands=""
  local items_to_remove=() # Array to hold names for logging/counting

  # Check jq availability and JSON validity
  if ! command -v jq >/dev/null; then
    log "Warning: jq command not found. Skipping precise cleanup of old popup items."
  elif [[ -z "$query_output" ]]; then
      log "Warning: Sketchybar query returned empty output for '$main_item_name'. Skipping cleanup."
  elif ! jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
      log "Warning: Sketchybar query output is not valid JSON. Skipping cleanup. Output was: $query_output"
  else
      log "jq found. Processing query output to find old items with prefix '$item_prefix'..."
      local existing_items_json # Variable to hold the JSON *array* of matching items
      # *** Use jq to filter the STRING array .popup.items ***
      # -r: raw string output (items without quotes, one per line)
      # --arg PREFIX: pass shell variable safely to jq
      # .popup.items? // []: Access .popup.items safely, default to empty array if null/missing
      # .[]: Iterate through each element (string) in the array
      # select(type == "string" and startswith($PREFIX)): Filter for strings starting with the prefix
      jq -r --arg PREFIX "$item_prefix" \
         '.popup.items? // [] | .[] | select(type == "string" and startswith($PREFIX))' \
         <<<"$query_output" 2>/dev/null |
      while IFS= read -r item_name; do
          # This loop now directly receives the names of items to be removed
          if [[ -n "$item_name" ]]; then
              log "Identified old item for removal: '$item_name'"
              local escaped_item_name
              # *** Crucial: Escape for the --remove command ***
              # Sketchybar --remove seems sensitive. Wrapping in quotes is often needed.
              # Let's define a specific escape function if needed, or test if simple quoting works.
              # Using the existing robust escape function should be safe.
              escaped_item_name=$(escape_for_sketchybar "$item_name")
              remove_commands+=" --remove \"$item_name\"" # Try direct quoting first for --remove
              # If direct quoting fails, revert to: remove_commands+=" --remove $escaped_item_name"
              items_to_remove+=("$item_name")
          fi
      done

      # Check if the pipe failed (e.g., jq error)
      if [[ ${pipestatus[1]} -ne 0 ]]; then
          log "Error: jq command failed during item cleanup processing. Skipping removal."
          remove_commands="" # Clear commands if jq failed
          items_to_remove=()
      fi

      log "Found ${#items_to_remove[@]} old dynamic items potentially matching the prefix."
  fi

  # Execute removal if needed
  if [[ -n "$remove_commands" ]]; then
    log "Constructed removal command fragment: $remove_commands"
    log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
    # Using eval carefully. Inputs ($item_name) come from sketchybar query itself.
    if eval "$sketchybar_cmd $remove_commands"; then
        log "Sketchybar removal command executed successfully."
    else
        log "Error executing sketchybar removal command. Command was: $sketchybar_cmd $remove_commands"
    fi
  else
    log "No old dynamic items found to remove or cleanup skipped."
  fi
  # --- End Cleanup ---


  # 2. --- Find recent properties files and extract data ---
  log "Starting find command in '$search_dir' (depth: $search_depth, suffix: $search_suffix, age: $search_days days)..."
  local -a sketchybar_add_commands # Use array for batching add/set commands safely
  local recent_artifact_id=""
  local recent_version=""
  local recent_modified_time=""
  local recent_group_id="" # Store recent group ID too
  local recent_branch_name="-"
  local first_file_processed=true
  local file_count=0
  local processed_count=0
  local -a processed_item_names # Array to hold names of items added/updated in this run

  # Use find with stat for macOS compatibility and efficiency, sort by modification time descending
  # find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" \
  find "$search_dir" -maxdepth "$search_depth" -type f -name "$search_suffix" -mtime "-$search_days" \
       -exec stat -f '%m %N' {} + | sort -rnk1 | cut -d' ' -f2- |
  while IFS= read -r file; do
    # Check if file still exists (might be deleted between find and processing)
    [[ ! -f "$file" ]] && log "  Skipping '$file' - no longer exists." && continue

    file_count=$((file_count + 1))
    log "Processing file #${file_count}: '$file'"

    # Use awk to extract keywords efficiently
    local awk_output
    awk_output=$(awk -v k1="^ *${keyword1} *=" -v k2="^ *${keyword2} *=" -v k3="^ *${keyword3} *=" '
        # Trim leading/trailing whitespace function
        function trim(s) { sub(/^ */, "", s); sub(/ *$/, "", s); return s }
        # Match lines, store values, and track if found
        BEGIN { gid=""; aid=""; ver=""; gid_found=0; aid_found=0; ver_found=0 }
        $0 ~ k1 {sub(k1, ""); aid=trim($0); aid_found=1}
        $0 ~ k2 {sub(k2, ""); ver=trim($0); ver_found=1}
        $0 ~ k3 {sub(k3, ""); gid=trim($0); gid_found=1}
        # Only print if essential keywords are found
        END {if (aid_found && ver_found) print gid "\n" aid "\n" ver}
      ' "$file" 2>/dev/null) # Redirect stderr to avoid clutter

    log "---------- $?"
    if [[ $? -ne 0 || -z "$awk_output" ]]; then
      log "  Error running awk on file '$file'. Skipping."
      continue
    fi

    # Read awk output into variables
    local group_id artifact_id version
    {
      read -r group_id
      read -r artifact_id
      read -r version
    } <<<"$awk_output"

    log "$([ -n "$artifact_id" && -n "$version" ])"
    # Check if essential keywords were extracted
    if [[ -n "$artifact_id" && -n "$version" ]]; then
      processed_count=$((processed_count + 1))

      # Handle missing Group ID
      if [[ -z "$group_id" ]]; then
        log "  Warning: Keyword '$keyword3' (GROUP_ID) not found or empty in '$file'. Using placeholder: '$PLACEHOLDER_GROUP_ID'"
        group_id="$PLACEHOLDER_GROUP_ID"
      fi
      log "  Found: GROUP_ID='$group_id', ARTIFACT_ID='$artifact_id', VERSION='$version'"

      # --- Determine Git context and Project Directory ---
      local file_dir project_dir_for_adder git_root current_branch branch_name commit_hash
      file_dir=$(dirname "$file")
      project_dir_for_adder="" # Reset for each file
      branch_name="-"          # Default branch name

      # Try to find git root starting from the file's directory
      git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null || true)

      if [[ -n "$git_root" && -d "$git_root" ]]; then
        log "  Git root found: '$git_root'. Using this as project directory."
        project_dir_for_adder="$git_root"
        # Get branch name (prefer branch over commit hash)
        current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)
        if [[ -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
          branch_name="$current_branch"
        else
          # Fallback to short commit hash if not on a branch or detached HEAD
          commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null || true)
          [[ -n "$commit_hash" ]] && branch_name="($commit_hash)"
        fi
        log "  Git info: Branch/Commit '$branch_name' in root '$git_root'"
      else
        log "  Warning: Could not determine Git root for '$file'. Falling back to file's directory '$file_dir' for adder script (may be less accurate)."
        project_dir_for_adder="$file_dir" # Fallback
      fi
      # --- End Git Context ---

      # --- Prepare Item Details ---
      local mod_unix_time modified_time label_content item_name escaped_item_name
      mod_unix_time=$(stat -f "%m" "$file")
      modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M") # Format as MM/DD HH:MM

      # Construct the label shown in the popup
      label_content="$modified_time [$branch_name] ${group_id}:${artifact_id}:${version}"
      log "  Constructed label: '$label_content'"

      # Generate a unique item name based on file path (MD5 for stability)
      item_name="${item_prefix}$(echo -n "$file" | md5)"
      processed_item_names+=("$item_name") # Track items added in this run
      log "  Generated sketchybar item name: '$item_name'"
      escaped_item_name=$(escape_for_sketchybar "$item_name") # Escape for use in commands

      # Store details of the most recent file (first one processed due to sort)
      if $first_file_processed; then
        log "  This is the most recent file matching criteria."
        recent_group_id="$group_id"
        recent_artifact_id="$artifact_id"
        recent_version="$version"
        recent_modified_time="$modified_time"
        recent_branch_name="$branch_name"
        first_file_processed=false
      fi
      # --- End Item Details ---

      # --- Prepare click_script (if possible) ---
      cur_as_project_path="$(/Users/didi/scripts/get_as_project_dir.sh)"
      local escaped_click_script_final=""
      if [[ -n "$cur_as_project_path" && -f "$ADD_DEPENDENCY_SCRIPT" && -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
          # Escape all components needed for the command executed by click_script
          local escaped_add_script_path escaped_project_dir escaped_group escaped_artifact escaped_version
          escaped_add_script_path=$(escape_for_sketchybar "$ADD_DEPENDENCY_SCRIPT")
          escaped_project_dir=$(escape_for_sketchybar "$cur_as_project_path")
          escaped_group=$(escape_for_sketchybar "$group_id")
          escaped_artifact=$(escape_for_sketchybar "$artifact_id")
          escaped_version=$(escape_for_sketchybar "$version")
          # Command to close the popup after the script runs
          local popup_off_cmd_str="$sketchybar_cmd --set \"$main_item_name\" popup.drawing=off"
          # We need to escape this *entire command* to embed it correctly
          local escaped_popup_off_cmd
          escaped_popup_off_cmd=$(escape_for_sketchybar "$popup_off_cmd_str")

          # Construct the full command string that click_script will execute
          # Format: add_script <proj_dir> <group> <artifact> <version> && close_popup_command
          # Note: Arguments MUST match the expectations of ADD_DEPENDENCY_SCRIPT
          local click_command
          # Use printf for safe concatenation, ensuring spaces between arguments
          click_command=$(printf '%s %s %s %s %s && %s' \
              "$ADD_DEPENDENCY_SCRIPT" \
              "$cur_as_project_path" \
              "$group_id" \
              "$artifact_id" \
              "$version" \
              "$popup_off_cmd_str" # Use the unescaped command string here
          )
          # Now, escape the *entire* command string for the click_script="<command>" attribute
          escaped_click_script_final=$(escape_for_sketchybar "$click_command")

          log "  Prepared click script. Command to run: $click_command"
          # log "  Final escaped click script for sketchybar: $escaped_click_script_final" # Can be noisy
      else
          if [[ -z "$cur_as_project_path" ]]; then
              log "  Skipping click_script for '$item_name': Project directory couldn't be determined."
          else
              log "  Skipping click_script for '$item_name': Adder script '$ADD_DEPENDENCY_SCRIPT' not found or not executable."
          fi
      fi
      # --- End Prepare click_script ---

      # --- Build Sketchybar --add and --set commands for this item ---
      local add_set_command
      local escaped_label=$(escape_for_sketchybar "$label_content")
      local escaped_popup=$(escape_for_sketchybar "$popup_name")

      # Start with adding the item to the popup
      add_set_command="--add item $escaped_item_name $escaped_popup"
      # Set the label
      add_set_command+=" --set $escaped_item_name label=\"$escaped_label\"" # Quote the label value

      # Add click_script if prepared
      if [[ -n "$escaped_click_script_final" ]]; then
          add_set_command+=" click_script=\"$escaped_click_script_final\"" # Quote the script value
      fi

      # Apply default settings from the associative array
      for key value in ${(kv)version_item_defaults}; do
          # Simple escape for key=value pairs usually works, but be careful
          # Assuming keys don't need complex escaping. Values might.
          local escaped_value=$(escape_for_sketchybar "$value")
          add_set_command+=" $key=$escaped_value" # Defaults usually don't need quotes
      done

      # Add the complete command string for this item to the batch array
      sketchybar_add_commands+=("$add_set_command")
      log "  Prepared add/set commands for item '$item_name'."
      # --- End Build Sketchybar Commands ---

    else
      # Log if essential keywords were missing
      local missing_keys=""
      [[ -z "$artifact_id" ]] && missing_keys+=" '$keyword1'"
      [[ -z "$version" ]] && missing_keys+=" '$keyword2'"
      log "  Skipping file '$file': Required keywords missing or empty:$missing_keys"
    fi

  done # End of while loop processing files

  # Check pipe status for the find | sort | cut | while loop
  # pipestatus array holds exit codes of pipeline components
  if [[ ${pipestatus[1]} -ne 0 || ${pipestatus[2]} -ne 0 || ${pipestatus[3]} -ne 0 ]]; then
     log "Warning: Error occurred during the 'find | sort | cut' pipeline (Exit codes: ${pipestatus[*]}). Results might be incomplete."
  fi

  log "Finished processing $file_count files found by 'find'. $processed_count files had required keywords."

  # 3. --- Execute batch Sketchybar add/set commands ---
  if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
    log "Constructing final batch 'add/set' command for ${#sketchybar_add_commands[@]} new/updated items..."
    # Join the array elements into a single command string
    local full_add_command="${sketchybar_add_commands[*]}"
    # Log only a snippet if the command is potentially huge
    # log "Executing batch command (first 200 chars): ${full_add_command:0:200}..."
    log "Executing batch sketchybar add/set command..."

    # Use eval to execute the combined command string
    if eval "$sketchybar_cmd $full_add_command"; then
        log "Batch sketchybar add/set command executed successfully."
    else
        log "Error executing batch sketchybar add/set command."
        # Consider logging the full command here only on error for debugging
        # log "Failed command: $sketchybar_cmd $full_add_command"
    fi
  else
    log "No new items to add or update in sketchybar popup."
  fi
  # --- End Batch Execution ---


  # 4. --- Update the main sketchybar item's label ---
  local summary_label="GD: N/A" # Default label
  if [[ -n "$recent_artifact_id" ]]; then
    # Example formats: Choose one or customize
    # summary_label="$recent_modified_time [$recent_branch_name] ${recent_artifact_id}:${recent_version}"
    summary_label="GD: ${recent_artifact_id}:${recent_version}" # Simpler version
    # summary_label="GD: $recent_modified_time" # Just time
    log "Updating main label with latest version: '$summary_label'"
  else
    log "Updating main label: No recent version found matching criteria."
  fi

  # Safely set the main label using direct execution (avoiding unnecessary eval)
  local escaped_summary_label
  escaped_summary_label=$(escape_for_sketchybar "$summary_label")
  log "Setting main item '$main_item_name' label to $escaped_summary_label"
  if $sketchybar_cmd --set "$main_item_name" label="$escaped_summary_label"; then # Quote the value
      log "Main sketchybar label updated successfully."
  else
      log "Error setting main sketchybar label."
  fi
  # --- End Update Main Label ---

  # 5. --- Set popup items order (Optional but recommended) ---
  # This ensures the items appear in the popup. If you don't set this,
  # they might appear but possibly in an unpredictable order or not at all
  # depending on Sketchybar version/behavior.
  if [[ ${#processed_item_names[@]} -gt 0 ]]; then
      log "Setting order of items in popup '$popup_name'..."
      local order_command_part="items="
      local item_name_str=""
      for item in "${processed_item_names[@]}"; do
          # Escape each item name *for the items= list*
          # Simple quoting usually works here.
          item_name_str+=" \"$(escape_for_sketchybar "$item")\"" # Space-separated quoted names
      done
      # Remove leading space
      item_name_str="${item_name_str# }"
      order_command_part+="$item_name_str"

      log "Executing command to set popup item order for ${#processed_item_names[@]} items..."
      if $sketchybar_cmd --set "$popup_name" "$order_command_part"; then
          log "Successfully set popup item order."
      else
          log "Error setting popup item order. Command part was: --set \"$popup_name\" $order_command_part"
      fi
  else
      log "No items processed in this run, skipping setting popup item order."
      # Optionally explicitly clear items if none were found
      # $sketchybar_cmd --set "$popup_name" items=""
  fi
  # --- End Setting Order ---


  log "--- update_sketchybar function finished ---"
} # End of update_sketchybar function

# --- Main Execution Logic ---

# Create log directory and clear/initialize log file
log_dir=$(dirname "$LOG_FILE")
mkdir -p "$log_dir"
# Initialize log file (clear or create) only if DEBUG is enabled
# [[ "$DEBUG" -eq 1 ]] && >|"$LOG_FILE"

log "Script started."

# --- Dependency Checks ---
log "Checking dependencies..."
echo "Checking dependencies..."
local dependency_error=0
# Check for sketchybar
if ! command -v "$sketchybar_cmd" &>/dev/null; then
  echo "Error: sketchybar not found at '$sketchybar_cmd'. Please install or correct the path." >&2
  dependency_error=1
fi
# Check for fswatch
if ! command -v "$fswatch_cmd" &>/dev/null; then
  echo "Error: fswatch not found at '$fswatch_cmd'. Please install (e.g., brew install fswatch) or correct the path." >&2
  dependency_error=1
fi
# Check for jq (optional but needed for precise cleanup)
if ! command -v jq &>/dev/null; then
  echo "Warning: jq not found. Popup cleanup might not remove old items correctly. Install jq (e.g., brew install jq)." >&2
  log "jq command not found (warning issued)." # Also log it
fi
# Check for git (required for branch/root info)
if ! command -v git &>/dev/null; then
  echo "Error: git command not found. Cannot reliably determine project root/branch. Please install git." >&2
  dependency_error=1
fi
# Check for the add_dependency script
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then
  echo "Error: Dependency adder script not found at '$ADD_DEPENDENCY_SCRIPT'. Please create it or correct the path." >&2
  dependency_error=1
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
  # Try to make it executable automatically, if script exists but isn't executable
  if chmod +x "$ADD_DEPENDENCY_SCRIPT"; then
    log "Made dependency adder script '$ADD_DEPENDENCY_SCRIPT' executable."
  else
    echo "Error: Dependency adder script '$ADD_DEPENDENCY_SCRIPT' is not executable, and failed to automatically make it executable. Please run: chmod +x '$ADD_DEPENDENCY_SCRIPT'" >&2
    dependency_error=1
  fi
fi

if [[ $dependency_error -eq 1 ]]; then
  log "Exiting due to missing critical dependencies or script issues."
  exit 1
fi
log "All critical dependencies checked."
# --- End Dependency Checks ---


# --- Initial Update ---
log "Performing initial sketchybar update on script start..."
update_sketchybar
# --- End Initial Update ---


# --- Start File System Watch ---
log "Starting file system watch using fswatch on '$search_dir' for '*.$search_suffix' files..."
# Define fswatch arguments in an array for clarity and safety
local -a fswatch_args
fswatch_args=(
  -r                             # Recursive
  -o                             # Batch events
  --event Created                # Trigger on creation
  --event Updated                # Trigger on modification
  --event Renamed                # Trigger on rename
  --event MovedTo                # Trigger when moved into the watched dir
  --include="\\.${search_suffix}$" # Include only files with the suffix
  --exclude='/\.git/'            # Exclude common VCS dir
  --exclude='/build/'            # Exclude common build dir
  --exclude='/src/'            # Exclude common build dir
  --exclude='/\.gradle/'         # Exclude common gradle cache dir
  --exclude='/\.idea/'           # Exclude common IDE dir
  --latency 0.5                  # Debounce interval in seconds
  "$search_dir"                  # The directory to watch
)

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

# Start fswatch and pipe its output to a loop that triggers updates
"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
  # event_batch_info often contains just counts or flags when using -o
  # The fact that we received *any* output indicates changes occurred.
  log "fswatch detected changes batch (details omitted for brevity)."
  # Optional: Log the actual batch info if needed for debugging fswatch itself
  # log "fswatch event batch details: $event_batch_info"
  log "Triggering sketchybar update due to fswatch event batch."
  update_sketchybar # Call the main update function
done

# Capture the exit code of fswatch (the first command in the pipe)
local ret_code=${pipestatus[1]}
log "fswatch process terminated with exit code $ret_code."

# Handle unexpected termination
if [[ $ret_code -ne 0 ]]; then
    echo "Error: fswatch process terminated unexpectedly (Code: $ret_code). Check logs at '$LOG_FILE'." >&2
fi

log "Script finished."
exit $ret_code
# --- End File System Watch ---

