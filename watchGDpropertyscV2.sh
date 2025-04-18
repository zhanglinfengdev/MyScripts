#!/bin/bash

# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
fswatch_cmd="/usr/local/bin/fswatch" # Adjust if installed elsewhere
search_dir="/Users/linfeng/AndroidStudioProjects"
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
ADD_DEPENDENCY_SCRIPT="/Users/linfeng/scripts/MyScripts/watchGDadd_dependency.sh" # <<<--- CHANGE THIS TO YOUR ACTUAL PATH

# --- Placeholder GroupID (if not found in file) ---
# You should ideally have GROUP_ID in your properties files.
# If not, modify this or the logic below to determine the correct group ID.
PLACEHOLDER_GROUP_ID="com.example.placeholder"

# --- Debugging ---
# Set DEBUG to 1 to enable verbose logging, 0 to disable
DEBUG=1 # Enable logging for testing

# --- Sketchybar Item Template ---
version_item_defaults=(
  icon.drawing=off # Example: hide default icon, rely on label
  icon.padding_left=5
  label.padding_right=5
  height=20
  background.padding_left=5
  background.padding_right=5
)

# --- Helper Function ---
# Escapes a string for use as a Sketchybar parameter value (basic)
# Handles spaces, single quotes, double quotes, backslashes.
escape_for_sketchybar() {
    printf '%s' "$1" | sed -e 's/\\/\\\\/g' -e 's/"/\\"/g' -e "s/'/\\\'/g" -e 's/ /\\ /g'
    # Simpler version if the above causes issues:
    # printf '%s' "$1" | sed 's/ /\\ /g; s/"/\\"/g; s/\\/\\\\/g'
    # Even simpler quoting (might work for simple labels/commands):
    # printf "'%s'" "$(printf '%s' "$1" | sed "s/'/'\\\\''/g")" # Wraps in single quotes, escapes internal single quotes
}


# --- Logging Function ---
# Usage: log "Your message here"
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    # Get timestamp in desired log format
    local log_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$log_time] [DEBUG] $1" # >> /tmp/sketchybar_versions.log # Uncomment to log to a file
  fi
}

