package main
import "core:fmt"
import x "vendor:x11/xlib"

OdinWindow :: struct {
  name: string,
  attributes: x.XWindowAttributes,
  frame: x.Window
}

windows: map[x.Window]OdinWindow

atom_types :: enum {
  delete_window,
  protocols
}
atoms: [len(atom_types)]x.Atom

display: ^x.Display

frame_grab: [2]i32 // position of the mouse inside the frame titlebar
is_frame_grabbed: bool = false

init_atoms :: proc(display: ^x.Display) {
  atoms[atom_types.delete_window] = x.InternAtom(display, "WM_DELETE_WINDOW", false)
  atoms[atom_types.protocols] = x.InternAtom(display, "WM_PROTOCOLS", false)
}

main :: proc() {
  fmt.printfln("Odin WM\n")

  display = x.OpenDisplay(nil)
  if display == nil {
    fmt.panicf("Could not open x display")
  }
  init_atoms(display)

  root_window := x.DefaultRootWindow(display)
  if root_window == 0 {
    fmt.panicf("Could not get root window")
  }

  screen := x.DefaultScreen(display)

  x.SelectInput(display, root_window, (
      {.KeyPress} |
      {.KeyRelease} |
      {.SubstructureRedirect} |
      {.SubstructureNotify}
  ))
  
  x.SetWindowBackground(display, root_window, 0x131d28)//x.WhitePixel(display, screen))
  x.ClearWindow(display, root_window)
  // x.DrawString(display, root_window, x.DefaultGC(display, screen), 100, 100, transmute([^]u8)&str, 10)
  x.Sync(display, false)

  // fmt.printfln("PIXEL WHITE %X", x.WhitePixel(display, screen))

  is_running: bool = true
  for is_running {
    ev: x.XEvent
    x.NextEvent(display, &ev) 

    #partial switch (ev.type) {
      case .MapRequest:
        on_map_request(ev.xmaprequest)
        break
      case .ConfigureRequest:
        on_configure_request(ev.xconfigurerequest)
        break
      case .KeyPress:
        on_key_press(ev.xkey)
      case .KeyRelease:
        break
      case .DestroyNotify:
        when ODIN_DEBUG {fmt.printfln("Closing window %d", ev.xdestroywindow.window)}
        close_frame(ev.xdestroywindow.window)
        break
      case .ButtonPress:
        if ev.xbutton.button == .Button1 {
          is_frame_grabbed = true
          frame_grab.x = ev.xbutton.x
          frame_grab.y = ev.xbutton.y
          x.RaiseWindow(display, ev.xbutton.window)
          fmt.printfln("Frame grabbed")
        }
        break
      case .MotionNotify:
        if is_frame_grabbed {
          x.MoveWindow(display, ev.xmotion.window, ev.xmotion.x_root - frame_grab.x, ev.xmotion.y_root - frame_grab.y)
        }
        break
      case .ButtonRelease:
        if ev.xbutton.button == .Button1 {
          is_frame_grabbed = false
          fmt.printfln("Frame released")
        }
        break
      case:
        when ODIN_DEBUG {fmt.printfln("Unhandled event")}
        break
    }

  }

  x.CloseDisplay(display)
}
