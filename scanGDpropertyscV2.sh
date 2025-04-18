#!/bin/bash


# --- Configuration ---
sketchybar_cmd="/usr/local/bin/sketchybar"
search_dir="/Users/didi/AndroidStudioProjects"
search_suffix="properties"
keyword1="ARTIFACT_ID"
keyword2="VERSION"
search_depth=4
# How many days back to search for modified files
search_days=61
# Name for sketchybar items (used as a prefix for uniqueness)
item_prefix="com.versions.item."
# The main item showing the summary
main_item_name="com.versions"
# The popup associated with the main item
popup_name="popup.$main_item_name"

# --- Sketchybar Item Template ---
# Define default properties for the popup items
version_item_defaults=(
  icon=$ACTIVITY # Assuming ACTIVITY is an env var or predefined icon
  icon.padding_left=5
  label.padding_right=5
  height=20
  background.padding_left=5
  background.padding_right=5
)

# --- Helper Function ---
# Safely escape a string for use in sketchybar click_script
escape_for_sketchybar() {
  # More robust escaping for various shells/contexts
  printf '%s' "$1" | sed "s/'/'\\\\''/g; 1s/^/'/; \$s/\$/'/"
}

# --- Main Logic ---

# 1. Prepare for new items: Remove *old* dynamic items from the popup
#    Query sketchybar and use jq to find items associated with the popup
#    that start with our prefix. Made jq query more robust.
#    Requires jq: brew install jq
existing_items=""
query_output=$($sketchybar_cmd --query items 2>/dev/null) # Suppress stderr if query fails
if command -v jq >/dev/null && [[ -n "$query_output" ]] && jq -e '.' >/dev/null 2>&1 <<<"$query_output"; then
  # Only run jq if it exists and the output is valid JSON
  existing_items=$(jq -r --arg POPUP "$popup_name" --arg PREFIX "$item_prefix" \
    '.items? // [] | .[] | select(.popup? == $POPUP and (.name? // "" | startswith($PREFIX))) | .name' <<<"$query_output")
fi

remove_commands=""
# Loop through newline-separated item names
while IFS= read -r item; do
  if [[ -n "$item" ]]; then # Ensure item name is not empty
    # Add quotes for safety, though item names shouldn't have spaces usually
    remove_commands+=" --remove \"$item\""
  fi
done <<<"$existing_items"

# If any items need removal, execute the command
if [[ -n "$remove_commands" ]]; then
  # Use eval carefully as item names *should* be safe, but there's inherent risk
  eval "$sketchybar_cmd $remove_commands"
fi

# --- Alternative simpler removal (if jq fails or is not installed): ---
# Uncomment the following line and comment out the jq/removal logic above
# $sketchybar_cmd --remove "$popup_name"
# -------------------------------------------------------------------

# 2. Find candidate files, sort by modification time (newest first), and process
#    Uses `find -exec stat` to get timestamp and path, sorts, then extracts path.
#    Handles spaces in filenames but might break on filenames with newlines.

# Temporary variables
declare -a sketchybar_add_commands # Array to store add commands
recent_artifact_id=""
recent_version=""
first_file_processed=true