# --- Core Update Logic Function ---
update_sketchybar() {
    log "--- update_sketchybar function started ---"

    # 1. Prepare for new items: Remove *old* dynamic items from the popup
    log "Querying sketchybar for existing items..."
    existing_items=""
    query_output=$($sketchybar_cmd --query items 2>/dev/null)

    jq_available=false
    if command -v jq >/dev/null; then
        jq_available=true
        log "jq command found."
        if ! jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
            log "Warning: sketchybar query output is not valid JSON. Skipping jq processing."
            query_output=""
        fi
    else
        log "Warning: jq command not found. Popup item cleanup might be less precise."
    fi

    if $jq_available && [[ -n "$query_output" ]]; then
        # Use jq to find items belonging to this popup with the specific prefix
        existing_items=$(jq -r --arg POPUP "$popup_name" --arg PREFIX "$item_prefix" \
          '.items? // [] | .[] | select(.popup? == $POPUP and (.name? // "" | startswith($PREFIX))) | .name' <<<"$query_output" 2>/dev/null)
        if [[ $? -ne 0 ]]; then
             log "Error running jq to find existing items. Output was: $query_output"
             existing_items=""
        fi
    fi

    remove_commands=""
    items_to_remove=()
    while IFS= read -r item; do
      if [[ -n "$item" ]]; then
        # Ensure we only remove items with the correct prefix
        if [[ "$item" == ${item_prefix}* ]]; then
            log "Identified old item for removal: '$item'"
            # Escape the item name for the remove command
            escaped_item_name=$(escape_for_sketchybar "$item")
            remove_commands+=" --remove $escaped_item_name"
            items_to_remove+=("$item")
        else
            log "Skipping removal of item '$item' - does not match prefix '$item_prefix'."
        fi
      fi
    done <<<"$existing_items"

    if [[ -n "$remove_commands" ]]; then
      log "Constructed removal command fragment: $remove_commands"
      log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
      # Use eval carefully here as we constructed the command with escaped parts
      eval "$sketchybar_cmd $remove_commands"
      if [[ $? -ne 0 ]]; then
          log "Error executing sketchybar removal command."
      else
          log "Sketchybar removal command executed."
      fi
    else
        log "No old dynamic items found to remove."
    fi

    # 2. Find candidate files, sort by modification time (newest first), and process
    log "Starting find command in '$search_dir'..."
    declare -a sketchybar_add_commands
    recent_artifact_id=""
    recent_version=""
    first_file_processed=true
    file_count=0
    processed_count=0

    # Find files, get modification time & path, sort, extract path
    # find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -exec stat -f "%m %N" {} \; | sort -rnk1 | cut -d' ' -f2-)
    #
    # --- 使用 -printf 优化的 find 命令 ---
    find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -printf '%T@ %p\n' | sort -rnk1 | cut -d' ' -f2-)
    # --- 优化命令结束 ---
    #
    log "Find command finished. Processing results..."

    while IFS= read -r file; do
      file_count=$((file_count + 1))
      [[ -z "$file" ]] && continue
      log "Processing file #${file_count}: '$file'"

      # Use awk to read the file ONCE and extract GROUP_ID, ARTIFACT_ID, VERSION
      # Allow space around the '=' sign
      awk_output=$(awk -v k1="^ *${keyword1} *=" -v k2="^ *${keyword2} *=" -v k3="^ *${keyword3} *=" '
        BEGIN { gid=""; aid=""; ver=""; gid_found=0; aid_found=0; ver_found=0 } # Initialize
        $0 ~ k1 {sub(k1, ""); aid=$0; gsub(/^ *| *$/, "", aid); aid_found=1} # Trim whitespace
        $0 ~ k2 {sub(k2, ""); ver=$0; gsub(/^ *| *$/, "", ver); ver_found=1} # Trim whitespace
        $0 ~ k3 {sub(k3, ""); gid=$0; gsub(/^ *| *$/, "", gid); gid_found=1} # Trim whitespace
        END {if (aid_found && ver_found) print gid "\n" aid "\n" ver} # Print each on a new line
      ' "$file" 2>/dev/null)


      if [[ $? -ne 0 ]]; then
          log "  Error running awk on file '$file'."
          continue
      fi

      # Read the awk output line by line
      {
       read -r group_id
       read -r artifact_id
       read -r version
      } <<< "$awk_output"


      # Check if ARTIFACT_ID and VERSION were found (GROUP_ID is optional here)
      if [[ -n "$artifact_id" && -n "$version" ]]; then
        processed_count=$((processed_count + 1))

        # Handle potentially missing groupId
        if [[ -z "$group_id" ]]; then
            log "  Warning: Keyword '$keyword3' not found in '$file'. Using placeholder: '$PLACEHOLDER_GROUP_ID'"
            group_id="$PLACEHOLDER_GROUP_ID"
        else
            log "  Found keywords: GROUP_ID='$group_id', ARTIFAC_ID='$artifact_id', VERSION='$version'"
        fi

        # --- Get Git Branch ---
        branch_name="-" # Default if not found or not a git repo
        file_dir=$(dirname "$file")
        # Check if it's inside a git repo and get root
        git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null)
        if [[ $? -eq 0 && -n "$git_root" ]]; then
            current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
            if [[ $? -eq 0 && -n "$current_branch" && "$current_branch" != "HEAD" ]]; then
                branch_name="$current_branch"
            else # Fallback for detached HEAD or other issues
                 commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null)
                 if [[ $? -eq 0 && -n $commit_hash ]]; then
                    branch_name="($commit_hash)" # Indicate it's a commit hash
                 fi
            fi
            log "  Git info: Branch/Commit '$branch_name' in root '$git_root'"
        else
            log "  Git info: Not a git repository or failed to get root/branch for '$file_dir'."
        fi
        # --- End Git Branch ---

        # --- Get Shortened Timestamp ---
        mod_unix_time=$(stat -f "%m" "$file")
        modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")
        log "  Modification time (shortened): $modified_time"
        # --- End Shortened Timestamp ---

        # Construct label with time, branch, artifact, version
        label_content="$modified_time [$branch_name] ${artifact_id}=${version}"
        log "  Constructed label: '$label_content'"

        # Store the first processed (most recent) artifact/version for the main label
        if $first_file_processed; then
          log "  This is the most recent file matching criteria."
          recent_artifact_id="$artifact_id"
          recent_version="$version"
          first_file_processed=false
        fi

        # Create a unique item name (using path hash might be safer if paths get very long)
        item_name="${item_prefix}$(echo -n "$file" | md5)" # Use MD5 hash of path for uniqueness
        log "  Generated sketchybar item name: '$item_name'"

        # --- Prepare click_script command ---
        escaped_add_script_path=$(escape_for_sketchybar "$ADD_DEPENDENCY_SCRIPT")
        escaped_group=$(escape_for_sketchybar "$group_id")
        escaped_artifact=$(escape_for_sketchybar "$artifact_id")
        escaped_version=$(escape_for_sketchybar "$version")
        popup_off_cmd_str="$sketchybar_cmd --set $main_item_name popup.drawing=off"
        escaped_popup_off_cmd=$(escape_for_sketchybar "$popup_off_cmd_str")

        # Build the command to execute on click: run script AND close popup
        # Use && so popup only closes if the script succeeds (exit code 0)
        click_command=$(printf "%s %s %s %s && %s" \
            "$escaped_add_script_path" \
            "$escaped_group" \
            "$escaped_artifact" \
            "$escaped_version" \
            "$escaped_popup_off_cmd")

        # Escape the *entire* command string again for the click_script attribute
        escaped_click_script_final=$(escape_for_sketchybar "$click_command")
        log "  Generated click script command: $click_command"
        log "  Final escaped click script: $escaped_click_script_final"
        # --- End Prepare click_script ---


        # Prepare the --add item command parts
        # Ensure item_name and popup_name are properly quoted if needed (escape_for_sketchybar handles this)
        cmd_part=$(
          printf -- "--add item %s %s --set %s label=%s click_script=%s " \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$popup_name")" \
            "$(escape_for_sketchybar "$item_name")" \
            "$(escape_for_sketchybar "$label_content")" \
            "$escaped_click_script_final" # Use the fully prepared click script command
        )

        # Add default settings
        setting_cmds=""
        for key in "${!version_item_defaults[@]}"; do
          value="${version_item_defaults[$key]}"
          # Escape key and value just in case, although keys are usually safe
          escaped_key=$(escape_for_sketchybar "$key")
          escaped_value=$(escape_for_sketchybar "$value")
          setting_cmds+=$(printf -- "--set %s %s=%s " "$(escape_for_sketchybar "$item_name")" "$escaped_key" "$escaped_value")
        done

        sketchybar_add_commands+=("$cmd_part $setting_cmds")
        log "  Added commands for item '$item_name' to batch."
      else
          log "  Required keywords ('$keyword1', '$keyword2') not found or incomplete in '$file'."
      fi
    done <<< "$find_output"

    log "Finished processing $file_count files found by 'find'. $processed_count files had required keywords."

    # 3. Execute all accumulated sketchybar commands at once
    if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
      log "Constructing final batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
      full_command="${sketchybar_add_commands[*]}"
      # log "Executing batch command: $sketchybar_cmd $full_command" # Careful logging this, can be huge
      eval "$sketchybar_cmd $full_command"
      if [[ $? -ne 0 ]]; then
          log "Error executing batch sketchybar add/set command."
      else
          log "Batch sketchybar add/set command executed."
      fi
    else
        log "No new items to add to sketchybar popup."
    fi


    # 4. Update the main label (shows latest version + current time)
    current_time=$(TZ="Asia/Shanghai" date "+%H:%M:%S") # Ensure correct timezone if needed
    if [[ -n "$recent_artifact_id" ]]; then
      summary_label="$current_time: ${recent_artifact_id}/${recent_version}"
      log "Updating main label with latest version: '$summary_label'"
    else
      summary_label="$current_time: N/A"
      log "Updating main label: No recent version found."
    fi

    $sketchybar_cmd --set "$main_item_name" label="$(escape_for_sketchybar "$summary_label")"
    if [[ $? -ne 0 ]]; then
      log "Error setting main sketchybar label."
    else
      log "Main sketchybar label updated."
    fi

    log "--- update_sketchybar function finished ---"
}

