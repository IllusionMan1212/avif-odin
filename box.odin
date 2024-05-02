package avif

import "core:encoding/endian"
import "core:fmt"
import "core:io"
import "core:math"
import "core:image"
import "core:strings"
import "core:unicode/utf8"

BOX_HEADER_SIZE :: 8 // 4 for box size, 4 for box type

BoxError :: enum {
    ReadExceedsBox,
}

BoxType :: enum u32 {
    FTYP = 'f' << 24 | 't' << 16 | 'y' << 8 | 'p', // File Type
    MDAT = 'm' << 24 | 'd' << 16 | 'a' << 8 | 't', // Media Data
    META = 'm' << 24 | 'e' << 16 | 't' << 8 | 'a', // Metadata
    HDLR = 'h' << 24 | 'd' << 16 | 'l' << 8 | 'r', // Declares Metadata Handler Type
    ILOC = 'i' << 24 | 'l' << 16 | 'o' << 8 | 'c', // Item Location
    IINF = 'i' << 24 | 'i' << 16 | 'n' << 8 | 'f', // Item Information
    INFE = 'i' << 24 | 'n' << 16 | 'f' << 8 | 'e', // Item Info Entry
    PITM = 'p' << 24 | 'i' << 16 | 't' << 8 | 'm', // Primary Item Reference
    IPRP = 'i' << 24 | 'p' << 16 | 'r' << 8 | 'p', // Item Properties
    IREF = 'i' << 24 | 'r' << 16 | 'e' << 8 | 'f', // Item Reference
    GRPL = 'g' << 24 | 'r' << 16 | 'p' << 8 | 'l', // Group List
    IPCO = 'i' << 24 | 'p' << 16 | 'c' << 8 | 'o', // Item Property Container
    ISPE = 'i' << 24 | 's' << 16 | 'p' << 8 | 'e', // Image Spatial Extents
    PIXI = 'p' << 24 | 'i' << 16 | 'x' << 8 | 'i', // Pixel Information
    COLR = 'c' << 24 | 'o' << 16 | 'l' << 8 | 'r', // Color Information
    AV1C = 'a' << 24 | 'v' << 16 | '1' << 8 | 'C', // AV1 Codec Configuration
    IPMA = 'i' << 24 | 'p' << 16 | 'm' << 8 | 'a', // Item Property Association
    CLLI = 'c' << 24 | 'l' << 16 | 'l' << 8 | 'i', // Content Light Level Info
}

Error :: union {
    io.Error,
    BoxError,
    OBUError,
    image.General_Image_Error,
}

Box :: struct {
    size: u32,
    type: BoxType,
    pos: i64,
}

Reader :: struct {
    box: Box,
    s:                 []byte, // read-only buffer
    i:                 i64, // current reading index
    bits_read_in_byte: u8,
}

reader_init :: proc(r: ^Reader, s: []byte) {
    r.s = s
    r.i = 0
    r.box.pos = 0
}

read_header :: proc(r: ^Reader) -> (err: Error) {
    r.box.pos = 0
    r.box.size = read_u32be(r) or_return
    type := read_u32be(r) or_return
    r.box.type = transmute(BoxType)type

    return err
}

read_bit :: proc(r: ^Reader) -> (bit: byte, err: Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box.size != 0 && r.box.pos >= i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    byte := r.s[r.i]

    // Get the bit that's after however many bits read starting from the MSB in the byte
    bits := 8 - (r.bits_read_in_byte + 1)
    b := (r.s[r.i:r.i+1][0] & auto_cast math.pow2_f32(bits)) >> bits
    r.bits_read_in_byte += 1

    if r.bits_read_in_byte == 8 {
        r.i += 1
        r.box.pos += 1
        r.bits_read_in_byte = 0
    }

    return b, nil
}

read_byte :: proc(r: ^Reader) -> (byte, Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box.size != 0 && r.box.pos >= i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    b := r.s[r.i]
    r.i += 1
    r.box.pos += 1
    return b, nil
}

