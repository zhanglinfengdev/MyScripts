#!/bin/bash

# --- Configuration ---
LOG_FILE="/tmp/get_focused_cwd.log"
CWD_OUTPUT_FILE="/tmp/yabai_focus_cwd.log" # Standard output file
YABAI_CMD_PATH="/usr/local/bin/yabai"     # Adjust if needed
JQ_CMD_PATH="/usr/local/bin/jq"         # Adjust if needed
KITTY_CMD_PATH="/usr/local/bin/kitty"   # Adjust if needed

# --- Helper Functions ---

log_message() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$$] $1" >> "$LOG_FILE"
}

# Function to get CWD for Kitty
get_kitty_cwd() {
    local window_id="$1"
    log_message "Attempting to get CWD for Kitty (Window ID: $window_id)"

    if [[ ! -x "$KITTY_CMD_PATH" ]]; then
        log_message "Error: kitty command not found or not executable at '$KITTY_CMD_PATH'"
        return 1
    fi
     if [[ ! -x "$JQ_CMD_PATH" ]]; then
        log_message "Error: jq command not found or not executable at '$JQ_CMD_PATH'"
        return 1
    fi

    local kitty_state_json
    kitty_state_json=$("$KITTY_CMD_PATH" @ ls 2>> "$LOG_FILE")
    local kitty_ls_exit_code=$?

    if [[ $kitty_ls_exit_code -ne 0 ]]; then
        log_message "Error: 'kitty @ ls' failed (Exit Code: $kitty_ls_exit_code). Is kitty running? Remote control enabled?"
        # Optional: Send notification
        # /usr/bin/osascript -e "display notification \"'kitty @ ls' failed (code $kitty_ls_exit_code)\" with title \"Yabai Script Error\""
        return 1
    fi

    # jq query to find the active pane in the specific OS window
    local jq_query='.[] | select(.is_active == true) | .os_windows[] | select(.id == $id) | .tabs[] | select(.is_active == true) | .windows[] | select(.is_active == true) | .foreground_processes[0].cwd // empty'
    local cwd
    # Use <<< to pass variable content as stdin to jq
    cwd=$(echo "$kitty_state_json" | "$JQ_CMD_PATH" --argjson id "$window_id" -r "$jq_query" 2>> "$LOG_FILE")
    local jq_exit_code=$?

    if [[ $jq_exit_code -eq 0 ]] && [[ -n "$cwd" ]]; then
        log_message "Success (Kitty): Found CWD: $cwd"
        echo "$cwd" # Output CWD to be captured
        return 0
    elif [[ $jq_exit_code -ne 0 ]]; then
         log_message "Error (Kitty): jq query failed (Exit Code: $jq_exit_code)."
         return 1
    else
        log_message "Warning (Kitty): jq succeeded but CWD is empty or not found for Window ID $window_id."
        return 1 # Indicate CWD not found
    fi
}

