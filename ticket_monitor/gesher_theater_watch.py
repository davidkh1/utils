#!/usr/bin/env python3
# Usage:
# Delete the state dir, then run once:
#
#   $ rm -r ~/Library/Caches/gesher-watch
#   $ ~/bin/gesher_theater_watch.py --stdout

import argparse
import hashlib
import logging
import os
import re
import subprocess
from pathlib import Path
from typing import List, Optional

logger = logging.getLogger(__name__)


ENABLE_IMESSAGE = True
IMESSAGE_BUDDY = "your.email@example.com"
SHOWS = {
    2839: "Souls",
    2752: "Richard III",
}
YEARS = [2026]
MONTH_START = 1
MONTH_END = 8

CALENDAR_BASE_URL = "https://www.gesher-theatre.co.il/he/company/a/calendar/"
DEFAULT_LOGFILE = Path.home() / "Library" / "Logs" / "gesher_theater_watch.log"
STATE_DIR = Path.home() / "Library" / "Caches" / "gesher-watch"
APPLESCRIPT_PATH = Path(__file__).with_name("send_imessage.applescript")
_TICKET_STATUS_RE = re.compile(r">\s*(?:לרכישה|הכרטיסים אזלו)\s*<")


def parse_args(argv: Optional[List[str]] = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Monitor Gesher Theater calendar for changes.")
    parser.add_argument(
        "--stdout",
        action="store_true",
        help="Write logs to stdout (useful for testing). Default is to log to a file.",
    )
    parser.add_argument(
        "--logfile",
        default=str(DEFAULT_LOGFILE),
        help=f"Log file path (default: {DEFAULT_LOGFILE}). Ignored with --stdout.",
    )
    return parser.parse_args(argv)


def _sha256_hex(text: str) -> str:
    return hashlib.sha256(text.encode("utf-8")).hexdigest()


def generate_urls() -> list[dict]:
    urls: list[dict] = []
    for show_id, show_name in SHOWS.items():
        for year in YEARS:
            for month in range(MONTH_START, MONTH_END + 1):
                urls.append({
                    "url": f"{CALENDAR_BASE_URL}?Month={month}&Year={year}&ShowID={show_id}",
                    "show_id": show_id,
                    "show_name": show_name,
                    "month": month,
                    "year": year,
                })
    return urls


def fetch_html(url: str) -> Optional[str]:
    env = os.environ.copy()
    env["PATH"] = "/usr/bin:/bin:/usr/sbin:/sbin:/opt/homebrew/bin:/usr/local/bin"

    proc = subprocess.run(
        ["/usr/bin/curl", "-fsSL", url],
        capture_output=True,
        text=True,
        env=env,
    )
    if proc.returncode != 0:
        return None
    return proc.stdout


def count_show_dates(html: str) -> int:
    html = html.replace("\r", "")
    return len(_TICKET_STATUS_RE.findall(html))


def notify_imessage(message: str) -> None:
    if not ENABLE_IMESSAGE:
        return

    if not APPLESCRIPT_PATH.exists():
        raise FileNotFoundError(f"Missing AppleScript file: {APPLESCRIPT_PATH}")

    subprocess.run(
        ["/usr/bin/osascript", str(APPLESCRIPT_PATH), IMESSAGE_BUDDY, message],
        check=False,
        capture_output=True,
        text=True,
    )


def monitor_site() -> int:
    STATE_DIR.mkdir(parents=True, exist_ok=True)
    logger.info("running gesher_theater_watch")

    changes: list[str] = []

    for item in generate_urls():
        url = item["url"]
        show_name = item["show_name"]
        month = item["month"]
        year = item["year"]

        key = _sha256_hex(url)
        state_file = STATE_DIR / f"{key}.available_count"

        html = fetch_html(url)
        if html is None:
            new_state = "FETCH_ERROR"
        else:
            new_state = str(count_show_dates(html))

        old_state = state_file.read_text(encoding="utf-8").strip() if state_file.exists() else ""

        if new_state == old_state:
            continue

        state_file.write_text(new_state, encoding="utf-8")

        if not old_state:
            logger.info(f"INIT {show_name} {month}/{year} [show_dates={new_state}]")
            continue

        if new_state == "FETCH_ERROR":
            logger.info(f"FETCH_FAIL {show_name} {month}/{year}")
            changes.append(f"FETCH_FAIL: {show_name} {month}/{year}")
            continue

        if old_state == "FETCH_ERROR":
            logger.info(f"RECOVER {show_name} {month}/{year}: now {new_state} dates")
            changes.append(f"{show_name} {month}/{year}: {new_state} dates (recovered)")
        else:
            logger.info(f"CHANGE {show_name} {month}/{year}: now {new_state} dates (was {old_state})")
            changes.append(f"{show_name} {month}/{year}: {new_state} dates (was {old_state})")

    if changes:
        if len(changes) == 1:
            notify_imessage(f"Gesher: {changes[0]}")
        else:
            msg = f"Gesher: {len(changes)} schedules updated:"
            for change in changes:
                msg += f"\n- {change}"
            notify_imessage(msg)

    return 0


def setup_logging(to_stdout: bool, logfile: Path) -> None:
    """Configure logging to stdout or file."""
    if to_stdout:
        handler = logging.StreamHandler()
    else:
        logfile.parent.mkdir(parents=True, exist_ok=True)
        handler = logging.FileHandler(logfile)

    handler.setFormatter(logging.Formatter("%(asctime)s %(message)s", "%Y-%m-%d %H:%M:%S"))
    logger.addHandler(handler)
    logger.setLevel(logging.INFO)


def main(argv: Optional[List[str]] = None) -> int:
    args = parse_args(argv)
    setup_logging(
        to_stdout=args.stdout,
        logfile=Path(args.logfile).expanduser(),
    )
    return monitor_site()


if __name__ == "__main__":
    raise SystemExit(main())
