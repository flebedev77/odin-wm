package main
import "core:fmt"
import "core:mem"
import "core:os"
import x "vendor:x11/xlib"

OdinWindow :: struct {
  name: string,
  attributes: x.XWindowAttributes,
  non_maximised_attributes: x.XWindowAttributes,
  window: x.Window,
  frame: x.Window,
  frame_close: x.Window,
  frame_maximise: x.Window,
  frame_minimise: x.Window,
  is_maximised: bool
}

windows: map[x.Window]OdinWindow

atom_types :: enum {
  delete_window,
  protocols
}
atoms: [len(atom_types)]x.Atom

display: ^x.Display
screen: i32
root_window: x.Window
gc: x.GC
depth: i32

frame_grab: [2]i32 // position of the mouse inside the frame titlebar
is_frame_grabbed: bool = false

close_image, maximise_image, minimise_image: ^x.XImage

fatty_to_ximage :: proc(fatty_data: []u8, bg_col: uint) -> ^x.XImage {
  if fatty_data[0] != 0xFA || fatty_data[1] != 0x54 {
    fmt.panicf("Fatty magic number is incorrect")
  }
  fatty_w, fatty_h, fatty_channels := i32(fatty_data[2]), i32(fatty_data[3]), i32(fatty_data[4])
  image_data, err := mem.alloc(int(fatty_w*fatty_h*depth)) 
  outimg := x.CreateImage(
    display,
    x.DefaultVisual(display, screen),
    u32(depth),
    .ZPixmap,
    0,
    image_data,
    u32(fatty_w),
    u32(fatty_h),
    32,
    0
  )
  for y: i32 = 0; y < fatty_h; y += 1 {
    for xp: i32 = 0; xp < fatty_w; xp += 1 {
      i := (y*fatty_w + xp) * fatty_channels + 5 // 5 is the header length
      // r := close_icon[i] 
      r, g, b, a := uint(fatty_data[i]), uint(fatty_data[i+1]), uint(fatty_data[i+2]), uint(fatty_data[i+3])
      // r, g, b := 0, (f32(xp)/32)*255, 255
      col: uint = uint(a) << 24 | uint(r) << 16 | uint(g) << 8 | uint(b)
      if a < 1 {
        col = bg_col
      }
      // col: uint = 0xFF00FF00
      x.PutPixel(outimg, xp, y, col)
      // x.AddPixel(close_image, int(x.BlackPixel(display, screen)))
    }
  }

  return outimg
}

init_assets :: proc() {
  close_icon := CLOSE_ICON
  close_image = fatty_to_ximage(close_icon, FRAME_CLOSE_COLOR)

  maximise_icon := MAXIMISE_ICON
  maximise_image = fatty_to_ximage(maximise_icon, FRAME_MAXIMISE_COLOR)

  minimise_icon := MINIMISE_ICON
  minimise_image = fatty_to_ximage(minimise_icon, FRAME_MINIMISE_COLOR)
}

init_atoms :: proc() {
  atoms[atom_types.delete_window] = x.InternAtom(display, "WM_DELETE_WINDOW", false)
  atoms[atom_types.protocols] = x.InternAtom(display, "WM_PROTOCOLS", false)
}

start_term :: proc() {
  pid, err := os.fork()
  if pid == 0 {
    fmt.printfln("Running xterm")
    xerr := os.execvp("ls", {""})
    if xerr != nil {
      fmt.panicf("Err")
    }
  }
}

