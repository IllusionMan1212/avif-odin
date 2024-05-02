package avif

import "core:fmt"
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

OBUError :: enum {
    ReservedOBU,
}

ColorPrimaries :: enum u8 {
    BT_709 = 1,
    UNSPECIFIED = 2,
    BT_470_M = 4,
    BT_470_B_G = 5,
    BT_601 = 6,
    SMPTE_240 = 7,
    GENERIC_FILM = 8,
    BT_2020 = 9,
    XYZ = 10,
    SMPTE_431 = 11,
    SMPTE_432 = 12,
    EBU_3213 = 22,
}

TransferCharacteristic :: enum u8 {
    RESERVED_0 = 0,
    BT_709 = 1,
    UNSPECIFIED = 2,
    RESERVED_3 = 3,
    BT_470_M = 4,
    BT_470_B_G = 5,
    BT_601 = 6,
    SMPTE_240 = 7,
    LINEAR = 8,
    LOG_100 = 9,
    LOG_100_SQRT10 = 10,
    IEC_61966 = 11,
    BT_1361 = 12,
    SRGB = 13,
    BT_2020_10_BIT = 14,
    BT_2020_12_BIT = 15,
    SMPTE_2084 = 16,
    SMPTE_428 = 17,
    HLG = 18,
}

MatrixCoefficient :: enum u8 {
    IDENTITY = 0,
    BT_709 = 1,
    UNSPECIFIED = 2,
    RESERVED_3 = 3,
    FCC = 4,
    BT_470_B_G = 5,
    BT_601 = 6,
    SMPTE_240 = 7,
    SMPTE_YCGCO = 8,
    BT_2020_NCL = 9,
    BT_2020_CL = 10,
    SMPTE_2085 = 11,
    CHROMAT_NCL = 12,
    CHROMAT_CL = 13,
    ICTCP = 14,
}

ChromeSamplePosition :: enum u8 {
    UNKNOWN = 0,
    VERTICAL = 1,
    COLOCATED = 2,
    RESERVED = 3,
}

OBUHeader :: bit_field u8 {
    obu_reserved:       u8      | 1,
    obu_has_size_field: b8      | 1,
    obu_extension_flag: b8      | 1,
    obu_type:           OBUType | 4,
    obu_forbidden_bit:  u8      | 1,
}

OBUExtensionHeader :: bit_field u8 {
    extension_header_reserved: u8 | 3,
    spatial_id:                u8 | 2,
    temporal_id:               u8 | 3,
}

read_obu :: proc(r: ^Reader) -> (err: Error) {
    header := read_bitfield(r, OBUHeader) or_return
    size: u64

    fmt.println(header)

    if header.obu_extension_flag {
        ext_header := read_bitfield(r, OBUExtensionHeader) or_return

        fmt.println(ext_header)
    }

    if header.obu_has_size_field {
        size = leb128(r)
    } else {
        // TODO: is this correct ???
        // The spec is NOT clear about wtf sz is, so I assume it's the box size without the header.
        // It's also possibly the remaining box size, we'll have to check how other decoders do it.
        size = u64(r.box.size - BOX_HEADER_SIZE - 1 - u32(header.obu_extension_flag))
    }

    // TODO: get bit position
    //start_pos := get_position()

    //// TODO:
    //if header.obu_type != .SEQUENCE_HEADER && header.obu_type != .TEMPORAL_DELIMITER && OperatingPointIdc != 0 && header.obu_extension_flag == 1 {
    //    in_temporal_layer := (OperatingPointIdc >> temporal_id) & 1
    //    in_spatial_layer := (OperatingPointIdc >> (spatial_id + 8)) & 1

    //    if in_temporal_layer == 0 || in_spatial_layer == 0 {
    //        drop_obu()
    //        return
    //    }
    //}

    fmt.println("OBU size:", size)

    if header.obu_type != .SEQUENCE_HEADER &&
       header.obu_type != .TEMPORAL_DELIMITER &&
       header.obu_type != .FRAME_HEADER &&
       header.obu_type != .TILE_GROUP &&
       header.obu_type != .METADATA &&
       header.obu_type != .FRAME &&
       header.obu_type != .REDUNDANT_FRAME_HEADER &&
       header.obu_type != .TILE_LIST &&
       header.obu_type != .PADDING {
        return .ReservedOBU
    }

    #partial switch header.obu_type {
        case .TEMPORAL_DELIMITER:
            // do nothing. the temporal OBU has an empty payload
        case .SEQUENCE_HEADER:
            parse_sequence_header_obu(r)
        case .FRAME:
            // TODO:
    }

    // TODO:
    //current_pos := get_position()
    //payload_bits := current_pos - start_pos

    //if size > 0 && header.obu_type != .TILE_GROUP && header.obu_type != .TILE_LIST && header.obu_type != .FRAME {
    //    trailing_bits(size * 8 - payload_bits)
    //}

    return nil
}

