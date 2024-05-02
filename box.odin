package avif

import "core:encoding/endian"
import "core:fmt"
import "core:io"
import "core:strings"
import "core:unicode/utf8"

BOX_HEADER_SIZE :: 8 // 4 for box size, 4 for box type

_BoxError :: enum {
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

BoxError :: union {
    io.Error,
    _BoxError,
}

Box :: struct {
    size: u32,
    type: BoxType,
}

Reader :: struct {
    using current_box: Box,
    s:                 []byte, // read-only buffer
    i:                 i64, // current reading index
    box_pos:           i64, // Byte index for the Box
}

reader_init :: proc(r: ^Reader, s: []byte) {
    r.s = s
    r.i = 0
    r.box_pos = 0
}

read_header :: proc(r: ^Reader) -> (err: BoxError) {
    r.box_pos = 0
    r.size = read_u32be(r) or_return
    type := read_u32be(r) or_return
    r.type = transmute(BoxType)type

    return err
}

read_byte :: proc(r: ^Reader) -> (byte, BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box_pos >= i64(r.size) {
        return 0, .ReadExceedsBox
    }
    b := r.s[r.i]
    r.i += 1
    r.box_pos += 1
    return b, nil
}

read_u16be :: proc(r: ^Reader) -> (u16, BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.box_pos + 2 > i64(r.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u16be(r.s[r.i:])
    r.i += 2
    r.box_pos += 2
    return b, nil
}

read_u32be :: proc(r: ^Reader) -> (u32, BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.size != 0 && r.box_pos + 4 > i64(r.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u32be(r.s[r.i:])
    r.i += 4
    r.box_pos += 4
    return b, nil
}

read_u64be :: proc(r: ^Reader) -> (u64, BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    if r.size != 0 && r.box_pos + 8 > i64(r.size) {
        return 0, .ReadExceedsBox
    }
    b := endian.unchecked_get_u64be(r.s[r.i:])
    r.i += 8
    r.box_pos += 8
    return b, nil
}

read_slice :: proc(r: ^Reader, s: []byte) -> (n: int, err: BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, .EOF
    }
    n = copy(s, r.s[r.i:])
    if r.box_pos + i64(n) > i64(r.size) {
        return 0, .ReadExceedsBox
    }
    r.i += i64(n)
    r.box_pos += i64(n)
    return
}

read_rune :: proc(r: ^Reader) -> (ch: rune, size: int, err: BoxError) {
    if r.i >= i64(len(r.s)) {
        return 0, 0, .EOF
    }
    if c := r.s[r.i]; c < utf8.RUNE_SELF {
        if r.box_pos >= i64(r.size) {
            return 0, 0, .ReadExceedsBox
        }
        r.i += 1
        r.box_pos += 1
        return rune(c), 1, nil
    }
    ch, size = utf8.decode_rune(r.s[r.i:])
    if r.box_pos + i64(size) > i64(r.size) {
        return 0, 0, .ReadExceedsBox
    }
    r.i += i64(size)
    r.box_pos += i64(size)
    return
}

read_string :: proc(r: ^Reader) -> (str: string, err: BoxError) {
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
read_bitfield_u32 :: proc(r: ^Reader, $T: typeid) -> (T, BoxError) where size_of(T) == 4 {
    b, err := read_u32be(r)
    return T(b), err
}

@(private = "file")
read_bitfield_u16 :: proc(r: ^Reader, $T: typeid) -> (T, BoxError) where size_of(T) == 2 {
    b, err := read_u16be(r)
    return T(b), err
}

read_bitfield :: proc {
    read_bitfield_u16,
    read_bitfield_u32,
}

skip_box :: proc(r: ^Reader) {
    fmt.printfln("SKIPPED! %v with size %d", r.type, r.size)
    reader_seek(r, auto_cast r.size - BOX_HEADER_SIZE, .Current)
}

remaining_box_size :: proc(r: ^Reader) -> i64 {
    return i64(r.size) - r.box_pos
}

reader_seek :: proc(r: ^Reader, offset: i64, whence: io.Seek_From) -> (i64, BoxError) {
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
