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
      case:
        when ODIN_DEBUG {fmt.printfln("Unhandled event")}
        break
    }

  }

  x.CloseDisplay(display)
}
