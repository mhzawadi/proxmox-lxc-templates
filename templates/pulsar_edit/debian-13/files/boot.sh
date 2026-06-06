#!/bin/bash
export DISPLAY=:1
export VNC_PORT=5901
export NO_VNC_PORT=8080
export VNC_COL_DEPTH=32
export VNC_RESOLUTION=1280x900
export TERM=xterm

set -e
trap ctrl_c INT
function ctrl_c() {
  exit 0
}
rm /tmp/.X1-lock 2> /dev/null &
/opt/noVNC/utils/novnc_proxy --vnc localhost:$VNC_PORT --listen $NO_VNC_PORT &
/usr/bin/Xvfb $DISPLAY -screen 0 ${VNC_RESOLUTION}x${VNC_COL_DEPTH} &
vncserver $DISPLAY -depth $VNC_COL_DEPTH -geometry $VNC_RESOLUTION -SecurityTypes None -localhost no --I-KNOW-THIS-IS-INSECURE &
pulsar &
wait
