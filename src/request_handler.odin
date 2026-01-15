package main
import "core:fmt"
import "core:strings"
import x "vendor:x11/xlib"

create_frame :: proc(window: x.Window, owindow: ^OdinWindow) {
  if owindow.attributes.width != 0 && owindow.attributes.height != 0 {
    owindow.frame = x.CreateSimpleWindow(display, x.DefaultRootWindow(display), 
      owindow.attributes.x,
      owindow.attributes.y,
      u32(owindow.attributes.width),
      u32(owindow.attributes.height),
      FRAME_BORDER_WIDTH,
      FRAME_BORDER_COLOR, FRAME_BORDER_COLOR)


    x.SelectInput(display, owindow.frame, (
        {.SubstructureRedirect} |
        {.SubstructureNotify}
    ))

    x.ReparentWindow(display, window, owindow.frame, 0, 0)

    x.MapWindow(display, owindow.frame)
  }
}

on_map_request :: proc(e: x.XMapRequestEvent) {
  x.MapWindow(display, e.window)

  str: cstring
  x.FetchName(display, e.window, &str)
  key_p, val_p, ji, err := map_entry(&windows, e.window)
  if len(str) > 0 {
    val_p.name = strings.clone_from_cstring(str)
  }

  fmt.printfln("Window mapped %s", str)

  x.SetInputFocus(display, e.window, .RevertToPointerRoot, x.CurrentTime)
  x.GrabKey(display, i32(x.KeysymToKeycode(e.display, .XK_C)), {.Mod4Mask},
    e.window, false, .GrabModeAsync, .GrabModeAsync)

  if val_p.frame == 0 {
    create_frame(e.window, val_p)
  }
}

on_configure_request :: proc(e: x.XConfigureRequestEvent) {
  rect := x.XWindowChanges{
    x = e.x,
    // x = config_reqs * 400,
    y = e.y,
    width = e.width,
    height = e.height,
    border_width = e.border_width,
    sibling = e.above,
    stack_mode = e.detail
  }

  _, val_p, _, err := map_entry(&windows, e.window)
  if err != nil {
    fmt.printfln("Could not modify window size attribute")
  } else {
    val_p.attributes.x = e.x
    val_p.attributes.y = e.y
    val_p.attributes.width = e.width
    val_p.attributes.height = e.height
    fmt.printfln("Window resized/moved %s x %d y %d w %d h %d", val_p.name, val_p.attributes.x, val_p.attributes.y, val_p.attributes.width, val_p.attributes.height)
  }

  changes_mask := transmute(x.WindowChangesMask)i32(e.value_mask)
  // changes_mask += {.CWX}

  x.ConfigureWindow(display, e.window, changes_mask, &rect)
  if val_p.frame == 0 {
    create_frame(e.window, val_p)
  } else {
    x.ConfigureWindow(display, val_p.frame, changes_mask, &rect)
  }
}

on_key_press :: proc(e: x.XKeyEvent) {
  fmt.printfln("Pressing something")
  if keycode_cmp(e.keycode, .XK_C) && MODIFIER_KEY in e.state {
    fmt.printfln("Gon close sum window")
    close_window(e.window)
  }
}
