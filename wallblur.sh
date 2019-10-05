#!/bin/bash

# <Constants>
cache_dir="$HOME/.cache/wallblur"
display_resolution=$(echo -n $(xdpyinfo | grep 'dimensions:') | awk '{print $2;}')
# </Constants>


# <Functions>
err() {
	echo "[$(date +'%Y-%m-%dT%H:%M:%S%z')]: $@" >&2
}

gen_blurred_seq () {
	notify-send "Building wallblur cache for "$base_filename""

	clean_cache

	wallpaper_resolution=$(identify -format "%wx%h" $wallpaper)

	err " Display resolution is: ""$display_resolution"""
	err " Wallpaper resolution is: $wallpaper_resolution"

	if [ "$wallpaper_resolution" != "$display_resolution" ]; then
		
		err "Scaling wallpaper to match resolution"
		convert $wallpaper -resize $display_resolution -gravity center -extent $display_resolution "$cache_dir"/"$filename"0."$extension"
		curr_wallpaper="$cache_dir"/"$filename"0."$extension"
	fi

	for i in $(seq 0 1 5)
	do
		blurred_wallaper=""$cache_dir"/"$filename""$i"."$extension""
		convert -blur 0x$i $curr_wallpaper $blurred_wallaper
		err " > Generating $(basename $blurred_wallaper)"
	done
}


do_blur () {
	for i in $(seq 5)
	do
		blurred_wallaper=""$cache_dir"/"$filename""$i"."$extension""
		feh --bg-fill "$blurred_wallaper" 
	done
}

do_unblur () {
	for i in $(seq 5 -1 0)
	do
		blurred_wallaper=""$cache_dir"/"$filename""$i"."$extension""
		feh --bg-fill "$blurred_wallaper" 
	done
}

check_wallpaper_changed() {
	source ~/.cache/wal/colors.sh
	pywal_wallpaper=${wallpaper##*/}


	if [ "$pywal_wallpaper" != "$base_filename" ]
	then
		err " Wallpaper changed. Going to update cache"

		curr_wallpaper="$wallpaper"
		base_filename=${curr_wallpaper##*/}
		extension="${base_filename##*.}"
		filename="${base_filename%.*}"

		gen_blurred_seq

		prev_state="reset"
	fi
}

clean_cache() {
	if [  "$(ls -A "$cache_dir")" ]; then
		err " * Cleaning existing cache"
		rm -r "$cache_dir"/*
	fi
}

is_minimized() {
	xprop -id "$1" | grep -Fq 'window state: Iconic'
}


number_of_unminimized_windows_in_current_workspace() {
	count=0
	for id in $(wmctrl -l | grep -vE '^0x\w* -1' | cut -f1 -d' '); do
		is_minimized "$id" || ((count++))
	done
	return $count
}
# </Functions>


# Get the current wallpaper location from pywal cache
source ~/.cache/wal/colors.sh
curr_wallpaper="$wallpaper"

base_filename=${curr_wallpaper##*/}
extension="${base_filename##*.}"
filename="${base_filename%.*}"

err $cache_dir

# Create a cache directory if it doesn't exist
if [ ! -d "$cache_dir" ]; then
	err "* Creating cache directory"
	mkdir -p "$cache_dir"
fi

blur_cache=""$cache_dir"/"$filename"0."$extension""

# Generate cached images if no cached images are found
if [ ! -f "$blur_cache" ]
then
	gen_blurred_seq
fi

prev_state="reset"

while :; do

	check_wallpaper_changed

	current_workspace="$(xprop -root _NET_CURRENT_DESKTOP | awk '{print $3}')"

	if [[ -n "$current_workspace" ]]; then

		num_windows="$(echo "$(wmctrl -l)" | awk -F" " '{print $2}' | grep ^$current_workspace)"

		# If there are active windows
		if [ -n "$num_windows" ]; then
			if [ "$prev_state" != "blurred" ]; then
				err " ! Blurring"
				do_blur
			fi
			prev_state="blurred"
		    else #If there are no active windows
		    	if [ "$prev_state" != "unblurred" ]; then
		    		err " ! Un-blurring"
		    		do_unblur
		    	fi
		    	prev_state="unblurred"
		fi
	fi
	sleep 0.3
done
