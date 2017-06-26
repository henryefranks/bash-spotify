#!/bin/bash

# TODO:
#		-Add support for song name picking
#		-Add proper flag support:
#			-Use getopts
#			-Flags for:
#				-Progress bar
#				-Now playing with next/previous

stty -echo

# Some values to change text styling
# TODO: Could NONE and REGULAR be combined?
GREEN='\033[1;32m'
NONE='\033[0m'
BOLD=$(tput bold)
ULINE=$(tput smul)
REGULAR=$(tput sgr0)

function clean_exit {
	# General cleanup (fixing cursor style and output colour)
	# This function is run instead of just exiting in most cases to keep the output from inheriting styles from echo statements, as a precaution
	echo -en "${NONE}${REGULAR}"
	stty echo
	exit
}

function interrupt {
	clear
	tput cnorm # Only needs to be run in player mode
	clean_exit
}

# Checking if running on a mac (stopping if not)
if [ $(uname) != "Darwin" ]; then
	echo "Sorry, this only works on macOS"
	clean_exit
fi

if [ "$1" == "quit" ]; then
	echo "Quitting Spotify"
	osascript -e 'quit app "Spotify"'
	clean_exit
fi

version="0.1.4"
year="2017"

# Opening Spotify if it isn't open
if ! pgrep -xq -- "Spotify"; then
	open -a Spotify -jg
	# Adequate time for it to open in background
	sleep 1
fi

if [ "$#" -eq 0 ]; then
	clean_exit
fi

# Checking is the album flag is active without allowing other flags
# Also, setting the return of the AppleScript appropriately
album='return name of current track & " | " & artist of current track'
if [ "$#" -eq 1 ]; then
	validNum=1
else
	validNum=0
	if [ "$#" -gt 1 ]; then # The below would throw an error if there were no arguments given
		if [ $2 == "-a" ]; then # A somewhat temporary solution, will fix to allow for other options later
			validNum=1
			album='return name of current track & " | " & artist of current track  & " | " & album of current track'
		fi
	fi
fi

#-------------------Testing new functionality-------------------#

while test $# -gt 1; do
	case "$2" in
		-q)
			echo "q -- testing"
			shift
			;;
		-t)
			echo "t -- testing"
			shift
			;;
		*)
			break
			;;
	esac
done

validNum=1

#---------------------------------------------------------------#

# Checking for non-player cases first will save time
if [ "$1" == "help" ] || [ "$validNum" -ne 1 ]; then  # Most important case
	echo "usage: ./spotify.sh [options] [-a]"
	echo "options: info   - more info"
	echo "         help   - help (this screen)"
	echo "         quit   - quit Spotify"
	echo "         track  - info about the currently playing track"
	echo "         next   - next song"
	echo "         prev   - previous song"
	echo "         play   - play"
	echo "         pause  - pause"
	echo "         toggle - toggle play/pause"
	echo "         player - live player"
	echo "use -a flag to show album (off by default)"
	clean_exit
elif [ "$1" == "info" ]; then
	echo -e "${GREEN}Spotify for Bash v$version${NONE}"
	echo -e "${BOLD}© $year Henry Franks${REGULAR}"
	echo -e "Visit me on GitHub: ${ULINE}https://github.com/henryefranks${NONE}"
	echo "use 'help' for a list of commands"
	clean_exit
fi

# Player mode
if [ $1 = "player" ]; then
	# Adding trap for clean exit (ctrl-c)
	trap interrupt INT

	printf '\e[8;6;70t'
	# Alternatively (requires X11): resize -s 6 70 2>&1 > /dev/null
	tput civis
	clear

	oldLen=0
	oldOut=""
	len=0

	command="$0 track" # Calling itself because I'm lazy
	if [ "$#" -eq 2 ]; then # Support for album flag
		command="$0 track $2"
	fi
	while :
	do
		oldLen=$len
		tput cup -0
		oldOut=$output
		output=$(eval $command)
		willEcho=false
		if [ "$output" != "$oldOut" ]; then
			willEcho=true
		fi
		len=$(echo -n $output | wc -m)
		if [ "$oldLen" != "$len" ]; then
			# Clearing output if not properly overwritten to avoid graphical glitches
			clear
			willEcho=true
		fi
		if [ willEcho ]; then
			echo "$output"
		fi
		sleep 0.1 # Using a 10Hz refresh rate to keep the second intervals regular
	done
fi

echo -en ${BOLD}

