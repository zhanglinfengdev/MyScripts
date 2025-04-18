#!/bin/bash

# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
fswatch_cmd="/usr/local/bin/fswatch" # Adjust if installed elsewhere
search_dir="/Users/linfeng/AndroidStudioProjects"
search_suffix="properties" # Used for filtering in find and fswatch pattern
keyword1="ARTIFACT_ID"
keyword2="VERSION"
search_depth=4
search_days=61
item_prefix="com.versions.item."
main_item_name="com.versions"
popup_name="popup.$main_item_name"

# --- Debugging ---
# Set DEBUG to 1 to enable verbose logging, 0 to disable
DEBUG=1 # Enable logging for testing

# --- Sketchybar Item Template ---
version_item_defaults=(
  icon=$ACTIVITY # Assuming ACTIVITY is an env var or predefined icon
  icon.padding_left=5
  label.padding_right=5
  height=20
  background.padding_left=5
  background.padding_right=5
)

# --- Helper Function ---
escape_for_sketchybar() {
  printf '%s' "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

# --- Logging Function ---
# Usage: log "Your message here"
log() {
  if [[ "$DEBUG" -eq 1 ]]; then
    # Get timestamp in desired log format
    local log_time=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$log_time] [DEBUG] $1"
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
        log "Identified old item for removal: '$item'"
        remove_commands+=" --remove \"$item\""
        items_to_remove+=("$item")
      fi
    done <<<"$existing_items"

    if [[ -n "$remove_commands" ]]; then
      log "Constructed removal command fragment: $remove_commands"
      log "Executing sketchybar removal for ${#items_to_remove[@]} item(s)..."
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

    find_output=$(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -exec stat -f "%m %N" {} \; | sort -rnk1 | cut -d' ' -f2-)
    log "Find command finished. Processing results..."

    while IFS= read -r file; do
      file_count=$((file_count + 1))
      [[ -z "$file" ]] && continue
      log "Processing file #${file_count}: '$file'"

      # Use awk to read the file ONCE
      awk_output=$(awk -v k1="^ *${keyword1}=" -v k2="^ *${keyword2}=" '
        $0 ~ k1 {gsub(k1, ""); aid=$0; aid_found=1}
        $0 ~ k2 {gsub(k2, ""); ver=$0; ver_found=1}
        END {if (aid_found && ver_found) print aid, ver}
      ' "$file" 2>/dev/null)

      if [[ $? -ne 0 ]]; then
          log "  Error running awk on file '$file'."
          continue
      fi

      read -r artifact_id version <<< "$awk_output"

      if [[ -n "$artifact_id" && -n "$version" ]]; then
        processed_count=$((processed_count + 1))
        log "  Found keywords: ARTIFAC_ID='$artifact_id', VERSION='$version'"

        # --- Get Git Branch ---
        branch_name="-" # Default if not found or not a git repo
        file_dir=$(dirname "$file")
        log "  Getting git info for directory: '$file_dir'"
        # Check if it's inside a git repo and get root
        # Redirect stderr (2>/dev/null) to avoid "fatal: not a git repository" messages
        git_root=$(git -C "$file_dir" rev-parse --show-toplevel 2>/dev/null)
        git_root_rc=$?
        if [[ $git_root_rc -eq 0 && -n "$git_root" ]]; then
            log "    Git root found: '$git_root'"
            # Get current branch name from the repo root
            # Redirect stderr in case of detached HEAD or other minor issues
            current_branch=$(git -C "$git_root" rev-parse --abbrev-ref HEAD 2>/dev/null)
            git_branch_rc=$?
             if [[ $git_branch_rc -eq 0 && -n "$current_branch" ]]; then
                branch_name="$current_branch"
                log "    Git branch found: '$branch_name'"
            else
                 log "    Could not get branch name (rc=$git_branch_rc, output='$current_branch'). Using default."
                 # Optionally try to get commit hash if branch name fails
                 commit_hash=$(git -C "$git_root" rev-parse --short HEAD 2>/dev/null)
                 if [[ $? -eq 0 && -n $commit_hash ]]; then
                    branch_name="($commit_hash)" # Indicate it's a commit hash
                    log "    Using commit hash instead: $branch_name"
                 fi
            fi
        else
            log "    Not a git repository or 'git rev-parse --show-toplevel' failed (rc=$git_root_rc)."
        fi
        # --- End Git Branch ---

        # --- Get Shortened Timestamp ---
        # Use stat -f %m to get Unix timestamp, then date -r to format
        mod_unix_time=$(stat -f "%m" "$file")
        # Format: MM/DD HH:MM (e.g., 07/26 15:30)
        modified_time=$(date -r "$mod_unix_time" "+%m/%d %H:%M")
        log "  Modification time (shortened): $modified_time"
        # --- End Shortened Timestamp ---

        # Construct label with time, branch, artifact, version
        label_content="$modified_time [$branch_name] ${artifact_id}=${version}"
        log "  Constructed label: '$label_content'"

        click_content="${artifact_id} ${version}" # Keep click content simple

        if $first_file_processed; then
          log "  This is the most recent file matching criteria."
          recent_artifact_id="$artifact_id"
          recent_version="$version"
          first_file_processed=false
        fi

        item_name="${item_prefix}$(echo -n "$file" | tr '/.' '__')"
        log "  Generated sketchybar item name: '$item_name'"
        escaped_click_content=$(escape_for_sketchybar "$click_content")
        popup_off_cmd_str="$sketchybar_cmd --set $main_item_name popup.drawing=off"
        escaped_popup_off_cmd=$(escape_for_sketchybar "$popup_off_cmd_str")

        cmd_part=$(
          printf -- "--add item %s %s --set %s label=%s click_script=%s " \
            "'$item_name'" \
            "'$popup_name'" \
            "'$item_name'" \
            "$(escape_for_sketchybar "$label_content")" \
            "$(escape_for_sketchybar "echo $escaped_click_content | pbcopy; $escaped_popup_off_cmd")"
        )

        setting_cmds=""
        for i in "${!version_item_defaults[@]}"; do
          key="${i}"
          value="${version_item_defaults[$i]}"
          setting_cmds+=$(printf -- "--set '%s' %s=%s " "$item_name" "$key" "$value")
        done

        sketchybar_add_commands+=("$cmd_part $setting_cmds")
        log "  Added commands for item '$item_name' to batch."
      else
          log "  Keywords not found or incomplete in '$file'."
      fi
    done <<< "$find_output"

    log "Finished processing $file_count files found by 'find'. $processed_count files had both keywords."

    # 3. Execute all accumulated sketchybar commands at once
    if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
      log "Constructing final batch 'add/set' command for ${#sketchybar_add_commands[@]} items..."
      full_command="${sketchybar_add_commands[*]}"
      log "Executing batch sketchybar add/set command..."
      eval "$sketchybar_cmd $full_command"
      if [[ $? -ne 0 ]]; then
          log "Error executing batch sketchybar add/set command."
      else
          log "Batch sketchybar add/set command executed."
      fi
    else
        log "No new items to add to sketchybar popup."
    fi


    # 4. Update the main label (remains unchanged, shows latest version + current time)
    current_time=$(TZ="Asia/Shanghai" date "+%H:%M:%S")
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

# Check dependencies (add git check)
log "Checking dependencies..."
dependency_error=0
if ! command -v "$sketchybar_cmd" &> /dev/null; then
    echo "Error: sketchybar not found at '$sketchybar_cmd'. Please install or adjust the path." >&2
    dependency_error=1
fi
if ! command -v "$fswatch_cmd" &> /dev/null; then
    echo "Error: fswatch not found at '$fswatch_cmd'. Please install (brew install fswatch) or adjust the path." >&2
    dependency_error=1
fi
if ! command -v jq &> /dev/null; then
     echo "Warning: jq command not found. Popup item cleanup might be less precise. Install with 'brew install jq'." >&2
     log "jq command not found (warning issued)."
fi
# Check for git command
if ! command -v git &> /dev/null; then
    echo "Error: git command not found. Cannot retrieve branch names." >&2
    dependency_error=1
fi


if [[ $dependency_error -eq 1 ]]; then
    log "Exiting due to missing critical dependencies."
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
    # Match files ending exactly with .properties (escape the dot)
    --include="\\.$search_suffix$"
    # Add excludes for common large/binary directories if desired
    # --exclude='/\.git/'
    # --exclude='/build/'
    # --exclude='/\.gradle/'
    --latency 0.5 # Batch events occurring within 0.5s
    "$search_dir" # Path to watch
)

log "Executing fswatch command: $fswatch_cmd ${fswatch_args[*]}"

"$fswatch_cmd" "${fswatch_args[@]}" | while IFS= read -r event_batch_info || [[ -n "$event_batch_info" ]]; do
    log "fswatch detected changes:"
    while IFS= read -r line; do
      log "  Event detail: $line"
    done <<< "$event_batch_info"

    log "Triggering sketchybar update due to fswatch event."
    update_sketchybar
done

ret_code=$?
log "fswatch process terminated with exit code $ret_code."
echo "Error: fswatch process terminated unexpectedly." >&2
exit $ret_code