//timing_info :: proc(r: ^Reader) {
//    num_units_in_display_tick = f(r, 32)
//    time_scale = f(r, 32)
//    equal_picture_interval = f(r, 32)
//    if equal_picture_interval == 1 {
//        num_ticks_per_picture_minus_1 = uvlc(r)
//    }
//}
//
//decoder_model_info :: proc(r: ^Reader) {
//    buffer_delay_length_minus_1 = f(r, 5)
//    num_units_in_decoding_tick = f(r, 32)
//    buffer_removal_time_length_minus_1 = f(r, 5)
//    frame_presentation_time_length_minus_1 = f(r, 5)
//}
//
//operating_parameters_info :: proc(r: ^Reader, op: u8) {
//    n = buffer_delay_length_minus_1 + 1
//    decoder_buffer_delay[op] = f(r, n)
//    encoder_buffer_delay[op] = f(r, n)
//    low_delay_mode_flag[op] = f(r, 1)
//}
//
//color_config :: proc(r: ^Reader) {
//    high_bitdepth = f(r, 1)
//
//    if seq_profile == 2 && high_bitdepth == 1 {
//        twelve_bit = f(r, 1)
//        BitDepth = twelve_bit == 1 ? 12 : 10
//    } else if seq_profile <= 2 {
//        BitDepth = high_bitdepth == 1 ? 10 : 8
//    }
//
//    if seq_profile == 1 {
//        mono_chrome = 0
//    } else {
//        mono_chrome = f(r, 1)
//    }
//
//    num_planes = mono_chrome == 1 ? 1 : 3
//    color_description_present_flag = f(r, 1)
//
//    if color_description_present_flag == 1 {
//        color_primaries = auto_cast f(r, 8)
//        transfer_characteristic = auto_cast f(r, 8)
//        matrix_coefficients = auto_cast f(r, 8)
//    } else {
//        color_primaries = .UNSPECIFIED
//        transfer_characteristic = .UNSPECIFIED
//        matrix_coefficients = .UNSPECIFIED
//    }
//
//    if mono_chrome == 1 {
//        color_range = f(r, 1)
//        subsampling_x = 1
//        subsampling_y = 1
//        chroma_sample_position = .UNKNOWN
//        separate_uv_delta_q = 0
//        return
//    } else if color_primaries == .BT_709 && transfer_characteristic == .SRGB && matrix_coefficients == .IDENTITY {
//        color_range = 1
//        subsampling_x = 0
//        subsampling_y = 0
//    } else {
//        color_range = f(r, 1)
//
//        if seq_profile == 0 {
//            subsampling_x = 1
//            subsampling_y = 1
//        } else if seq_profile == 1 {
//            subsampling_x = 0
//            subsampling_y = 0
//        } else {
//            if BitDepth == 12 {
//                subsampling_x = f(r, 1)
//
//                if subsampling_x == 1 {
//                    subsampling_y = f(r, 1)
//                } else {
//                    subsampling_y = 0
//                }
//            } else {
//                subsampling_x = 1
//                subsampling_y = 0
//            }
//        }
//
//        if subsampling_x == 1 && subsampling_y == 1 {
//            chroma_sample_position = auto_cast f(r, 2)
//        }
//    }
//
//    separate_uv_delta_q = f(r, 1)
//}

