package avif

import "core:bytes"
import "core:fmt"
import "core:image"
import "core:encoding/endian"
import "core:io"
import "core:strings"

Error :: image.Error
//Image   :: image.Image
Options :: image.Options

Image :: struct {
    compatible_brands: [dynamic]ISOBMFFBrand,
    major_brand:       ISOBMFFBrand,
    brand_version:     u32,
    handler_type:      HEIFTrack,
    handler_name:      string,
    primary_item_id:   u32,
}

//            Noticed avif compatible brands, avif, mif1, miaf, MA1A, MA1B
//            Files containing MA1A as a compatible brand are expected to list the following brands in any order:
//            avif, mif1, miaf, MA1A
//            If the file contains a `pict` track compliant with this profile then it's expected to list the following brands in any order:
//            avis, msf1, miaf, MA1A
//            Files containing MA1B as a compatible brand is expected to list the following brands in any order:
//            avif, mif1, miaf, MA1B
//            If the file contains a `pict` track compliant with this profile then it's expected to list the following brands in any order:
//            avis, msf1, miaf, MA1B
//            If the file contains a `pict` track compliant with this profile and made only of samples marked `sync` then it's expected to list the following brands in any order:
//            avis, avio, msf1, miaf, MA1B

VersionAndFlags :: bit_field u32 {
    flags: u32 | 24,
    version: u16 | 8, // should be u8 but compiler fails an assertion that I couldn't reproduce
}

ILOCSize :: bit_field u16 {
    index_size_OR_reserved: u8 | 4,
    base_offset_size: u8 | 4,

    length_size: u8 | 4,
    offset_size: u8 | 4,
}

// NOTE: We order the bits in the reverse order because Odin's bit_field is LSB while the spec is MSB.
AV1CodecConfigRecord :: bit_field u32 {
    initial_presentation_delay_minus_one_OR_reserved: u8 | 4,
    initial_presentation_delay_present:               u8 | 1,
    reserved:                                         u8 | 3,

    chroma_sample_position:                           u8 | 2,
    chroma_subsampling_y:                             u8 | 1,
    chroma_subsampling_x:                             u8 | 1,
    monochrome:                                       u8 | 1,
    twelve_bit:                                       u8 | 1,
    high_bitdepth:                                    u8 | 1,
    seq_tier_0:                                       u8 | 1,

    seq_level_idx_0:                                  u8 | 5,
    seq_profile:                                      u8 | 3,

    version:                                          u8 | 7,
    marker:                                           u8 | 1,
}

ISOBMFFBrand :: enum u32 {
    AVIF = 'a' << 24 | 'v' << 16 | 'i' << 8 | 'f',
    MIF1 = 'm' << 24 | 'i' << 16 | 'f' << 8 | '1',
    MIAF = 'm' << 24 | 'i' << 16 | 'a' << 8 | 'f',
    MA1A = 'M' << 24 | 'A' << 16 | '1' << 8 | 'A',
    MA1B = 'M' << 24 | 'A' << 16 | '1' << 8 | 'B',
    AVIS = 'a' << 24 | 'v' << 16 | 'i' << 8 | 's',
    AVIO = 'a' << 24 | 'v' << 16 | 'i' << 8 | 'o',
    MSF1 = 'm' << 24 | 's' << 16 | 'f' << 8 | '1',
    AV01 = 'a' << 24 | 'v' << 16 | '0' << 8 | '1',
}

HEIFTrack :: enum u32 {
    PICT = 'p' << 24 | 'i' << 16 | 'c' << 8 | 't', // Picture track
}

save_to_buffer :: proc(
    output: ^bytes.Buffer,
    img: ^Image,
    options := Options{},
    allocator := context.allocator,
) -> (
    err: Error,
) {
    // TODO:
    return nil
}

load_from_bytes :: proc(
    data: []byte,
    options := Options{},
    allocator := context.allocator,
) -> (
    img: ^Image,
    err: Error,
) {
    context.allocator = allocator

    img = new(Image)
    //img.which = .AVIF

    reader: Reader
    reader_init(&reader, data)

    res := read_box(img, &reader)
    for res == .None {
        res = read_box(img, &reader)
    }

    if res != .EOF {
        fmt.eprintln(res)
        return nil, .Invalid_Input_Image
    }

    return img, nil
}