# Process Substitution <(...) is used to feed the while loop without a subshell
# so variables set inside (like recent_artifact_id) persist.
while IFS= read -r file; do
  # Skip empty lines potentially introduced by processing
  [[ -z "$file" ]] && continue

  # Use awk to read the file ONCE and extract BOTH values if they exist
  # We check for lines STARTING with optional space then keyword followed by '='
  # Pass keywords as awk variables to avoid injection issues
  read -r artifact_id version < <(awk -v k1="^ *${keyword1}=" -v k2="^ *${keyword2}=" '
    $0 ~ k1 {gsub(k1, ""); aid=$0; aid_found=1}
    $0 ~ k2 {gsub(k2, ""); ver=$0; ver_found=1}
    END {if (aid_found && ver_found) print aid, ver}
  ' "$file")

  # If both keywords were found by awk
  if [[ -n "$artifact_id" && -n "$version" ]]; then
    # Get formatted modification time (only for files that matched both keywords)
    # We need stat again here for the formatted date; the previous one was just for sorting.
    modified_time=$(date -r "$(stat -f "%m" "$file")" "+%m月%d日%H:%M") # Shortened format

    # Prepare label and click script content
    label_content="$modified_time: ${artifact_id}=${version}"
    click_content="${artifact_id} ${version}" # Content to copy to clipboard

    # Store the first (most recent) artifact/version found
    if $first_file_processed; then
      recent_artifact_id="$artifact_id"
      recent_version="$version"
      first_file_processed=false
    fi

    # Generate a unique item name based on the file path (replace problematic chars)
    item_name="${item_prefix}$(echo -n "$file" | tr '/.' '__')"

    # Escape content for the click script
    escaped_click_content=$(escape_for_sketchybar "$click_content")
    # Escape the command to turn off the popup as well
    popup_off_cmd_str="$sketchybar_cmd --set $main_item_name popup.drawing=off"
    escaped_popup_off_cmd=$(escape_for_sketchybar "$popup_off_cmd_str")

    # Build the --add and --set commands for this item
    # Use printf for safer command construction
    cmd_part=$(
      printf -- "--add item %s %s --set %s label=%s click_script=%s " \
        "'$item_name'" \
        "'$popup_name'" \
        "'$item_name'" \
        "$(escape_for_sketchybar "$label_content")" \
        "$(escape_for_sketchybar "echo $escaped_click_content | pbcopy; $escaped_popup_off_cmd")"
    )

    # Add default item settings
    setting_cmds=""
    for i in "${!version_item_defaults[@]}"; do
      key="${i}"
      value="${version_item_defaults[$i]}"
      # Ensure item name is quoted here too if using printf directly
      setting_cmds+=$(printf -- "--set '%s' %s=%s " "$item_name" "$key" "$value")
    done

    sketchybar_add_commands+=("$cmd_part $setting_cmds")

  fi
done < <(find "$search_dir" -maxdepth "$search_depth" -type f -name "*.$search_suffix" -mtime "-$search_days" -exec stat -f "%m %N" {} \; |
  sort -rnk1 |
  cut -d' ' -f2-)
# Explanation of the find command pipe:
# 1. find ... -exec stat -f "%m %N" {} \; : For each found file, execute `stat`.
#    - %m: Prints Unix modification timestamp.
#    - %N: Prints the filename.
#    Output per file: <timestamp> <filename> (e.g., 1678886400 /path/to/my file.txt)
# 2. sort -rnk1 : Sorts lines numerically (-n) in reverse (-r) based on the first field (-k1, the timestamp).
# 3. cut -d' ' -f2- : Cuts each line using space (' ') as the delimiter (-d) and keeps the second field through the end (-f2-). This extracts the filename, even if it contains spaces.

# 3. Execute all accumulated sketchybar commands at once
if [[ ${#sketchybar_add_commands[@]} -gt 0 ]]; then
  # Join array elements into a single command string
  full_command="${sketchybar_add_commands[*]}"
  # Use eval to execute the constructed command string
  eval "$sketchybar_cmd $full_command"
fi
# No 'else' clause to add a placeholder - keep it simple. If nothing found, popup is empty.

# 4. Update the main label
current_time=$(TZ="Asia/Shanghai" date "+%H:%M:%S")
if [[ -n "$recent_artifact_id" ]]; then
  summary_label="$current_time: ${recent_artifact_id}/${recent_version}"
else
  summary_label="$current_time: N/A"
fi

# Use escape_for_sketchybar for the label too, just in case
$sketchybar_cmd --set "$main_item_name" label="$(escape_for_sketchybar "$summary_label")"

echo "Script finished at $(date)" # For debugging