main :: proc() {
  fmt.printfln("Odin WM\n")

  display = x.OpenDisplay(nil)
  if display == nil {
    fmt.panicf("Could not open x display")
  }

  root_window = x.DefaultRootWindow(display)
  if root_window == 0 {
    fmt.panicf("Could not get root window")
  }

  screen = x.DefaultScreen(display)

  // start_term()

  gc = x.DefaultGC(display, screen)
  depth = x.DefaultDepth(display, screen)

  init_atoms()
  init_assets()

  x.SelectInput(display, root_window, (
      // {.KeyPress} |
      // {.KeyRelease} |
      {.SubstructureRedirect} |
      {.SubstructureNotify}
  ))
  
  x.SetWindowBackground(display, root_window, 0x131d28)//x.WhitePixel(display, screen))
  x.ClearWindow(display, root_window)
  // x.DrawString(display, root_window, x.DefaultGC(display, screen), 100, 100, transmute([^]u8)&str, 10)
  x.Sync(display, false)

  root_attributes: x.XWindowAttributes
  x.GetWindowAttributes(display, root_window, &root_attributes)

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
          parent_window := find_window_from_contents(0, ev.xbutton.window, 0, 0)
          if parent_window != 0 {
            close_window(parent_window)
          }
          parent_window = find_window_from_contents(0, 0, 0, ev.xbutton.window)
          if parent_window != 0 {
            fmt.printfln("Minimizing %s", windows[parent_window].name)
            x.UnmapWindow(display, windows[parent_window].frame)
          }
          parent_window = find_window_from_contents(0, 0, ev.xbutton.window, 0)
          if parent_window != 0 {
            // owindow := &windows[parent_window]
            _, owindow, ji, err := map_entry(&windows, parent_window)
            fmt.printfln("Maximising %s", owindow.name)
            // x.UnmapWindow(display, windows[parent_window].frame)
            if !owindow.is_maximised {
              owindow.is_maximised = true
              x.GetWindowAttributes(display, owindow.frame, &owindow.non_maximised_attributes)
              x.MoveResizeWindow(display, owindow.frame, 0, 0, u32(root_attributes.width), u32(root_attributes.height))
              owindow.attributes.width = root_attributes.width
              owindow.attributes.height = root_attributes.height
              resize_frame(owindow^)
            } else {
              owindow.is_maximised = false
              x.MoveResizeWindow(display, owindow.frame,
                owindow.non_maximised_attributes.x, 
                owindow.non_maximised_attributes.y,
                u32(owindow.non_maximised_attributes.width),
                u32(owindow.non_maximised_attributes.height)
              )
              owindow.attributes.width = owindow.non_maximised_attributes.width
              owindow.attributes.height = owindow.non_maximised_attributes.height
              resize_frame(owindow^)
            }

          }
        }
        break
      case .Expose:
        // x.DrawLine(display, ev.xexpose.window, gc, 0, 0, 50, TITLE_BAR_HEIGHT)
        // x.DrawLine(display, ev.xexpose.window, gc, 0, TITLE_BAR_HEIGHT, 50, 0)
        parent_window := find_window_from_contents(0, ev.xexpose.window, 0, 0)
        if parent_window != 0 {
          parent_owindow := windows[parent_window]
          x.PutImage(display,
            ev.xexpose.window,
            gc,
            close_image, 0, 0,
            FRAME_BUTTON_WIDTH/2 - close_image.width/2,
            TITLE_BAR_HEIGHT/2 - close_image.height/2,
            u32(close_image.width), u32(close_image.height)
          )
          // x.DrawRectangle(display, ev.xexpose.window, x.DefaultGC(display, screen), 10, 10, 20, 20)
          // x.DrawLine(display, ev.xexpose.window, gc, 0, 0, 50, TITLE_BAR_HEIGHT)
          // x.DrawLine(display, ev.xexpose.window, gc, 0, TITLE_BAR_HEIGHT, 50, 0)
        }

        parent_window = find_window_from_contents(0, 0, ev.xexpose.window, 0)
        if parent_window != 0 {
          x.PutImage(display,
            ev.xexpose.window,
            gc,
            maximise_image, 0, 0,
            FRAME_BUTTON_WIDTH/2 - maximise_image.width/2,
            TITLE_BAR_HEIGHT/2 - maximise_image.height/2,
            u32(maximise_image.width), u32(maximise_image.height)
          )
        }

        parent_window = find_window_from_contents(0, 0, 0, ev.xexpose.window)
        if parent_window != 0 {
          x.PutImage(display,
            ev.xexpose.window,
            gc,
            minimise_image, 0, 0,
            FRAME_BUTTON_WIDTH/2 - minimise_image.width/2,
            TITLE_BAR_HEIGHT/2 - minimise_image.height/2,
            u32(minimise_image.width), u32(minimise_image.height)
          )
        }
        break
      case:
        // when ODIN_DEBUG {fmt.printfln("Unhandled event")}
        break
    }

  }

  x.CloseDisplay(display)
}