parse_sequence_header_obu :: proc(r: ^Reader) {
    seq_profile := f(r, 3)
    still_picture := f(r, 1)
    reduced_still_picture_header := f(r, 1)

    timing_info_present_flag: u8
    decoder_model_info_present_flag: u8
    initial_display_delay_present_flag: u8
    operating_points_cnt_minus_1: u8

    if reduced_still_picture_header == 1 {
        // TODO: should these be saved as state ??
        timing_info_present_flag = 0
        decoder_model_info_present_flag = 0
        initial_display_delay_present_flag = 0
        operating_points_cnt_minus_1 = 0
        //operating_point_idc[ 0 ] = 0
        //seq_level_idx[ 0 ]
        //seq_tier[ 0 ] = 0
        //decoder_model_present_for_this_op[ 0 ] = 0
        //initial_display_delay_present_for_this_op[ 0 ] = 0
    } else {
        //timing_info_present_flag = auto_cast f(r, 1)

        //if timing_info_present_flag == 1 {
        //    timing_info(r)

        //    decoder_model_info_present_flag = auto_cast f(r, 1)
        //    if decoder_model_info_present_flag == 1 {
        //        decoder_model_info(r)
        //    }
        //} else {
        //    decoder_model_info_present_flag = 0
        //}

        //initial_display_delay_present_flag = auto_cast f(r, 1)
        //operating_points_cnt_minus_1 = auto_cast f(r, 5)

        //for i in 0 ..=operating_points_cnt_minus_1 {
        //    operating_point_idc[i] = f(r, 12)
        //    seq_level_idx[i] = f(r, 5)

        //    if seq_level_idx[i] > 7 {
        //        seq_tier[i] = f(r, 1)
        //    } else {
        //        seq_tier[i] = 0
        //    }

        //    if decoder_model_info_present_flag == 1 {
        //        decoder_model_present_for_this_op[i] = f(r, 1)
        //        if decoder_model_present_for_this_op[i] == 1 {
        //            operating_parameters_info(r, i)
        //        }
        //    } else {
        //        decoder_model_present_for_this_op[i] = 0
        //    }

        //    if initial_display_delay_present_flag == 1 {
        //        initial_display_delay_present_for_this_op[i] = f(r, 1)
        //        if initial_display_delay_present_for_this_op[i] == 1 {
        //            initial_display_delay_minus_1[i] = f(r, 4)
        //        }
        //    }
        //}
    }

    fmt.println("seq_profile:", seq_profile)
    fmt.println("still_picture:", still_picture)
    fmt.println("reduced_still_picture_header:", reduced_still_picture_header)

    fmt.println("timing_info_present_flag:", timing_info_present_flag)
    fmt.println("decoder_model_info_present_flag:", decoder_model_info_present_flag)
    fmt.println("initial_display_delay_present_flag:", initial_display_delay_present_flag)
    fmt.println("operating_points_cnt_minus_1:", operating_points_cnt_minus_1)

    //operating_point := choose_operating_point()
    //operating_point_idc_one := operating_point_idc[operating_point]
    frame_width_bits_minus_1 := f(r, 4)
    frame_height_bits_minus_1 := f(r, 4)
    n := frame_width_bits_minus_1 + 1
    max_frame_width_minus_1 := f(r, auto_cast n)
    n = frame_height_bits_minus_1 + 1
    max_frame_height_minus_1 := f(r, auto_cast n)

    frame_id_numbers_present_flag: u8
    delta_frame_id_length_minus_2: u8
    additional_frame_id_length_minus_1: u8

    if reduced_still_picture_header == 1 {
        frame_id_numbers_present_flag = 0
    } else {
        frame_id_numbers_present_flag = auto_cast f(r, 1)
    }

    if frame_id_numbers_present_flag == 1 {
        delta_frame_id_length_minus_2 = auto_cast f(r, 4)
        additional_frame_id_length_minus_1 = auto_cast f(r, 3)
    }

    use_128x128_superblock := f(r, 1)
    enable_filter_intra := f(r, 1)
    enable_intra_edge_filter := f(r, 1)

    fmt.println("frame_width_bits_minus_1:", frame_width_bits_minus_1)
    fmt.println("frame_height_bits_minus_1:", frame_height_bits_minus_1)
    fmt.println("max_frame_width_minus_1:", max_frame_width_minus_1)
    fmt.println("max_frame_height_minus_1:", max_frame_height_minus_1)

    fmt.println("frame_id_numbers_present_flag:", frame_id_numbers_present_flag)
    fmt.println("delta_frame_id_length_minus_2:", delta_frame_id_length_minus_2)
    fmt.println("additional_frame_id_length_minus_1:", additional_frame_id_length_minus_1)

    fmt.println("use_128x128_superblock:", use_128x128_superblock)
    fmt.println("enable_filter_intra:", enable_filter_intra)
    fmt.println("enable_intra_edge_filter:", enable_intra_edge_filter)

    //if reduced_still_picture_header == 1 {
    //    enable_interintra_compound = 0
    //    enable_masked_compound = 0
    //    enable_warped_motion = 0
    //    enable_dual_filter = 0
    //    enable_order_hint = 0
    //    enable_jnt_comp = 0
    //    enable_ref_frame_mvs = 0
    //    seq_force_screen_content_tools = SELECT_SCREEN_CONTENT_TOOLS
    //    seq_force_integer_mv = SELECT_INTEGER_MV
    //    OrderHintBits = 0
    //} else {
    //    enable_interintra_compount = f(r, 1)
    //    enable_masked_compound = f(r, 1)
    //    enable_warped_motion = f(r, 1)
    //    enable_dual_filter = f(r, 1)
    //    enable_order_hint = f(r, 1)
    //    if enable_order_hint == 1 {
    //        enable_jnt_comp = f(r, 1)
    //        enable_ref_frame_mvs = f(r, 1)
    //    } else {
    //        enable_jnt_comp = 0
    //        enable_ref_frame_mvs = 0
    //    }

    //    seq_choose_screen_content_tools = f(r, 1)
    //    if seq_choose_screen_content_tools == 1 {
    //        seq_force_screen_content_tools = SELECT_SCREEN_CONTENT_TOOLS
    //    } else {
    //        seq_force_screen_content_tools = f(r, 1)
    //    }

    //    if seq_force_screen_content_tools > 0 {
    //        seq_choose_integer_mv = f(r, 1)
    //        if seq_choose_integer_mv == 1 {
    //            seq_force_integer_mv = SELECT_INTEGER_MV
    //        } else {
    //            seq_force_integer_mv = f(r, 1)
    //        }
    //    } else {
    //        seq_force_integer_mv = SELECT_INTEGER_MV
    //    }

    //    if enable_order_hint == 1 {
    //        order_hint_bits_minus_1 = f(r, 3)
    //        OrderHintBits = order_hint_bits_minus_1 + 1
    //    } else {
    //        OrderHintBits = 0
    //    }
    //}

    //enable_superres = f(r, 1)
    //enable_cdef = f(r, 1)
    //enable_restoration = f(r, 1)
    //color_config()
    //film_grain_params_present = f(r, 1)
}

f :: proc(r: ^Reader, n: int) -> u64 {
    x: u64 = 0

    for i in 0 ..< n {
        // TODO: maybe get rid of or_break and propagate the error??
        x = 2 * x + auto_cast read_bit(r) or_break
    }

    return x
}

leb128 :: proc(r: ^Reader) -> u64 {
    value: u64 = 0
    leb128_bytes := 0

    for i: u64 = 0; i < 8; i += 1 {
        leb128_byte := f(r, 8)
        value |= ((leb128_byte & 0x7f) << (i * 7))
        leb128_bytes += 1

        if (leb128_byte & 0x80) == 0 {
            break
        }
    }

    return value
}

uvlc :: proc(r: ^Reader) -> u64 {
    leading_zeros: u64 = 0

    for {
        done := f(r, 1)
        if done == 1 {
            break
        }
        leading_zeros += 1
    }

    if leading_zeros >= 32 {
        return (1 << 32) - 1
    }

    value := f(r, auto_cast leading_zeros)
    return value + (1 << leading_zeros) - 1
}
