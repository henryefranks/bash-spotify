#!/bin/bash

# TODO:
#    -Add messages when toggling play/pause/shuffle
#    -Fix 'play' command
#    -Add support for song name picking

version="0.1.3"
year="2017"

# Opening Spotify if it isn't open
if ! pgrep -xq -- "Spotify"; then
    open -a Spotify -jg
    # Adequate time for it to open in background
    sleep 1
fi

# Some values to change text styling
# TODO: NONE and REGULAR could be combined?
GREEN='\033[1;32m'
NONE='\033[0m'
BOLD=$( tput bold )
ULINE=$( tput smul )
REGULAR=$( tput sgr0 )

# Checking for non-player cases first will save time
if [ "$1" == "help" ] || [ "$#" -ne 1 ]; then  # Most important case
    echo "usage: ./spotify.sh [options]"
    echo "options: info   - more info"
    echo "         help   - help (this screen)"
    echo "         track  - info about the currently playing track"
    echo "         next   - next song"
    echo "         prev   - previous song"
    echo "         play   - play (doesn't work, use toggle)"
    echo "         pause  - pause"
    echo "         toggle - toggle play/pause"
    exit
elif [ "$1" == "info" ]; then
    echo -e "${GREEN}Spotify for Bash v$version${NONE}"
    echo -e "${BOLD}© $year Henry Franks${REGULAR}"
    echo -e "Visit me on GitHub: ${ULINE}https://github.com/henryefranks${NONE}"
    echo "use 'help' for a list of commands"
    exit
fi

echo -en ${BOLD}

function showBar {
    # Printing the times and the progress bar
    echo -en "${NONE}"
    echo -n "$currentMin:"
    if (( $currentSec < 10 )); then
	echo -n "0"
    fi
    echo -n "$currentSec"
    echo -en " [${GREEN}"
    for i in {0..20}; do
	if (( i > lineLength )); then
	    echo -en "${NONE}${BOLD}-${REGULAR}"
	else
	    echo -en "${GREEN}${BOLD}=${REGULAR}"
	fi
    done
    echo -en "${NONE}] "
    echo -n "$endMin:"
    if (( $endSec < 10 )); then
	echo -n "0"
    fi
    echo "$endSec"
}

function nowPlaying {
    # Current time and duration of track
    currentPos=$( osascript -e 'tell application "Spotify"' -e "return player position" -e "end tell" )
    duration=$( osascript -e 'tell application "Spotify"' -e "return duration of current track" -e "end tell" )


    # Some maths to work out the values to show on the progress bar
    truncPos=$( printf "%.*f" 0 $currentPos )
    truncDur=$( printf "%.*f" 0 $(( $duration / 1000)) )
    ratio=$( echo "$truncPos / $truncDur" | bc -l )
    tempLength=$( echo "20 * $ratio" | bc -l )
    lineLength=$( printf "%.*f" 0 $tempLength )

    currentMin=$(( truncPos / 60 ))
    currentSec=$( printf "%.*f" 0 $( echo "$currentPos - $(( currentMin * 60 ))" | bc -l ) )

    endMin=$(( truncDur / 60 ))
    endSec=$( printf "%.*f" 0 $( echo "$truncDur - $(( endMin * 60 ))" | bc -l ) )
    echo "Now Playing:"
    echo -en ${GREEN}
    osascript -e 'tell application "Spotify"' -e 'return name of current track & " | " & artist of current track  & " | " & album of current track' -e "end tell"
    state=$( osascript -e 'tell application "Spotify"' -e 'return player state' -e 'end tell' )
    echo
    # Note: I've reversed the play and pause logos so they are the way they appear in most players (pause logo = playing, play logo = paused)
    echo -n "("
    if [ "$state" == "playing" ]; then
	echo -n "||"
    else
	echo -en "\xE2\x96\xB6"
    fi
    echo -n ")  "
    showBar
    echo -en ${NONE}
}

command="$1"

# Parsing the command
if [ $command == "track" ]; then
    nowPlaying
    echo -e "${NONE}${REGULAR}"
    exit
elif [ $command == "play" ]; then
    command='play track $2'
elif [ $command == "next" ]; then
    command="next track"
elif [ $command == "prev" ]; then
    command="previous track"
elif [ $command == "toggle" ]; then
    command="playpause"
elif [ $command == "shuffle" ]; then
    command="set shuffling to not shuffling"
fi

# Redirecting stderr into a variable to check if command was valid
err=$( osascript -e 'tell application "Spotify"' -e "$command" -e "end tell" 2>&1 > /dev/null )

# $err will be empty if there was no error
if [ "$err" != "" ]; then
    echo -e "${REGULAR}invalid command - use 'help' for a list of commands"
    exit
fi

if [ $1 == "next" ] || [ $1 == "prev" ]; then
    nowPlaying
fi

echo -en "${NONE}${REGULAR}"
exit
