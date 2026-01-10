# Gesher Theater Ticket Monitor

A cron-based monitoring script for Gesher Theater's show calendar. Tracks when new show dates become available and sends iMessage notifications.

## Requirements
- macOS (uses osascript for iMessage notifications)
- curl (for fetching web pages)
- iMessage account configured on the Mac

## Installation
1. Copy the script to your local bin directory:
   ```bash
   cp gesher_watch_multi.sh ~/bin/
   chmod +x ~/bin/gesher_watch_multi.sh
   ```

2. Set up cron job to run every 6 hours:
   ```bash
   crontab -e
   ```
   
   Add this line:
   ```
   0 */6 * * * /bin/bash $HOME/bin/gesher_watch_multi.sh >> $HOME/Library/Logs/gesher_watch_multi.log 2>&1
   ```

3. Test the script manually first:
   ```bash
   ~/bin/gesher_watch_multi.sh
   ```

   The first run will initialize (no notifications). Subsequent runs will notify on changes.

## How It Works

1. Fetches each configured Gesher Theater calendar page
2. Counts show date entries using pattern matching
3. Compares count with previous run (stored as hash)
4. Sends iMessage notification if count changed
5. Logs all activity to `~/Library/Logs/gesher_watch_multi.log`

## Logs

View logs:
```bash
tail -f ~/Library/Logs/gesher_watch_multi.log
```