# --- Main Execution ---

log "Script started."

# Check dependencies
log "Checking dependencies..."
dependency_error=0
# Check for sketchybar
if ! command -v "$sketchybar_cmd" &> /dev/null; then
    echo "Error: sketchybar not found at '$sketchybar_cmd'. Please install or adjust the path." >&2
    dependency_error=1
fi
# Check for fswatch
if ! command -v "$fswatch_cmd" &> /dev/null; then
    echo "Error: fswatch not found at '$fswatch_cmd'. Please install (brew install fswatch) or adjust the path." >&2
    dependency_error=1
fi
# Check for jq (optional but recommended)
if ! command -v jq &> /dev/null; then
     echo "Warning: jq command not found. Popup item cleanup might be less precise. Install with 'brew install jq'." >&2
     log "jq command not found (warning issued)."
fi
# Check for git
if ! command -v git &> /dev/null; then
    echo "Error: git command not found. Cannot retrieve branch names." >&2
    dependency_error=1
fi
# Check for the add_dependency script
if [[ ! -f "$ADD_DEPENDENCY_SCRIPT" ]]; then
    echo "Error: Dependency script not found at '$ADD_DEPENDENCY_SCRIPT'. Please create it or adjust the path." >&2
    dependency_error=1
elif [[ ! -x "$ADD_DEPENDENCY_SCRIPT" ]]; then
     echo "Error: Dependency script '$ADD_DEPENDENCY_SCRIPT' is not executable. Run: chmod +x $ADD_DEPENDENCY_SCRIPT" >&2
    dependency_error=1
