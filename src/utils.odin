package main
import "core:mem"
import "core:fmt"
import x "vendor:x11/xlib"

keycode_cmp :: proc(keycode: u32, key: x.KeySym) -> bool {
  return keycode == u32(x.KeysymToKeycode(display, key))
}

close_window :: proc(window: x.Window) {
  // x.KillClient(display, window)
  // x.DestroyWindow(display, window)
  msg: x.XEvent
  msg.xclient.type = .ClientMessage
  msg.xclient.message_type = atoms[atom_types.protocols]
  msg.xclient.window = window
  msg.xclient.format = 32
  msg.xclient.data.l[0] = transmute(int)atoms[atom_types.delete_window]
  x.SendEvent(display, window, false, transmute(x.EventMask)int(0), &msg)

  // frame gets closed from main DestroyNotify handler
  // close_frame(display, window)
}

close_frame :: proc(window: x.Window) {
  _, val_p, ji, err := map_entry(&windows, window)

  if err != nil || ji || val_p.frame == 0 {
    return 
  }
  x.DestroyWindow(display, val_p.frame)
  mem.zero_item(val_p)
}

create_frame :: proc(window: x.Window, owindow: ^OdinWindow) {
  if owindow.attributes.width != 0 && owindow.attributes.height != 0 {
    owindow.window = window
    owindow.frame = x.CreateSimpleWindow(display, root_window, 
      owindow.attributes.x,
      owindow.attributes.y,
      u32(owindow.attributes.width),
      u32(owindow.attributes.height),
      FRAME_BORDER_WIDTH,
      FRAME_BORDER_COLOR, FRAME_BORDER_COLOR)

    owindow.frame_close = x.CreateSimpleWindow(display, owindow.frame,
      owindow.attributes.x,
      owindow.attributes.y,
      FRAME_BUTTON_WIDTH,
      TITLE_BAR_HEIGHT,
      0,
      FRAME_BORDER_COLOR, FRAME_CLOSE_COLOR)

    owindow.frame_maximise = x.CreateSimpleWindow(display, owindow.frame,
      owindow.attributes.x,
      owindow.attributes.y,
      FRAME_BUTTON_WIDTH,
      TITLE_BAR_HEIGHT,
      0,
      FRAME_BORDER_COLOR, FRAME_MAXIMISE_COLOR)

    owindow.frame_minimise = x.CreateSimpleWindow(display, owindow.frame,
      owindow.attributes.x,
      owindow.attributes.y,
      FRAME_BUTTON_WIDTH,
      TITLE_BAR_HEIGHT,
      0,
      FRAME_BORDER_COLOR, FRAME_MINIMISE_COLOR)

    x.SelectInput(display, owindow.frame_close, (
        {.ButtonRelease} | {.ButtonPress} |
        {.Exposure}
    ))
    x.SelectInput(display, owindow.frame_maximise, (
        {.ButtonRelease} | {.ButtonPress} |
        {.Exposure}
    ))
    x.SelectInput(display, owindow.frame_minimise, (
        {.ButtonRelease} | {.ButtonPress} |
        {.Exposure}
    ))


    x.SelectInput(display, owindow.frame, (
        {.SubstructureRedirect} |
        {.SubstructureNotify} |
        {.Button1Motion} |
        {.ButtonRelease} |
        {.ButtonPress}
    ))

    x.ReparentWindow(display, window, owindow.frame, 0, TITLE_BAR_HEIGHT)

    // x.PutImage(display, pixmap, gc, close_image, 0, 0, 0, 0, 32, 32)

    x.MapWindow(display, owindow.frame_close)
    x.MapWindow(display, owindow.frame_maximise)
    x.MapWindow(display, owindow.frame_minimise)
    x.MapWindow(display, owindow.frame)

    resize_frame(owindow^)
  }
}

resize_frame :: proc(owindow: OdinWindow) {
  x.MoveWindow(display, owindow.frame_minimise, owindow.attributes.width - FRAME_BUTTON_WIDTH*3 - FRAME_BUTTON_PADDING*2, 0)
  x.MoveWindow(display, owindow.frame_maximise, owindow.attributes.width - FRAME_BUTTON_WIDTH*2 - FRAME_BUTTON_PADDING, 0)
  x.MoveWindow(display, owindow.frame_close, owindow.attributes.width - FRAME_BUTTON_WIDTH, 0)
  x.ResizeWindow(display, owindow.window, u32(owindow.attributes.width), u32(owindow.attributes.height) - TITLE_BAR_HEIGHT)
}

find_window_from_contents :: proc(frame, frame_close, frame_maximise, frame_minimise: x.Window) -> x.Window {
  for window_id in windows {
    fmt.printfln("Querying window frame in %d %d", window_id, frame_close)
    if (windows[window_id].frame == frame && frame != 0) ||
      (windows[window_id].frame_close == frame_close && frame_close != 0) ||
      (windows[window_id].frame_maximise == frame_maximise && frame_maximise != 0) ||
      (windows[window_id].frame_minimise == frame_minimise && frame_minimise != 0)
    {
      return window_id
    }
  }
  return 0
}
