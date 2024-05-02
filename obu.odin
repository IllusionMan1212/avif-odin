package avif

import "core:io"

OBUType :: enum u8 {
    SEQUENCE_HEADER        = 1,
    TEMPORAL_DELIMITER     = 2,
    FRAME_HEADER           = 3,
    TILE_GROUP             = 4,
    METADATA               = 5,
    FRAME                  = 6,
    REDUNDANT_FRAME_HEADER = 7,
    TILE_LIST              = 8,
    PADDING                = 15,
}

// TODO: write a nice bitstream reader
// ??? Still don't know how I want this to work
BitstreamReader :: struct {
    data: []byte,
    pos: i64, // Number of bits read from the data slice
}

OBUHeader :: bit_field u8 {
    obu_reserved:       u8      | 1,
    obu_has_size_field: u8      | 1,
    obu_extension_flag: u8      | 1,
    obu_type:           OBUType | 4,
    obu_forbidden_bit:  u8      | 1,
}

OBUExtensionHeader :: bit_field u8 {
    extension_header_reserved: u8 | 3,
    spatial_id:                u8 | 2,
    temporal_id:               u8 | 3,
}

read_bit :: proc() -> b8 {
    // TODO: idfk
    // This should read a single bit from the bitstream and advance the bitstream position by 1

    return false
}

f :: proc(n: int) -> u64 {
    x: u64 = 0

    for i in 0 ..< n {
        x = 2 * x + auto_cast read_bit()
    }

    return x
}

leb128 :: proc() -> u64 {
    value: u64 = 0
    leb128_bytes := 0

    for i: u64 = 0; i < 8; i += 1 {
        leb128_byte := f(8)
        value |= ((leb128_byte & 0x7f) << (i * 7))
        leb128_bytes += 1

        if (leb128_byte & 0x80) == 0 {
            break
        }
    }

    return value
}
