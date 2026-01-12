# Gesher Theater Ticket Monitor

A cron-based monitoring script for Gesher Theater's show calendar. Tracks when new show dates become available and sends iMessage notifications.

## Requirements
- macOS (uses osascript for iMessage notifications)
- curl (for fetching web pages)
- iMessage account configured on the Mac

## Installation
1. Copy the script to your local bin directory:
   ```bash
   cp gesher_theater_watch.py ~/bin/
   cp send_imessage.applescript ~/bin/
   chmod +x ~/bin/gesher_theater_watch.py
   ```

2. Edit `~/bin/gesher_theater_watch.py` and set `IMESSAGE_BUDDY`.

3. Set up cron job to run every 8 hours:
   ```bash
   crontab -e
   ```
   
   Add this line:
   ```
   0 */8 * * * $HOME/bin/gesher_theater_watch.py
   ```

4. Test the script manually first, with output to your terminal:
   ```bash
   ~/bin/gesher_theater_watch.py --stdout
   ```

   The first run will initialize (no notifications). Subsequent runs will notify on changes.

## How It Works

1. Fetches each configured Gesher Theater calendar page
2. Counts show-date entries by matching "לרכישה" or "הכרטיסים אזלו"
3. Compares count with previous run (stored per-URL)
4. Sends iMessage notification if count changed
5. Logs to `~/Library/Logs/gesher_theater_watch.log` by default (or to stdout with `--stdout`)

## Logs

View logs:
```bash
tail -f ~/Library/Logs/gesher_theater_watch.log
```
