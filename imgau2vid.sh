#!/bin/bash
# Bash script to convert a one image with audio to video
# This script required kdialog (in a future i add support for Zenity and command line options)
# 2018 Alfonso Saavedra "Son Link"
# Script under the GPLv3 or newer license

function convert(){
	# Get video duration in seconds
	duration=$(ffmpeg -i "$AUDIO" 2>&1 | sed -n "s/.* Duration: \([^,]*\), start: .*/\1/p")
	fps=1
	hours=$(echo $duration | cut -d":" -f1)
	minutes=$(echo $duration | cut -d":" -f2)
	seconds=$(echo $duration | cut -d":" -f3)
	totalsecs=$(echo "($hours*3600+$minutes*60+$seconds)" | bc)

	if [ -f /tmp/ffmpeg.log ]; then rm /tmp/ffmpeg.log; fi

	# Init convert and redirect the log to a file
	ffmpeg -loop 1 -i "$IMAGE" -i "$AUDIO" \
	-c:v libvpx -c:a libvorbis -b:a 192k -b:v 1M -vf scale=$RES -auto-alt-ref 0 \
	-r 1 -y "$SAVE" -v verbose 1> /tmp/ffmpeg.log 2>&1 &
	# Get ffmpeg Process ID
	PID=$( ps -ef | grep "ffmpeg" | grep -v "grep" | awk '{print $2}' )
}

function showPercent_kdialog(){
	dbusRef=$(kdialog --title "Converting video." --progressbar "Converting video." 100)
	qdbus $dbusRef showCancelButton true

	# While ffmpeg runs, process the log file for the current time, display percentage progress
	while [ -e /proc/$PID ]; do
		if [[ $(qdbus $dbusRef wasCancelled) != "false" ]]; then
			kill $PID
			qdbus $qdbusRef org.kde.kdialog.ProgressDialog.close > /dev/null
			rm /tmp/ffmpeg.log;
			break
		fi

		currenttime=$(tail -n 1 /tmp/ffmpeg.log | awk '/time=/ { print $7 }' | cut -d= -f2)
		hours=$(echo $currenttime | cut -d":" -f1)
		minutes=$(echo $currenttime | cut -d":" -f2)
		seconds=$(echo $currenttime | cut -d":" -f3)

		if [ ! -z $currenttime ]; then
			processedsecs=$(echo "($hours*3600+$minutes*60+$seconds)" | bc)
			if [ ! -z "$processedsecs" ]; then
				PROG=$(echo "scale=3; ($processedsecs/$totalsecs)*100.0/1" | bc)
				PROG=${PROG%%.*}
				if [ ! -z $PROG ] && [ $PROG -lt 0 ]; then PROG=0; fi
				qdbus $dbusRef Set "" value $PROG
				sleep 1
			fi
		fi
	done

	kdialog --title "New convert" --yesno "You want to convert another image and audio?"
	if [ $? = 0 ]; then
		init_kdialog
	else
		exit 0
	fi
}

function showPercent_zenity(){
	PROG=0
	# While ffmpeg runs, process the log file for the current time, display percentage progress
	(while [ -e /proc/$PID ]; do

		currenttime=$(tail -n 1 /tmp/ffmpeg.log | awk '/time=/ { print $7 }' | cut -d= -f2)
		hours=$(echo $currenttime | cut -d":" -f1)
		minutes=$(echo $currenttime | cut -d":" -f2)
		seconds=$(echo $currenttime | cut -d":" -f3)
		
		if [ ! -z $currenttime ]; then
			processedsecs=$(echo "($hours*3600+$minutes*60+$seconds)" | bc)
			if [ ! -z "$processedsecs" ]; then
				PROG=$(echo "scale=3; ($processedsecs/$totalsecs)*100.0/1" | bc)
				PROG=${PROG%%.*}
				if [ ! -z $PROG ] && [ $PROG -lt 0 ]; then PROG=0; fi
				echo "# Converting video (${PROG}%)."
				echo $PROG; sleep 1
			fi
		fi
	done) | zenity --progress \
			--title="Converting video" \
			--text="Converting video (0%)." \
			--percentage=0 \
			--auto-close

	zenity --question --title="New convert?" \
		--text="You want to convert another image and audio?" \
		--icon-name="question" --ellipsize
		
	if [ $? = 0 ]; then
		init_zenity
	else
		exit 0
	fi
}