function show_bar {
	# Printing the times and the progress bar
	echo -en "${NONE}"
	echo -n "$currentMin:"
	if (($currentSec < 10)); then
		echo -n "0"
	fi
	if [ "$currentSec" == "-0" ]; then # Fixing a bug where it would display, for example 1:0-0 (currentSec was set to -0)
		currentSec="0"
	fi
	echo -n "$currentSec"
	echo -en " [${GREEN}"
	for i in {0..20}; do
		if ((i > lineLength)); then
			echo -en "${NONE}${BOLD}-${REGULAR}"
		else
			echo -en "${GREEN}${BOLD}=${REGULAR}"
		fi
	done
	echo -en "${NONE}] "
	echo -n "$endMin:"
	if (($endSec < 10)); then
		echo -n "0"
	fi
	echo "$endSec"
}

function now_playing {
	# Current time and duration of track
	currentPos=$(osascript -e 'tell application "Spotify"' -e "return player position" -e "end tell")
	duration=$(osascript -e 'tell application "Spotify"' -e "return duration of current track" -e "end tell")


	# Some maths to work out the values to show on the progress bar
	truncPos=$(printf "%.*f" 0 $currentPos)
	truncDur=$(printf "%.*f" 0 $(($duration / 1000)))
	ratio=$(echo "$truncPos / $truncDur" | bc -l)
	tempLength=$(echo "20 * $ratio" | bc -l)
	lineLength=$(printf "%.*f" 0 $tempLength)

	currentMin=$((truncPos / 60))
	currentSec=$(printf "%.*f" 0 $( echo "$currentPos - $(( currentMin * 60 ))" | bc -l))

	endMin=$((truncDur / 60))
	endSec=$(printf "%.*f" 0 $( echo "$truncDur - $(( endMin * 60 ))" | bc -l))
	echo "Now Playing:"
	echo -en ${GREEN}

	track=$(osascript -e 'tell application "Spotify"' -e "$album" -e "end tell")
	if [ $(tput cols) -lt 45 ]; then
		resize -s $(tput lines) 45 2>&1 > /dev/null
	fi
	if [ $(tput lines) -lt 6 ]; then
		resize -s 6 $(tput cols) 2>&1 > /dev/null
		clear
	fi
	echo ${track:0:$(tput cols)}
	state=$(osascript -e 'tell application "Spotify"' -e 'return player state' -e 'end tell')
	echo
	# Note: I've reversed the play and pause icons so they are the way they appear in most players (pause icon = playing, play icon = paused)
	echo -n "("
	if [ "$state" == "playing" ]; then
		echo -n "||"
	else
		echo -en "\xE2\x96\xB6 "
	fi
	echo -n ")  "
	show_bar
	echo -en ${NONE}
}

command="$1"

# Parsing the command
# TODO: Convert to switch statement
if [ $command == "track" ]; then
	now_playing
	clean_exit
elif [ $command == "play" ]; then
  # Replace with resume in future to support playing songs by name
  state=$(osascript -e 'tell application "Spotify"' -e 'return player state' -e 'end tell')
	echo -en ${REGULAR}
	if [ "$state" != "playing" ]; then
		command="playpause"
		echo "Playing"
  else
		echo "Already playing"
		clean_exit
  fi
	echo -en ${BOLD}
elif [ $command == "next" ]; then
	command="next track"
elif [ $command == "prev" ]; then
	command="previous track"
elif [ $command == "toggle" ]; then
	command="play"
elif [ $command == "shuffle" ]; then
	command="set shuffling to not shuffling"
  shuffle=$(osascript -e 'tell application "Spotify"' -e 'return shuffling' -e 'end tell')
	echo -en ${REGULAR}
	if [ "$shuffle" == "true" ]; then
		echo "Turning off shuffle"
  else
		echo "Turning on shuffle"
  fi
	echo -en ${BOLD}
elif [ $command == "pause" ]; then
	state=$(osascript -e 'tell application "Spotify"' -e 'return player state' -e 'end tell')
	echo -en ${REGULAR}
	if [ "$state" == "playing" ]; then
		echo "Pausing"
  else
		echo "Already paused"
		clean_exit
  fi
	echo -en ${BOLD}
fi

# For playing tracks by name, use:
# command='play track $2'

# Redirecting stderr into a variable to check if command was valid
err=$(osascript -e 'tell application "Spotify"' -e "$command" -e "end tell" 2>&1 > /dev/null)

# $err will be empty if there was no error
if [ "$err" != "" ]; then
	echo -e "${REGULAR}invalid command - use 'help' for a list of commands"
	clean_exit
fi

# Functionality temporarily removed until permanent option is available through a flag
#if [ $1 == "next" ] || [ $1 == "prev" ]; then
#	now_playing
#fi

clean_exit
