#!/bin/sh
set -xe
odin build src -debug -out:odin-win

XEPHYR=$(whereis -b Xephyr | sed -E 's/^.*: ?//')
if [ -z "$XEPHYR" ]; then
    echo "Xephyr not found, exiting"
    exit 1
fi

DISP_NUM=:10

killall Xephyr | cat
killall gf2 | cat
killall odin-win | cat
killall xterm | cat
"$XEPHYR" $DISP_NUM -ac -screen 1366x768 -host-cursor &
gf2 ./odin-win &
sleep 1 && $(DISPLAY=:10 xterm)
# DISPLAY=$DISP_NUM xterm
# xinit ./xinitrc -- \
#     "$XEPHYR" \
#         :$RANDOM \
#         -ac \
#         -screen 1366x768 \
#         -host-cursor
