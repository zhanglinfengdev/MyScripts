
"fjkdslfjkdslfjk" >> ~/fafafa.txt

/usr/bin/osascript -e 'tell application "System Events" to key code 103'


# notifyMe() {
#     osascript -e 'display notification "'"$1"'" with title "'"$2"'"
# }

# notifyMe "enhance switch" "enhance"

/usr/bin/osascript  <<EOF
    display notification "$(pbpaste)" with title "copyshellcmd"
EOF


