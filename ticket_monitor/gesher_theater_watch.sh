#!/usr/bin/env bash
set -euo pipefail

PATH="/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

# Where to message you (must be reachable via iMessage on this Mac)
IMESSAGE_BUDDY="your.email@example.com"
SHOW_IDS=(2839)  # Shows to monitor (find ShowID in the Gesher website URLs)
YEARS=(2026 2027)  # Years to monitor, example: YEARS=(2026) or YEARS=(2026 2027)
MONTH_START=3
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

LOGFILE="$HOME/Library/Logs/gesher_theater_watch.log"
mkdir -p "$(dirname "$LOGFILE")"
echo "$(date '+%Y-%m-%d %H:%M:%S') ran gesher_theater_watch" >> "$LOGFILE"

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
  local html="$1"
  local shows
  shows="$(printf "%s" "$html" | tr -d '\r' | grep -o '<span>[^<]*[0-9]\+\.[0-9]\+ - [0-9]\+</span>' | sed 's/ - [0-9].*//' | sed 's/<span>//' | sort -u | tr '\n' '|')"

  if [[ -n "$shows" ]]; then
    printf "shows:%s" "$shows"
    return 0
  fi

  # Fallback: if no shows found, return a marker
  printf "shows:none"
}

# Collect changes for batched notification
CHANGES=()

for url in "${URLS[@]}"; do
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
      show_count="$(printf "%s" "$payload" | cut -d: -f2- | tr '|' '\n' | grep -v '^$' | wc -l | tr -d ' ')"
      echo "$(date '+%Y-%m-%d %H:%M:%S') INIT $url [$show_count unique shows]" >> "$LOGFILE"
      continue
    fi

    if [[ -z "$html" ]]; then
      echo "$(date '+%Y-%m-%d %H:%M:%S') FETCH_FAIL $url" >> "$LOGFILE"
      CHANGES+=("FETCH_FAIL: ${url}")
    else
      # Count shows
      show_list="$(printf "%s" "$payload" | cut -d: -f2-)"
      show_count="$(printf "%s" "$show_list" | tr '|' '\n' | grep -v '^$' | wc -l | tr -d ' ')"

      # Extract month and year from URL
      month="$(printf "%s" "$url" | grep -o 'Month=[0-9]\+' | cut -d= -f2)"
      year="$(printf "%s" "$url" | grep -o 'Year=[0-9]\+' | cut -d= -f2)"

      echo "$(date '+%Y-%m-%d %H:%M:%S') CHANGE Month=$month Year=$year: now $show_count shows" >> "$LOGFILE"
      CHANGES+=("$month/$year: $show_count shows")
    fi
  fi
done

# Send batched notification if there were any changes
if [[ ${#CHANGES[@]} -gt 0 ]]; then
  if [[ ${#CHANGES[@]} -eq 1 ]]; then
    notify_imessage "Gesher: ${CHANGES[0]}"
  else
    # Multiple changes - send summary
    msg="Gesher: ${#CHANGES[@]} schedules updated:"
    for change in "${CHANGES[@]}"; do
      msg="${msg}\n- ${change}"
    done
    notify_imessage "${msg}"
  fi
fi