read_u16be :: proc(r: ^Reader) -> (u16, Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box.size != 0 && r.box.pos + 2 > i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u16be(r.s[r.i:])
    r.i += 2
    r.box.pos += 2
    return b, nil
}

read_u32be :: proc(r: ^Reader) -> (u32, Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box.size != 0 && r.box.pos + 4 > i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u32be(r.s[r.i:])
    r.i += 4
    r.box.pos += 4
    return b, nil
}

read_u64be :: proc(r: ^Reader) -> (u64, Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box.size != 0 && r.box.pos + 8 > i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u64be(r.s[r.i:])
    r.i += 8
    r.box.pos += 8
    return b, nil
}

read_slice :: proc(r: ^Reader, s: []byte) -> (n: int, err: Error) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    n = copy(s, r.s[r.i:])
    if r.box.pos + i64(n) > i64(r.box.size) {
        return 0, .ReadExceedsBox
    }
    r.i += i64(n)
    r.box.pos += i64(n)
    return
}

read_rune :: proc(r: ^Reader) -> (ch: rune, size: int, err: Error) {
    if r.i >= i64(len(r.s)) {
        return 0, 0, .EOF
    }
    if c := r.s[r.i]; c < utf8.RUNE_SELF {
        if r.box.pos >= i64(r.box.size) {
            return 0, 0, .ReadExceedsBox
        }
        r.i += 1
        r.box.pos += 1
        return rune(c), 1, nil
    }
    ch, size = utf8.decode_rune(r.s[r.i:])
    if r.box.pos + i64(size) > i64(r.box.size) {
        return 0, 0, .ReadExceedsBox
    }
    r.i += i64(size)
    r.box.pos += i64(size)
    return
}

read_string :: proc(r: ^Reader) -> (str: string, err: Error) {
    if r.i >= i64(len(r.s)) {
        return "", .EOF
    }

    sb: strings.Builder
    strings.builder_init_len_cap(&sb, 0, 8)
    defer strings.builder_destroy(&sb)

    for {
        rune, _ := read_rune(r) or_break
        if rune == '\x00' {
            break
        }

        strings.write_rune(&sb, rune)
    }

    return strings.clone(strings.to_string(sb)), err
}

@(private = "file")
read_bitfield_u32 :: proc(r: ^Reader, $T: typeid) -> (T, Error) where size_of(T) == 4 {
    b, err := read_u32be(r)
    return T(b), err
}

@(private = "file")
read_bitfield_u16 :: proc(r: ^Reader, $T: typeid) -> (T, Error) where size_of(T) == 2 {
    b, err := read_u16be(r)
    return T(b), err
}

@(private = "file")
read_bitfield_u8 :: proc(r: ^Reader, $T: typeid) -> (T, Error) where size_of(T) == 1 {
    b, err := read_byte(r)
    return T(b), err
}

read_bitfield :: proc {
    read_bitfield_u8,
    read_bitfield_u16,
    read_bitfield_u32,
}

skip_box :: proc(r: ^Reader) {
    fmt.printfln("SKIPPED! %v with size %d", r.box.type, r.box.size)
    reader_seek(r, auto_cast r.box.size - BOX_HEADER_SIZE, .Current)
}

remaining_box_size :: proc(r: ^Reader) -> i64 {
    return i64(r.box.size) - r.box.pos
}

reader_seek :: proc(r: ^Reader, offset: i64, whence: io.Seek_From) -> (i64, Error) {
    abs: i64
    switch whence {
        case .Start:
            abs = offset
        case .Current:
            abs = r.i + offset
        case .End:
            abs = i64(len(r.s)) + offset
        case:
            return 0, .Invalid_Whence
    }

    if abs < 0 {
        return 0, .Invalid_Offset
    }
    r.i = abs
    return abs, nil
}
