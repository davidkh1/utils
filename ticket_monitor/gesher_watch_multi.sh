#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

# Where to message you (must be reachable via iMessage on this Mac)
IMESSAGE_BUDDY="<YOUR_APPLE_REGISTERED_EMAIL"

# ============================================================
# CONFIGURATION
# ============================================================

# Shows to monitor (find ShowID in the Gesher website URLs)
# Add multiple shows by adding more IDs, use blank between IDs.
SHOW_IDS=(
  2839  # "Neshamot"
)

YEARS=(2026 2027)

MONTH_START=1
MONTH_END=12

# Generate URLs from configuration
URLS=()
for show_id in "${SHOW_IDS[@]}"; do
  for year in "${YEARS[@]}"; do
    for month in $(seq $MONTH_START $MONTH_END); do
      URLS+=("https://www.gesher-theatre.co.il/he/company/a/calendar/?Month=${month}&Year=${year}&ShowID=${show_id}")
    done
  done
done

LOGFILE="$HOME/Library/Logs/gesher_watch_multi.log"
mkdir -p "$(dirname "$LOGFILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S') ran gesher_watch_multi" >> "$LOGFILE"

STATE_DIR="$HOME/Library/Caches/gesher-watch"
mkdir -p "$STATE_DIR"

notify_imessage () {
  local msg="$1"
  /usr/bin/osascript <<APPLESCRIPT
tell application "Messages"
  set targetService to 1st service whose service type = iMessage
  set targetBuddy to buddy "${IMESSAGE_BUDDY}" of targetService
  send "${msg}" to targetBuddy
end tell
APPLESCRIPT
}

extract_payload () {
  # Count the number of available show dates (each show date has a span with the pattern: showname - date - id)
  local html="$1"

  # Count show date entries in the format: <span>show - DD.M - ID</span>
  local count
  count="$(printf "%s" "$html" | tr -d '\r' | grep -o '<span>[^<]*[0-9]\+\.[0-9]\+ - [0-9]\+</span>' | wc -l | tr -d ' ')"

  if [[ -n "$count" && "$count" -gt 0 ]]; then
    # Return just the count - this represents available show dates
    printf "show_dates:%s" "$count"
    return 0
  fi

  # Fallback: if no show dates found, return a marker
  printf "show_dates:0"
}

for url in "${URLS[@]}"; do
  # Safe filename from URL
  key="$(printf "%s" "$url" | /usr/bin/shasum -a 256 | awk '{print $1}')"
  hash_file="$STATE_DIR/$key.hash"

  html="$(/usr/bin/curl -fsSL "$url" || true)"
  if [[ -z "$html" ]]; then
    # Avoid repeated spam if temporary failure: hash the error state too
    new_hash="$(printf "FETCH_ERROR:%s" "$url" | /usr/bin/shasum -a 256 | awk '{print $1}')"
  else
    payload="$(extract_payload "$html")"
    new_hash="$(printf "%s" "$payload" | /usr/bin/shasum -a 256 | awk '{print $1}')"
  fi

  old_hash="$(cat "$hash_file" 2>/dev/null || true)"

  if [[ "$new_hash" != "$old_hash" ]]; then
    printf "%s" "$new_hash" > "$hash_file"

    if [[ -z "$old_hash" ]]; then
      # first run: initialise quietly (no alert)
      echo "$(date '+%Y-%m-%d %H:%M:%S') INIT $url [$(printf "%s" "$payload" | cut -d: -f2) shows]" >> "$LOGFILE"
      continue
    fi

    if [[ -z "$html" ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') FETCH_FAIL $url" >> "$LOGFILE"
      notify_imessage "Gesher watcher: fetch failed for ${url}"
    else
      # Extract new count for the notification
      new_count="$(printf "%s" "$payload" | cut -d: -f2)"

      # Extract month from URL for clearer notification
      month="$(printf "%s" "$url" | grep -o 'Month=[0-9]\+' | cut -d= -f2)"

      echo "$(date '+%Y-%m-%d %H:%M:%S') CHANGE Month=$month now has $new_count show dates" >> "$LOGFILE"
      notify_imessage "Gesher: Month $month schedule updated - now $new_count show dates available"
    fi
  fi
done
