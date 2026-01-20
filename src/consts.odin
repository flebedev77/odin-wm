package main
import x "vendor:x11/xlib"

FRAME_BORDER_COLOR :: 0x161616//0x6786BF
FRAME_BORDER_WIDTH :: 2

FRAME_MAXIMISE_COLOR :: 0x6786BF
FRAME_MINIMISE_COLOR :: 0x6777B0
FRAME_CLOSE_COLOR :: 0x4786BF

FRAME_BUTTON_WIDTH :: 50
FRAME_BUTTON_PADDING :: 5

TITLE_BAR_HEIGHT :: 20

MODIFIER_KEY :: x.InputMaskBits.Mod4Mask

CLOSE_ICON :: #load("../assets/close.bin")
MAXIMISE_ICON :: #load("../assets/maximise.bin")
MINIMISE_ICON :: #load("../assets/minimise.bin")
