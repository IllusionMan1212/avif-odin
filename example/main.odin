package avif_example

import "core:fmt"
import "core:os"
import avif "../"

main :: proc() {
    if len(os.args) < 2 {
        fmt.eprintln("Please provide a path to an avif image.")
        os.exit(1)
    }

    img, err := avif.load_from_file(os.args[1])
    if err != nil {
        fmt.eprintln(err)
        os.exit(1)
    }

    fmt.println(img)
}