fi


if [[ $dependency_error -eq 1 ]]; then
    log "Exiting due to missing critical dependencies or script issues."
    exit 1
fi
log "Dependencies checked."

# Perform initial update when the script starts
log "Performing initial sketchybar update..."
update_sketchybar

# Start fswatch to monitor the directory
log "Starting file system watch on '$search_dir' for '*.$search_suffix' files..."
fswatch_args=(
    -r # recursive
    -o # batch output
    --event Created
    --event Updated
    --event Renamed
    --event MovedTo
    # Match files ending exactly with the suffix (escape the dot if suffix contains one)
    --include="\\.${search_suffix}$"
    # Exclude common large/binary directories for performance
    --exclude='/\.git/'
    --exclude='/build/'
    --exclude='/\.gradle/'
    --exclude='/\.idea/'
    --latency 0.5 # Batch events occurring within 0.5s
    "$search_dir" # Path to watch
)

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

# Use process substitution to read batched events line-by-line for logging
# The main loop still triggers only once per batch thanks to -o
"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
    log "fswatch detected changes batch:"
    # Log each event in the batch (optional detail)
    # printf '%s\n' "$event_batch_info" | while IFS= read -r line; do log "  Event detail: $line"; done

    log "Triggering sketchybar update due to fswatch event batch."
    update_sketchybar
done

ret_code=$?
log "fswatch process terminated with exit code $ret_code."
echo "Error: fswatch process terminated unexpectedly (Code: $ret_code)." >&2
exit $ret_code

