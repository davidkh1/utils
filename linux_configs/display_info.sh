#!/bin/bash
# Utility to find screens where a window is displayed.

# Get the list of windows
windows=$(wmctrl -l)
echo "Window ID | Desktop No. | Window Title | Display(s) | Display Count"

# Loop through each window and find its display
while IFS= read -r line; do
    window_id=$(echo "$line" | awk '{print $1}')
    desktop_no=$(echo "$line" | awk '{print $2}')
    window_title=$(echo "$line" | cut -d " " -f 5-)

    # Get window geometry
    geom=$(xdotool getwindowgeometry $window_id)
    geom_position=$(echo "$geom" | grep "Position" | awk '{print $2}')
    geom_x=$(echo $geom_position | cut -d "," -f1)
    geom_y=$(echo $geom_position | cut -d "," -f2)
    geom_size=$(echo "$geom" | grep "Geometry" | awk '{print $2}')
    geom_width=$(echo $geom_size | cut -d "x" -f1)
    geom_height=$(echo $geom_size | cut -d "x" -f2)

    # Variables to track displays
    displayed_on=""
    display_count=0

    # Determine display
    while IFS= read -r display; do
        display_name=$(echo $display | awk '{print $1}')
        display_geom=$(echo $display | grep -oP '\d+x\d+\+\d+\+\d+')
        display_x=$(echo $display_geom | cut -d "+" -f2)
        display_y=$(echo $display_geom | cut -d "+" -f3)
        display_width=$(echo $display_geom | cut -d "x" -f1)
        display_height=$(echo $display_geom | cut -d "+" -f1 | cut -d "x" -f2)

        # Calculate window edges
        window_right_edge=$((geom_x + geom_width))
        window_bottom_edge=$((geom_y + geom_height))
        
        # Check if the window overlaps with this display
        if [[ "$geom_x" -lt "$((display_x + display_width))" && "$window_right_edge" -gt "$display_x" && "$geom_y" -lt "$((display_y + display_height))" && "$window_bottom_edge" -gt "$display_y" ]]; then
            if [[ -n "$displayed_on" ]]; then
                displayed_on+=", "
            fi
            displayed_on+="$display_name"
            display_count=$((display_count + 1))
        fi
    done <<< "$(xrandr | grep " connected")"

    echo "$window_id | $desktop_no | $window_title | $displayed_on | $display_count"

done <<< "$windows"
