package main
import "core:mem"
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