# Function to get CWD for iTerm2 (using AppleScript)
get_iterm_cwd() {
    local window_id="$1" # Note: iTerm AppleScript usually works with window references, not Yabai IDs directly
    log_message "Attempting to get CWD for iTerm2"

    # This AppleScript targets the *current* iTerm window, which *should* be
    # the one that just gained focus. Might be less reliable in rapid changes.
    local cwd
    cwd=$(osascript -e '
        tell application "iTerm"
            try
                tell current window
                    tell current session
                        get variable "path"
                    end tell
                end tell
            on error
                return "" -- Return empty string on error
            end try
        end tell
    ' 2>> "$LOG_FILE")

    if [[ -n "$cwd" ]]; then
        log_message "Success (iTerm): Found CWD: $cwd"
        echo "$cwd"
        return 0
    else
        log_message "Warning (iTerm): Could not get CWD via AppleScript. Is iTerm running? Correct permissions?"
        return 1
    fi
}

# Function placeholder for Android Studio (Difficult!)
get_android_studio_cwd() {
    local pid="$1"
    log_message "Attempting CWD for Android Studio (PID: $pid) - Generally unreliable"
    # Option 1: Try lsof (Likely shows launch CWD, not project CWD)
    local lsof_cwd
    lsof_cwd=$(lsof -p "$pid" -a -d cwd -Fn | grep '^n' | cut -c 2-)
     if [[ -n "$lsof_cwd" ]]; then
         log_message "Info (Android Studio): lsof found CWD: $lsof_cwd (May not be project root)"
         echo "$lsof_cwd" # Return the best guess
         return 0
     else
         log_message "Warning (Android Studio): Could not determine CWD via lsof."
         return 1
     fi
    # Option 2: AppleScript (Requires specific knowledge of AS dictionary, may not exist/work)
    # log_message "Note: Reliable CWD for Android Studio often requires specific plugins or is unavailable."
    # return 1
}

# Function placeholder for Finder
get_finder_cwd() {
    log_message "Attempting CWD for Finder"
    local cwd
    # Get the path of the frontmost Finder window's target
    cwd=$(osascript -e '
        tell application "Finder"
            try
                get POSIX path of (target of front window as alias)
            on error
                return ""
            end try
        end tell
    ' 2>> "$LOG_FILE")

     if [[ -n "$cwd" ]]; then
        log_message "Success (Finder): Found CWD: $cwd"
        echo "$cwd"
        return 0
    else
        log_message "Warning (Finder): Could not get CWD. No Finder window open or other issue."
        # Fallback to home directory?
        # echo "$HOME"
        # return 0
        return 1
    fi
}

# --- Main Script ---

# Clear log file on start (optional)
# > "$LOG_FILE"

log_message "--- Script Start ---"

# Check for required commands
if ! command -v "$YABAI_CMD_PATH" &> /dev/null; then
    log_message "Error: yabai command not found at '$YABAI_CMD_PATH'"
    exit 1
fi
if ! command -v "$JQ_CMD_PATH" &> /dev/null; then
     log_message "Error: jq command not found at '$JQ_CMD_PATH'"
     exit 1
fi

yabai_window_id="$1"
if [[ -z "$yabai_window_id" ]]; then
    log_message "Error: No Yabai Window ID received."
    log_message "--- Script End (Error) ---"
    exit 1
fi
log_message "Received Yabai Window ID: $yabai_window_id"

# Query Yabai for window details
window_info=$("$YABAI_CMD_PATH" -m query --windows --window "$yabai_window_id")
query_exit_code=$?

if [[ $query_exit_code -ne 0 ]]; then
    log_message "Error: Yabai query failed for window ID $yabai_window_id (Exit Code: $query_exit_code)"
    # Fallback: Maybe clear the output file?
    # echo "Error: Yabai Query Failed" > "$CWD_OUTPUT_FILE"
    log_message "--- Script End (Yabai Query Error) ---"
    exit 1
fi

# Extract App Name and PID
app_name=$("$JQ_CMD_PATH" -r '.app // empty' <<< "$window_info")
pid=$("$JQ_CMD_PATH" -r '.pid // empty' <<< "$window_info")
jq_exit_code=$?

if [[ $jq_exit_code -ne 0 ]]; then
    log_message "Error: jq failed to parse Yabai output (Exit Code: $jq_exit_code)"
    log_message "--- Script End (jq Parse Error) ---"
    exit 1
fi

log_message "Focused App: '$app_name' (PID: $pid, Window ID: $yabai_window_id)"

# --- Application Specific Logic ---
final_cwd=""
app_processed=false

case "$app_name" in
    "kitty")
        final_cwd=$(get_kitty_cwd "$yabai_window_id")
        app_processed=true
        ;;
    "iTerm2")
        # Note: iTerm function uses front window, not Yabai ID directly
        final_cwd=$(get_iterm_cwd "$yabai_window_id")
        app_processed=true
        ;;
    "Code") # VS Code
         log_message "Info: VS Code CWD usually requires workspace API or extensions. No standard method implemented."
         # Potentially try lsof as a basic guess?
         # final_cwd=$(lsof -p "$pid" -a -d cwd -Fn | grep '^n' | cut -c 2-)
         app_processed=true
         ;;
     "Android Studio"*) # Match different versions like "Android Studio Electric Eel"
         final_cwd=$(get_android_studio_cwd "$pid")
         app_processed=true
         ;;
      "Finder")
          final_cwd=$(get_finder_cwd)
          app_processed=true
          ;;
      "Alacritty" | "WezTerm" | "Hyper" | "Terminal")
          # Generic Terminal Approach (Less Reliable): Try lsof on the process PID
          # This often gets the CWD the *terminal app* was launched in, or its own internal CWD,
          # NOT necessarily the CWD of the *shell* in the active pane.
          log_message "Info: Attempting generic CWD fetch for '$app_name' using lsof on PID $pid (may be inaccurate)."
          lsof_cwd=$(lsof -p "$pid" -a -d cwd -Fn 2>/dev/null | grep '^n' | cut -c 2-)
          if [[ -n "$lsof_cwd" ]]; then
              log_message "Info ($app_name): lsof found CWD: $lsof_cwd"
              final_cwd="$lsof_cwd"
          else
              log_message "Warning ($app_name): Could not determine CWD via lsof."
          fi
          app_processed=true
          ;;

    *)
        log_message "Info: Application '$app_name' has no specific CWD logic implemented."
        # Optionally, clear the CWD file or write a default value
        # final_cwd="$HOME" # Default to home? Or leave empty?
        app_processed=true # Mark as processed even if no CWD found
        ;;
esac

# --- Output Result ---
if [[ -n "$final_cwd" ]]; then
    log_message "Final CWD determined: $final_cwd"
    echo "$final_cwd" > "$CWD_OUTPUT_FILE"
    log_message "CWD written to $CWD_OUTPUT_FILE"
elif [[ "$app_processed" == true ]]; then
    # App was handled, but no CWD found (or not applicable)
    log_message "No valid CWD determined for '$app_name'. Clearing output file."
    # Clear the file or write a placeholder like "N/A" or "/"
    # echo "N/A" > "$CWD_OUTPUT_FILE"
     > "$CWD_OUTPUT_FILE" # Clear the file
else
    # Should not happen if case statement covers *
     log_message "Warning: Application '$app_name' was not processed by the case statement."
fi

log_message "--- Script End ---"
exit 0