@(private)
read_box :: proc(img: ^Image, reader: ^Reader) -> (err: io.Error) {
    if read_header(reader) == .EOF {
        return .EOF
    }

    // if the Box has a size 0 then it's the last Box, parse it and return EOF
    if reader.size == 0 {
        err = .EOF
    }

    fmt.println("box size:", reader.size)
    fmt.println("type:", reader.type)

    #partial switch reader.type {
        case .FTYP:
            read_ftyp(img, reader)
        case .META:
            read_meta(reader)
        case .HDLR:
            read_hdlr(img, reader)
        case .PITM:
            read_pitm(img, reader)
        case .ILOC:
            read_iloc(reader)
        case .IINF:
            read_iinf(reader)
        case .INFE:
            read_infe(reader)
        case .IPRP: // Just serves as a container for the boxes inside it.
        case .IPCO: // Same as IPRP
        case .ISPE:
            read_ispe(reader)
        case .PIXI:
            read_pixi(reader)
        case .AV1C:
            read_av1c(reader)
        case .COLR:
            read_colr(reader)
        case .IPMA:
            read_ipma(reader)
        case:
            // Skip unknown boxes
            skip_box(reader)
    }

    return err
}

@(private)
read_ipma :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)
    entry_count, _ := read_u32be(reader)

    fmt.println("association entries:", entry_count)

    for i in 0 ..< entry_count {
        item_id: u32
        if vaf.version == 0 {
            t, _ := read_u16be(reader)
            item_id = auto_cast t
        } else {
            item_id, _ = read_u32be(reader)
        }

        association_count, _ := read_byte(reader)
        fmt.println("item_id:", item_id)
        fmt.println("association_count:", association_count)

        // TODO: something something association, IDFK I DONT HAVE THE LATEST SPEC CUZ ITS PAYWALLED
        for c in 0 ..< association_count {
            if (vaf.flags & 1) == 1 {     // if LSB is 1
                // TODO: idfk
                //data: [2]u8
                //reader_read(reader, data[:])
            } else {
                data, _ := read_byte(reader)
                fmt.println(data)
            }
        }
    }
}

@(private)
read_colr :: proc(reader: ^Reader) {
    _color_type: [4]u8
    read_slice(reader, _color_type[:])
    color_type := string(_color_type[:])

    if color_type == "nclx" {
        color_primaries, _ := read_u16be(reader)
        transfer_characteristics, _ := read_u16be(reader)
        matrix_coefficients, _ := read_u16be(reader)

        data, _ := read_byte(reader)

        // remaining 7 bits are reserved
        full_range_flag := data >> 7

        fmt.println("color primaries:", color_primaries)
        fmt.println("transfer characteristics:", transfer_characteristics)
        fmt.println("matrix coefficients:", matrix_coefficients)
        fmt.println("full_range_flag", full_range_flag)
    } else if color_type == "rICC" {
        // TODO: restricted icc profile
        fmt.eprintln("rICC color profile is not supported yet")
    } else if color_type == "prof" {
        fmt.eprintln("prof color profile is not supported yet")
        // TODO: icc profile
    }
}

@(private)
read_av1c :: proc(reader: ^Reader) {
    data, _ := read_bitfield(reader, AV1CodecConfigRecord)

    fmt.println(data)
}

@(private)
read_pixi :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    channel_bits: []u8

    if vaf.version == 0 {
        channels_count, _ := read_byte(reader)
        channel_bits = make([]u8, channels_count)

        fmt.printfln("There are %d channels in this image", channels_count)

        for i in 0 ..< channels_count {
            bits_per_channel, _ := read_byte(reader)
            channel_bits[i] = bits_per_channel
        }
    }

    fmt.println(channel_bits)
}

@(private)
read_ispe :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    if vaf.version == 0 {
        width, _ := read_u32be(reader)
        height, _ := read_u32be(reader)

        fmt.println("Width:", width)
        fmt.println("Height:", height)
    } else {
        // TODO: should we error here??
        fmt.eprintln("Unknown ispe version:", vaf.version)
    }
}

@(private)
read_infe :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    item_id: u32
    item_protection_index: u16
    item_name: string
    content_type: string
    content_encoding: string

    if vaf.version == 0 || vaf.version == 1 {
        _item_id, _ := read_u16be(reader)
        item_id = auto_cast _item_id
        item_protection_index, _ = read_u16be(reader)

        item_name, _ = read_string(reader)
        content_type, _ = read_string(reader)
        content_encoding, _ = read_string(reader)
    }

    if vaf.version == 1 {
        // TODO: ?? not sure about the ItemInfoExtension class
    }

    if vaf.version >= 2 {
        // Reference: https://github.com/strukturag/libheif/blob/master/libheif/box.cc#L1567
        hidden_item: bool = (vaf.flags & 1) == 1

        if vaf.version == 2 {
            t, _ := read_u16be(reader)
            item_id = auto_cast t
        } else if vaf.version == 3 {
            item_id, _ = read_u32be(reader)
        }

        item_uri_type: string
        item_type: [4]u8

        item_protection_index, _ = read_u16be(reader)
        read_slice(reader, item_type[:])

        item_name, _ = read_string(reader)

        // This is for ISOBMFF, avif uses av01 and similar named types
        if string(item_type[:]) == "mime" {
            content_type, _ = read_string(reader)
            content_encoding, _ := read_string(reader)
        } else if string(item_type[:]) == "uri " {
            item_uri_type, _ = read_string(reader)
        } else if string(item_type[:]) == "av01" {
            // TODO: ??? idfk
        }

        fmt.println("item type", string(item_type[:]))
        fmt.println("item uri type", item_uri_type)
    }

    fmt.println("VAF:", vaf)
    fmt.println("item_id", item_id)
    fmt.println("item_protection_index", item_protection_index)
    fmt.println("item_name", item_name)
    fmt.println("content type", content_type)
    fmt.println("content encoding", content_encoding)
}

