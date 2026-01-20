package converter
import "core:fmt"
import "core:os"
import i "vendor:stb/image"

convert_file :: proc(inpath: cstring, outpath: string) {
  x, y, channels: i32 = 0, 0, 0
  data := i.load(inpath, &x, &y, &channels, 0)
  data_len := int(x*y*channels)
  fmt.printfln("[%s -> %s] %d %d %d", inpath, outpath, x, y, channels)
  // err := os.write_entire_file_or_err("./assets/close.bin", data[:(x*y*channels)])
  fd, err := os.open(outpath, os.O_CREATE | os.O_TRUNC | os.O_RDWR, 0o664)
  defer os.close(fd)

  os.write_any(fd, u8(0xFA))
  os.write_any(fd, u8(0x54))
  os.write_any(fd, u8(x))
  os.write_any(fd, u8(y))
  os.write_any(fd, u8(channels))
  os.write_ptr(fd, data, data_len)
}

main :: proc() {
  // file := c.fopen("../assets/close.png", "rb")
  // data := i.load_from_file(file, &x, &y, &channels, 0)
  // c.fclose(file)
  convert_file("./assets/close3.png", "./assets/close.bin")
  convert_file("./assets/maximise.png", "./assets/maximise.bin")
  convert_file("./assets/minimise.png", "./assets/minimise.bin")
}
