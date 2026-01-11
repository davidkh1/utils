-- Usage:
-- osascript send_imessage.applescript "your.email@example.com" "Test message from AppleScript"
on run argv
	if (count of argv) < 2 then
		error "Usage: osascript send_imessage.applescript <buddy> <message>"
	end if

	set buddyIdentifier to item 1 of argv
	set messageText to item 2 of argv

	tell application "Messages"
		set targetService to 1st service whose service type = iMessage
		set targetBuddy to buddy buddyIdentifier of targetService
		send messageText to targetBuddy
	end tell
end run

