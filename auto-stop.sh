#!/bin/zsh

WEBCAM_DEVICE="0"

# When playback has stopped, a POST will be sent to this URL.
# You can use this to press a button in Companion that will stop recording and send a notification.
COMPANION_BUTTON_URL="http://10.11.200.40:8000/api/location/90/0/1/press"

# Define the RGB values for the blue screen that indicate the camcorder has stopped playback.
R_VALUE=1
G_VALUE=1
B_VALUE=183

# VCR
#R_VALUE=27
#G_VALUE=37
#B_VALUE=124

# Stop recording after this many samples have been detected.
# I've found that some of my tapes have a few seconds of gaps and I didn't
# want to stop recording the tape, so this means it won't stop until
# a total of 40 seconds have passed.
STOP_AFTER_CONSECUTIVE_FRAMES=20
SECONDS_BETWEEN_SAMPLES=2


###############################

blue_frame_count=0
post_sent=false
while true; do
    # Extract a single frame from the webcam using the avfoundation input format
	ffmpeg -y -f avfoundation -framerate 30 -video_size 1920x1080 -i "$WEBCAM_DEVICE:" -frames:v 1 frame.jpg 2>&/dev/null

    # Check if the frame file exists before proceeding
    if [ ! -f frame.jpg ]; then
        echo "Error: Failed to capture a frame from the device."
        exit 1
    fi

    # Compute the average color of the frame using ffmpeg
    average_color=$(ffmpeg -i frame.jpg -vf "scale=1:1" -f rawvideo -pix_fmt rgb24 - | hexdump -e '3/1 "%02X" "\n"') 2>&/dev/null

    # Remove the image
    rm -f frame.jpg

    # Extract R, G, and B values
    r=$(echo $average_color | cut -c1-2)
    g=$(echo $average_color | cut -c3-4)
    b=$(echo $average_color | cut -c5-6)

    # Convert hex values to decimal
    r_dec=$((16#$r))
    g_dec=$((16#$g))
    b_dec=$((16#$b))

    echo "Average color: R=$r_dec, G=$g_dec, B=$b_dec"

    # Check for a blue frame
    if [ "$r_dec" -lt $R_VALUE ] && [ "$g_dec" -lt $G_VALUE ] && [ "$b_dec" -gt $B_VALUE ]; then
        # Increment the counter for blue frames
        blue_frame_count=$((blue_frame_count + 1))
        echo "Blue frame detected: $blue_frame_count consecutive frames."
    else
        # Reset the counter if the condition is not met
        blue_frame_count=0
        post_sent=false
    fi

    # Check if the required number of consecutive blue frames has been reached
    if [ "$blue_frame_count" -ge "$STOP_AFTER_CONSECUTIVE_FRAMES" ]  && [ "$post_sent" = false ]; then
    	echo "Stopping Recording"
        curl -X POST -H "Content-Type: application/json" $COMPANION_BUTTON_URL
        # Reset the counter
        blue_frame_count=0
        post_sent=true
    fi

    # Sleep for 2 seconds before the next iteration
    sleep $SECONDS_BETWEEN_SAMPLES
done

