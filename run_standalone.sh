#!/bin/sh
set -xe
odin build src -debug -out:odin-win
WD=$(dirname $(realpath $0))
XINITRC="$WD/xinitrc" startx