@(private)
read_iinf :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    entry_count: u32 = 0
    if vaf.version == 0 {
        t, _ := read_u16be(reader)
        entry_count = auto_cast t
    } else {
        entry_count, _ = read_u32be(reader)
    }
}

@(private)
read_iloc :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)
    size, _ := read_bitfield(reader, ILOCSize)

    item_count: u32
    if vaf.version < 2 {
        _item_count, _ := read_u16be(reader)
        item_count = auto_cast _item_count
    } else if vaf.version == 2 {
        item_count, _ = read_u32be(reader)
    }

    fmt.println("VAF:", vaf)
    fmt.println("Size:", size)
    fmt.println("Item count", item_count)

    for i in 0 ..< item_count {
        item_id: u32
        construction_method: u8 = 0
        if vaf.version < 2 {
            _item_id, _ := read_u16be(reader)
            item_id = auto_cast _item_id
        } else {
            item_count, _ = read_u32be(reader)
        }

        if vaf.version == 1 || vaf.version == 2 {
            data, _ := read_u16be(reader)

            // First 12 bits are reserved
            construction_method = auto_cast (data & 0xF)
        }

        data_reference_index, _ := read_u16be(reader)
        base_offset: u64 = 0
        if size.base_offset_size == 4 {
            t, _ := read_u32be(reader)
            base_offset = auto_cast t
        } else if size.base_offset_size == 8 {
            base_offset, _ = read_u64be(reader)
        }
        extent_count, _ := read_u16be(reader)

        fmt.println("item id:", item_id)
        fmt.println("construction method", construction_method)
        fmt.println("data reference index", data_reference_index)
        fmt.println("base offset", base_offset)
        fmt.println("extent count", extent_count)

        for j in 0 ..< extent_count {
            if (vaf.version == 1 || vaf.version == 2) && size.index_size_OR_reserved > 0 {
                extent_index: u64 = 0
                if size.index_size_OR_reserved == 4 {
                    t, _ := read_u32be(reader)
                    extent_index = auto_cast t
                } else if size.index_size_OR_reserved == 8 {
                    extent_index, _ = read_u64be(reader)
                }

                fmt.println("extent index", extent_index)
            }
            extent_offset: u64 = 0
            extent_length: u64 = 0
            if size.offset_size == 4 {
                t, _ := read_u32be(reader)
                extent_offset = auto_cast t
            } else if size.offset_size == 8 {
                extent_offset, _ = read_u64be(reader)
            }


            if size.length_size == 4 {
                t, _ := read_u32be(reader)
                extent_length = auto_cast t
            } else if size.length_size == 8 {
                extent_length, _ = read_u64be(reader)
            }

            fmt.println("extent offset", extent_offset)
            fmt.println("extent length", extent_length)
        }
    }
}

@(private)
read_pitm :: proc(img: ^Image, reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    if vaf.version == 0 {
        item_id, _ := read_u16be(reader)

        img.primary_item_id = auto_cast item_id
    } else {
        img.primary_item_id, _ = read_u32be(reader)
    }
}

@(private)
read_hdlr :: proc(img: ^Image, reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)

    reader_seek(reader, 4, .Current) // Field called 'Predefined'. Always 0?
    handler_type, err := read_u32be(reader)
    if err != nil {
        fmt.eprintln(err)
    }
    reader_seek(reader, 4 * 3, .Current) // array with size 3 of 4byte reserved data. [3]u32

    img.handler_type = transmute(HEIFTrack)handler_type
    img.handler_name, _ = read_string(reader)
}

@(private)
read_meta :: proc(reader: ^Reader) {
    vaf, _ := read_bitfield(reader, VersionAndFlags)
    fmt.println("Meta Box VAF:", vaf)
}

@(private)
read_ftyp :: proc(img: ^Image, reader: ^Reader) {
    major_brand, _ := read_u32be(reader)
    img.major_brand = transmute(ISOBMFFBrand)major_brand
    img.brand_version, _ = read_u32be(reader)

    num_compatible_brands := remaining_box_size(reader) / size_of(ISOBMFFBrand)

    for i in 0 ..< num_compatible_brands {
        brand, _ := read_u32be(reader)
        append(&img.compatible_brands, transmute(ISOBMFFBrand)brand)
    }
}
