#!/bin/bash
# Prompt the user to confirm or change the working directory on each session start.
# Saves the last-used dir so it appears as the default next time.
#
# Usage: source this script (do NOT run it as a subprocess — cd must affect the caller)
#   . /usr/local/bin/pick-working-dir "/config"

_pwd_default="${1:-/config}"
_pwd_state="${ANTHROPIC_HOME}/last-working-dir"

# Load last used dir, fall back to configured default
if [ -f "$_pwd_state" ]; then
    _pwd_last=$(cat "$_pwd_state")
else
    _pwd_last="$_pwd_default"
fi

printf "\nWorking directory [%s]: " "$_pwd_last"
read -r _pwd_chosen
_pwd_chosen="${_pwd_chosen:-$_pwd_last}"

# Persist choice
echo "$_pwd_chosen" > "$_pwd_state"

if ! cd "$_pwd_chosen" 2>/dev/null; then
    printf "Directory '%s' not found, falling back to /config\n" "$_pwd_chosen"
    cd /config
fi

unset _pwd_default _pwd_state _pwd_last _pwd_chosen