function showPercent_cli(){
	PROG=0
	echo "Converting video:"
	echo -e "\tImage: $IMAGE"
	echo -e "\tAudio: $AUDIO"
	echo -e "\tto: $SAVE"
	echo -e "Press Ctrl+C por quit."
	
	# While ffmpeg runs, process the log file for the current time, display percentage progress
	while [ -e /proc/$PID ]; do

		currenttime=$(tail -n 1 /tmp/ffmpeg.log | awk '/time=/ { print $7 }' | cut -d= -f2)
		hours=$(echo $currenttime | cut -d":" -f1)
		minutes=$(echo $currenttime | cut -d":" -f2)
		seconds=$(echo $currenttime | cut -d":" -f3)
		if [ ! -z $currenttime ]; then
			processedsecs=$(echo "($hours*3600+$minutes*60+$seconds)" | bc)
			if [ ! -z "$processedsecs" ]; then
				PROG=$(echo "scale=3; ($processedsecs/$totalsecs)*100.0/1" | bc)
				PROG=${PROG%%.*}
				bar="##################################################"
				barlength=${#bar}
				if [ ! -z $PROG ] && [ $PROG -gt 0 ]; then
					n=$(($PROG*barlength/100))
					printf "\r[%-${barlength}s (%d%%)] " "${bar:0:n}" "$PROG"
				fi
			fi
		fi
	done
	
	if [ $? = 0 ]; then
		exit 1
	else
		exit 0
	fi
}

function init_kdialog(){
	FORMAT=$(kdialog --radiolist "Select video format and resolution:" \
		'webm-1080' 'WebM FullHD (1080)' on \
		'webm-720'	'WebM HD (720)' off \
		'web-480'	'WebM SD (480)' off\
		'mp4-1080' 	'MP4 FullHD (1080)' off \
		'mp4-720'	'MP4 HD (720)' off \
		'mp4-480'	'MP4 SD (480)' off )

	if [ $? = 1 ]; then exit 1; fi

	EXT=$(echo $FORMAT | cut -d- -f1)
	RES=$(echo $FORMAT | cut -d- -f2)

	if [ $RES = '1080' ]; then
		RES='1920:1080'
	elif [ $RES = '720' ]; then
		RES='1280:720'
	elif [ $RES = '480' ]; then
		RES='854:480'
	fi

	IMAGE=$(kdialog --getopenfilename $HOME "Images (*.png *.jpg *.bmp)" --title 'Select image')
	if [ $? = 1 ]; then exit 1; fi

	AUDIO=$(kdialog --getopenfilename $HOME "Audio (*.mp3 *.ogg *.wav *.aac *.flac *m4a)" --title 'Select audio')
	if [ $? = 1 ]; then exit 1; fi

	SAVE=$(kdialog --getsavefilename $HOME/:video.$EXT "Video file (*.$EXT)" --title 'Set output file name')
	if [ $? = 1 ]; then exit 1; fi
}

function init_zenity(){
	FORMAT=$(zenity --list \
		--title="Select video format and resolution" \
		--text="Select video format and resolution:" \
		--column="" --column="Formats & resolutions" \
		--hide-column=1 --print-column=1 \
		'webm-1080' 'WebM FullHD (1080)' \
		'webm-720'	'WebM HD (720)' \
		'web-480'	'WebM SD (480)' \
		'mp4-1080' 	'MP4 FullHD (1080)' \
		'mp4-720'	'MP4 HD (720)' \
		'mp4-480'	'MP4 SD (480)' )

	if [ $? != 0 ] || [ -z $FORMAT ]; then exit 1; fi
		
	EXT=$(echo $FORMAT | cut -d- -f1)
	RES=$(echo $FORMAT | cut -d- -f2)

	if [ $RES = '1080' ]; then
		RES='1920:1080'
	elif [ $RES = '720' ]; then
		RES='1280:720'
	elif [ $RES = '480' ]; then
		RES='854:480'
	fi

	IMAGE=$(zenity --file-selection --title="Select a Image" --file-filter=""*.png" "*.jpg" "*.bmp"")
	if [ $? != 0 ]; then exit 1; fi

	AUDIO=$(zenity --file-selection --title="Select a Audio" --file-filter=""*.mp3" "*.ogg" "*.wav" "*.aac" "*.m4a" "*.flac"")
	if [ $? != 0 ]; then exit 1; fi

	SAVE=$(zenity --file-selection --save --title="Set output file name" --file-filter="*.$EXT")
	if [ $? != 0 ]; then exit 1; fi
}

function usage(){
	echo "imgau2vid. How to use:"
	echo -e "\t-h: Show this help."
	echo -e "\t-k: Use Kdialog for GUI."
	echo -e "\t-z: Use Zenity for GUI."
	echo "These options is required for use on terminal"
	echo -e "\t-i /path/to/image: Set the image."
	echo -e "\t-a /path/to/audio: Set the audio."
	echo -e "\t-o /path/to/output: Set the output video file."
	echo "These options is optionals for use on terminal"
	echo -e "\t-f webm|mp4: Set video format. Default is webm"
	echo -e "\t-r fhd|hd|sd: Set video resolution. Default is fhd (FullHD 1920x1080)"
}

while getopts "i:a:o:f:r:hkz" o; do
    case "${o}" in
		i)
			if [ -f "$OPTARG" ]; then
				IMAGE="$OPTARG"
			else
				echo "The image $OPTARG is not found."
				exit 1
			fi
			;;
		a)
			if [ -f "$OPTARG" ]; then
				AUDIO="$OPTARG"
			else
				echo "The audio $OPTARG is not found."
				exit 1
			fi
			;;
		f)
			FORMATS=("webm" "mp4")
			if [[ "${FORMATS[@]}" =~ "$OPTARG" ]]; then
				FORMAT=$OPTARG
			else
				echo "The video format $OPTARG is don't actually support."
				usage
			fi
			;;
		r)
			RESOLUTIONS=("fhd" "hd" "sd")
			$RES = $OPTARG
			if [[ "${RESOLUTIONS[@]}" =~ "$RES" ]]; then
				if [ $RES = 'fhd' ]; then
					RES='1920:1080'
				elif [ $RES = 'hd' ]; then
					RES='1280:720'
				elif [ $RES = 'sd' ]; then
					RES='854:480'
				fi
			else
				echo "The resolution $OPTARG is don't actually avaliable."
				usage
			fi
			;;
		o)
			if [ -w "$OPTARG" ]; then
				SAVE="$OPTARG"
			else
				echo "You don't hace permissions for write the output video $OPTARG."
				exit 1
			fi
			;;
        h)
			#s=${OPTARG}
			usage
			;;
        k)
			GUI=kdialog
			init_kdialog

			;;
		z)
			GUI=zenity
			init_zenity
			;;
        *)
			usage
			;;
    esac
done

if [ $# = 0 ]; then usage; fi

if [ -n $RES ]; then RES='1920:1080'; fi
if [ -n $FORMAT ]; then FORMAT='webm'; fi
if [ -z $GUI ]; then GUI='cli'; fi

if [ -n "$FORMAT" ] && [ -n "$RES" ] && [ -n "$IMAGE" ] && [ -n "$AUDIO" ] && [ -n "$SAVE" ]; then
	convert
	showPercent_${GUI}
fi

trap ctrl_c INT

if [ $? != 0 ]; then ctrl_c; fi

function ctrl_c() {
    if [ -e /proc/$PID ]; then
		kill $PID
		rm /tmp/ffmpeg.log
		exit 1
    fi
}
