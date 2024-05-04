package avif

import "core:fmt"
import "core:io"

SELECT_SCREEN_CONTENT_TOOLS :: 2
SELECT_INTEGER_MV :: 2
MAX_OPERATING_POINTS :: 32
MAX_TILE_COLS :: 64
MAX_TILE_ROWS :: 64
NUM_REF_FRAMES :: 8
REFS_PER_FRAME :: 7
PRIMARY_REF_NONE :: 7
MAX_SEGMENTS :: 8

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
    ReservedSeqProfile,
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

ColorRange :: enum u8 {
    LIMITED = 0,
    FULL = 1,
}

FrameType :: enum u8 {
    KEY_FRAME = 0,
    INTER_FRAME = 1,
    INTRA_ONLY_FRAME = 2,
    SWITCH_FRAME = 3,
}

// Maybe just make these constants??
RefFrame0 :: enum u8 {
    INTRA_FRAME = 0,
    LAST_FRAME = 1,
    LAST2_FRAME = 2,
    LAST3_FRAME = 3,
    GOLDEN_FRAME = 4,
    BWDREF_FRAME = 5,
    ALTREF2_FRAME = 6,
    ALTREF_FRAME = 7,
}

RefFrame1 :: enum i8 {
    NONE = -1,
    INTRA_FRAME = 0,
    LAST_FRAME = 1,
    LAST2_FRAME = 2,
    LAST3_FRAME = 3,
    GOLDEN_FRAME = 4,
    BWDREF_FRAME = 5,
    ALTREF2_FRAME = 6,
    ALTREF_FRAME = 7,
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

SequenceHeader :: struct {
    enable_superres: bool,
    enable_cdef: bool,
    enable_restoration: bool,
    film_grain_params_present: bool,
    seq_profile: u8,
    BitDepth: u8,
    mono_chrome: bool,
    num_planes: u8,
    color_primaries: ColorPrimaries,
    transfer_characteristic: TransferCharacteristic,
    matrix_coefficients: MatrixCoefficient,
    chroma_sample_position: ChromeSamplePosition,
    subsampling_x: u8,
    subsampling_y: u8,
    separate_uv_delta_q: u8,
    color_range: ColorRange,
    OrderHintBits: u8,
    num_ticks_per_picture_minus_1: u64,
    time_scale: u32,
    num_units_in_display_tick: u32,
    buffer_delay_length_minus_1: u8,
    num_units_in_decoding_tick: u32,
    buffer_removal_time_length_minus_1: u8,
    frame_presentation_time_length_minus_1: u8,
    initial_display_delay_minus_1: [MAX_OPERATING_POINTS]u8,
    decoder_buffer_delay: [MAX_OPERATING_POINTS]u64,
    encoder_buffer_delay: [MAX_OPERATING_POINTS]u64,
    low_delay_mode_flag: [MAX_OPERATING_POINTS]bool,
    operating_point_idc_arr: [MAX_OPERATING_POINTS]u16,
    seq_level_idx: [MAX_OPERATING_POINTS]u8,
    seq_tier: [MAX_OPERATING_POINTS]u8,
    decoder_model_present_for_this_op: [MAX_OPERATING_POINTS]bool,
    initial_display_delay_present_for_this_op: [MAX_OPERATING_POINTS]bool,
    frame_id_numbers_present_flag: bool,
    additional_frame_id_length_minus_1: u8,
    delta_frame_id_length_minus_2: u8,
    reduced_still_picture_header: bool,
    equal_picture_interval: bool,
}

FrameHeader :: struct {
    SeenFrameHeader: bool,
    TileNum: u64,
    show_existing_frame: bool,
}

read_obu :: proc(r: ^Reader, seq_header: ^SequenceHeader, frame_header: ^FrameHeader) -> (err: Error) {
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

    start_pos := r.i * 8 + i64(r.bits_read_in_byte)

    //// TODO:
    //if header.obu_type != .SEQUENCE_HEADER && header.obu_type != .TEMPORAL_DELIMITER && OperatingPointIdc != 0 && header.obu_extension_flag == 1 {
    //    inTemporalLayer := (OperatingPointIdc >> temporal_id) & 1
    //    inSpatialLayer := (OperatingPointIdc >> (spatial_id + 8)) & 1

    //    if inTemporalLayer == 0 || inSpatialLayer == 0 {
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
            parse_sequence_header_obu(r, seq_header)
            fmt.println(seq_header)
        case .FRAME_HEADER:
            parse_frame_header_obu(r, size, seq_header, frame_header)
        case .FRAME:
            parse_frame_obu(r, size, seq_header, frame_header)
    }

    current_pos := r.i * 8 + i64(r.bits_read_in_byte)
    payload_bits := current_pos - start_pos

    fmt.println("start pos", start_pos)
    fmt.println("current pos", current_pos)
    fmt.println("payload_bits", payload_bits)
    fmt.println("trailing bits", size * 8 - u64(payload_bits))

    if size > 0 && header.obu_type != .TILE_GROUP && header.obu_type != .TILE_LIST && header.obu_type != .FRAME {
        trailing_bits(r, size * 8 - u64(payload_bits))
    }

    return nil
}

trailing_bits :: proc(r: ^Reader, nbits: u64) {
    nbits := nbits
    trailing_one_bit := f(r, 1)
    nbits -= 1

    for nbits > 0 {
        trailing_one_bit = f(r, 1)
        nbits -= 1
    }
}

timing_info :: proc(r: ^Reader, seq_header: ^SequenceHeader) {
    seq_header.num_units_in_display_tick = auto_cast f(r, 32)
    seq_header.time_scale = auto_cast f(r, 32)
    seq_header.equal_picture_interval = auto_cast f(r, 32)
    if seq_header.equal_picture_interval {
        seq_header.num_ticks_per_picture_minus_1 = uvlc(r)
    }
}

decoder_model_info :: proc(r: ^Reader, seq_header: ^SequenceHeader) {
    seq_header.buffer_delay_length_minus_1 = auto_cast f(r, 5)
    seq_header.num_units_in_decoding_tick = auto_cast f(r, 32)
    seq_header.buffer_removal_time_length_minus_1 = auto_cast f(r, 5)
    seq_header.frame_presentation_time_length_minus_1 = auto_cast f(r, 5)
}

operating_parameters_info :: proc(r: ^Reader, op: u8, seq_header: ^SequenceHeader) {
    n := seq_header.buffer_delay_length_minus_1 + 1
    seq_header.decoder_buffer_delay[op] = f(r, auto_cast n)
    seq_header.encoder_buffer_delay[op] = f(r, auto_cast n)
    seq_header.low_delay_mode_flag[op] = auto_cast f(r, 1)
}

color_config :: proc(r: ^Reader, seq_header: ^SequenceHeader) {
    high_bitdepth := bool(f(r, 1))

    if seq_header.seq_profile == 2 && high_bitdepth {
        twelve_bit := bool(f(r, 1))
        seq_header.BitDepth = twelve_bit ? 12 : 10
    } else if seq_header.seq_profile <= 2 {
        seq_header.BitDepth = high_bitdepth ? 10 : 8
    }

    if seq_header.seq_profile == 1 {
        seq_header.mono_chrome = false
    } else {
        seq_header.mono_chrome = auto_cast f(r, 1)
    }

    seq_header.num_planes = seq_header.mono_chrome ? 1 : 3
    color_description_present_flag: bool = auto_cast f(r, 1)

    if color_description_present_flag {
        seq_header.color_primaries = auto_cast f(r, 8)
        seq_header.transfer_characteristic = auto_cast f(r, 8)
        seq_header.matrix_coefficients = auto_cast f(r, 8)
    } else {
        seq_header.color_primaries = .UNSPECIFIED
        seq_header.transfer_characteristic = .UNSPECIFIED
        seq_header.matrix_coefficients = .UNSPECIFIED
    }

    if seq_header.mono_chrome {
        seq_header.color_range = auto_cast f(r, 1)
        seq_header.subsampling_x = 1
        seq_header.subsampling_y = 1
        seq_header.chroma_sample_position = .UNKNOWN
        seq_header.separate_uv_delta_q = 0
        return
    } else if seq_header.color_primaries == .BT_709 && seq_header.transfer_characteristic == .SRGB && seq_header.matrix_coefficients == .IDENTITY {
        seq_header.color_range = .FULL
        seq_header.subsampling_x = 0
        seq_header.subsampling_y = 0
    } else {
        seq_header.color_range = auto_cast f(r, 1)

        if seq_header.seq_profile == 0 {
            seq_header.subsampling_x = 1
            seq_header.subsampling_y = 1
        } else if seq_header.seq_profile == 1 {
            seq_header.subsampling_x = 0
            seq_header.subsampling_y = 0
        } else {
            if seq_header.BitDepth == 12 {
                seq_header.subsampling_x = auto_cast f(r, 1)

                if seq_header.subsampling_x == 1 {
                    seq_header.subsampling_y = auto_cast f(r, 1)
                } else {
                    seq_header.subsampling_y = 0
                }
            } else {
                seq_header.subsampling_x = 1
                seq_header.subsampling_y = 0
            }
        }

        if seq_header.subsampling_x == 1 && seq_header.subsampling_y == 1 {
            seq_header.chroma_sample_position = auto_cast f(r, 2)
        }
    }

    seq_header.separate_uv_delta_q = auto_cast f(r, 1)
}

parse_sequence_header_obu :: proc(r: ^Reader, seq_header: ^SequenceHeader) -> (OBUError) {
    seq_profile := f(r, 3)
    if seq_profile > 2 {
        return .ReservedSeqProfile
    }

    still_picture := f(r, 1)
    seq_header.reduced_still_picture_header := auto_cast f(r, 1)

    timing_info_present_flag: bool
    decoder_model_info_present_flag: bool
    initial_display_delay_present_flag: bool
    operating_points_cnt_minus_1: u8

    if seq_header.reduced_still_picture_header {
        // TODO: should these be saved as state ??
        timing_info_present_flag = false
        decoder_model_info_present_flag = false
        initial_display_delay_present_flag = false
        operating_points_cnt_minus_1 = 0
        seq_header.operating_point_idc_arr[0] = 0
        seq_header.seq_level_idx[0] = auto_cast f(r, 5)
        seq_header.seq_tier[0] = 0
        seq_header.decoder_model_present_for_this_op[0] = false
        seq_header.initial_display_delay_present_for_this_op[0] = false
    } else {
        timing_info_present_flag = auto_cast f(r, 1)

        if timing_info_present_flag {
            timing_info(r, seq_header)

            decoder_model_info_present_flag = auto_cast f(r, 1)
            if decoder_model_info_present_flag {
                decoder_model_info(r, seq_header)
            }
        } else {
            decoder_model_info_present_flag = false
        }

        initial_display_delay_present_flag = auto_cast f(r, 1)
        operating_points_cnt_minus_1 = auto_cast f(r, 5)

        for i in 0 ..=operating_points_cnt_minus_1 {
            seq_header.operating_point_idc_arr[i] = auto_cast f(r, 12)
            seq_header.seq_level_idx[i] = auto_cast f(r, 5)

            if seq_header.seq_level_idx[i] > 7 {
                seq_header.seq_tier[i] = auto_cast f(r, 1)
            } else {
                seq_header.seq_tier[i] = 0
            }

            if decoder_model_info_present_flag {
                seq_header.decoder_model_present_for_this_op[i] = auto_cast f(r, 1)
                if seq_header.decoder_model_present_for_this_op[i] {
                    operating_parameters_info(r, i, seq_header)
                }
            } else {
                seq_header.decoder_model_present_for_this_op[i] = false
            }

            if initial_display_delay_present_flag {
                seq_header.initial_display_delay_present_for_this_op[i] = auto_cast f(r, 1)
                if seq_header.initial_display_delay_present_for_this_op[i] {
                    seq_header.initial_display_delay_minus_1[i] = auto_cast f(r, 4)
                }
            }
        }
    }

    fmt.println("seq_profile:", seq_profile)
    fmt.println("still_picture:", still_picture)
    fmt.println("reduced_still_picture_header:", seq_header.reduced_still_picture_header)

    fmt.println("timing_info_present_flag:", timing_info_present_flag)
    fmt.println("decoder_model_info_present_flag:", decoder_model_info_present_flag)
    fmt.println("initial_display_delay_present_flag:", initial_display_delay_present_flag)
    fmt.println("operating_points_cnt_minus_1:", operating_points_cnt_minus_1)

    //operating_point := choose_operating_point()
    //operating_point_idc := seq_header.operating_point_idc_arr[operating_point]
    frame_width_bits_minus_1 := f(r, 4)
    frame_height_bits_minus_1 := f(r, 4)
    n := frame_width_bits_minus_1 + 1
    max_frame_width_minus_1 := f(r, auto_cast n)
    n = frame_height_bits_minus_1 + 1
    max_frame_height_minus_1 := f(r, auto_cast n)

    if seq_header.reduced_still_picture_header {
        seq_header.frame_id_numbers_present_flag = false
    } else {
        seq_header.frame_id_numbers_present_flag = auto_cast f(r, 1)
    }

    if seq_header.frame_id_numbers_present_flag {
        seq_header.delta_frame_id_length_minus_2 = auto_cast f(r, 4)
        seq_header.additional_frame_id_length_minus_1 = auto_cast f(r, 3)
    }

    use_128x128_superblock := f(r, 1)
    enable_filter_intra := f(r, 1)
    enable_intra_edge_filter := f(r, 1)

    fmt.println("frame_width_bits_minus_1:", frame_width_bits_minus_1)
    fmt.println("frame_height_bits_minus_1:", frame_height_bits_minus_1)
    fmt.println("max_frame_width_minus_1:", max_frame_width_minus_1)
    fmt.println("max_frame_height_minus_1:", max_frame_height_minus_1)

    fmt.println("frame_id_numbers_present_flag:", seq_header.frame_id_numbers_present_flag)
    fmt.println("delta_frame_id_length_minus_2:", seq_header.delta_frame_id_length_minus_2)
    fmt.println("additional_frame_id_length_minus_1:", seq_header.additional_frame_id_length_minus_1)

    fmt.println("use_128x128_superblock:", use_128x128_superblock)
    fmt.println("enable_filter_intra:", enable_filter_intra)
    fmt.println("enable_intra_edge_filter:", enable_intra_edge_filter)

    enable_interintra_compound: u8
    enable_masked_compound: u8
    enable_warped_motion: u8
    enable_dual_filter: u8
    enable_order_hint: bool
    enable_jnt_comp: u8
    enable_ref_frame_mvs: u8
    seq_force_screen_content_tools: u8
    seq_force_integer_mv: u8

    if seq_header.reduced_still_picture_header {
        enable_interintra_compound = 0
        enable_masked_compound = 0
        enable_warped_motion = 0
        enable_dual_filter = 0
        enable_order_hint = false
        enable_jnt_comp = 0
        enable_ref_frame_mvs = 0
        seq_force_screen_content_tools = SELECT_SCREEN_CONTENT_TOOLS
        seq_force_integer_mv = SELECT_INTEGER_MV
        seq_header.OrderHintBits = 0
    } else {
        enable_interintra_compound = auto_cast f(r, 1)
        enable_masked_compound = auto_cast f(r, 1)
        enable_warped_motion = auto_cast f(r, 1)
        enable_dual_filter = auto_cast f(r, 1)
        enable_order_hint = auto_cast f(r, 1)
        if enable_order_hint {
            enable_jnt_comp = auto_cast f(r, 1)
            enable_ref_frame_mvs = auto_cast f(r, 1)
        } else {
            enable_jnt_comp = 0
            enable_ref_frame_mvs = 0
        }

        seq_choose_screen_content_tools: bool = auto_cast f(r, 1)
        if seq_choose_screen_content_tools {
            seq_force_screen_content_tools = SELECT_SCREEN_CONTENT_TOOLS
        } else {
            seq_force_screen_content_tools = auto_cast f(r, 1)
        }

        if seq_force_screen_content_tools > 0 {
            seq_choose_integer_mv: bool = auto_cast f(r, 1)
            if seq_choose_integer_mv {
                seq_force_integer_mv = SELECT_INTEGER_MV
            } else {
                seq_force_integer_mv = auto_cast f(r, 1)
            }
        } else {
            seq_force_integer_mv = SELECT_INTEGER_MV
        }

        if enable_order_hint {
            order_hint_bits_minus_1 := f(r, 3)
            seq_header.OrderHintBits = u8(order_hint_bits_minus_1) + 1
        } else {
            seq_header.OrderHintBits = 0
        }
    }

    seq_header.enable_superres = auto_cast f(r, 1)
    seq_header.enable_cdef = auto_cast f(r, 1)
    seq_header.enable_restoration = auto_cast f(r, 1)
    color_config(r, seq_header)
    seq_header.film_grain_params_present = auto_cast f(r, 1)

    return nil
}

byte_alignment :: proc(r: ^Reader) {
    pos := r.i * 8 + i64(r.bits_read_in_byte)
    for pos & 7 == 1 {
        f(r, 1)
    }
}

parse_frame_obu :: proc(r: ^Reader, size: u64, seq_header: ^SequenceHeader, frame_header: ^FrameHeader) {
    size := size

    start_bit_pos := r.i * 8 + i64(r.bits_read_in_byte)
    parse_frame_header_obu(r, seq_header, frame_header)
    byte_alignment(r)
    end_bit_pos := r.i * 8 + i64(r.bits_read_in_byte)
    header_bytes := (end_bit_pos - start_bit_pos) / 8
    size -= u64(header_bytes)
    parse_tile_group_obu(r, size)
}

uncompressed_header :: proc(r: ^Reader, seq_header: ^SequenceHeader, frame_header: ^FrameHeader) {
    if seq_header.frame_id_numbers_present_flag {
        idLen := seq_header.additional_frame_id_length_minus_1 + seq_header.delta_frame_id_length_minus_2 + 3
    }

    allFrames := (1 << NUM_REF_FRAMES) - 1
    if seq_header.reduced_still_picture_header {
        frame_header.show_existing_frame = false
        frame_type = .KEY_FRAME
        FrameIsIntra = true
        show_frame = true
        showable_frame = false
    } else {
        frame_header.show_existing_frame = auto_cast f(r, 1)
        if frame_header.show_existing_frame {
            frame_to_show_map_idx = f(r, 3)
            if seq_header.decoder_model_info_present_flag && !seq_header.equal_picture_interval {
                temporal_point_info()
            }

            refresh_frame_flags = 0

            if seq_header.frame_id_numbers_present_flag {
                display_frame_id = f(r, idLen)
            }

            frame_type = RefFrameType[frame_to_show_map_idx]
            if frame_type == .KEY_FRAME {
                refresh_frame_flags = allFrames
            }
            if seq_header.film_grain_params_present {
                load_grain_params(frame_to_show_map_idx)
            }
            return
        }

        frame_type = f(r, 2)
        FrameIsIntra = frame_type == .INTRA_ONLY_FRAME || frame_type == .KEY_FRAME
        show_frame = f(r, 1)

        if show_frame && seq_header.decoder_model_info_present_flag && !seq_header.equal_picture_interval {
            temporal_point_info()
        }

        if show_frame {
            showable_frame = frame_type != .KEY_FRAME
        } else {
            showable_frame = f(r, 1)
        }

        if frame_type == .SWITCH_FRAME || (frame_type == .KEY_FRAME && show_frame) {
            error_resilient_mode = 1
        } else {
            error_resilient_mode = f(r, 1)
        }
    }

    if frame_type == .KEY_FRAME && show_frame {
        for i in 0..<NUM_REF_FRAMES {
            RefValid[i] = 0
            RefOrderHint[i] = 0
        }

        for i in 0..<REFS_PER_FRAME {
            OrderHints[.LAST_FRAME + i] = 0
        }
    }

    disable_cdf_update = f(r, 1)

    if seq_force_screen_content_tools == SELECT_SCREEN_CONTENT_TOOLS {
        allow_screen_content_tools = f(r, 1)
    } else {
        allow_screen_content_tools = seq_force_screen_content_tools
    }

    if allow_screen_content_tools {
        if seq_force_integer_mv == SELECT_INTEGER_MV {
            force_integer_mv = f(r, 1)
        } else {
            force_integer_mv = seq_force_integer_mv
        }
    } else {
        force_integer_mv = 0
    }

    if FrameIsIntra {
        force_integer_mv = 1
    }

    if seq_header.frame_id_numbers_present_flag {
        PrevFrameID = current_frame_id
        current_frame_id = f(r, idLen)
        mark_ref_frames(idLen)
    } else {
        current_frame_id = 0
    }

    if frame_type == .SWITCH_FRAME {
        frame_size_override_flag = 1
    } else if seq_header.reduced_still_picture_header {
        frame_size_override_flag = 0
    } else {
        frame_size_override_flag = f(r, 1)
    }

    order_hint = f(seq_header.OrderHintBits)
    OrderHint = order_hint

    if FrameIsIntra || error_resilient_mode {
        primary_ref_frame = PRIMARY_REF_NONE
    } else {
        primary_ref_frame = f(r, 3)
    }

    if seq_header.decoder_model_info_present_flag {
        buffer_removal_time_present_flag = f(r, 1)

        if buffer_removal_time_present_flag {
            for opNum in 0..=operating_points_cnt_minus_1 {
                if seq_header.decoder_model_present_for_this_op[opNum] {
                    opPtIdc = seq_header.operating_point_idc_arr[opNum]
                    inTemporalLayer = (opPtIdc >> temporal_id) & 1
                    inSpatialLayer = (opPtIdc >> (spatial_id + 8)) & 1
                    if opPtIdc == 0 || (inTemporalLayer && inSpatialLayer) {
                        n = buffer_removal_time_length_minus_1 + 1
                        buffer_removal_time[opNum]
                    }
                }
            }
        }
    }

    allow_high_precision_mv = 0
    use_ref_frame_mvs = 0
    allow_intrabc = 0

    if frame_type == .SWITCH_FRAME || (frame_type == .KEY_FRAME && show_frame) {
        refresh_frame_flags = allFrames
    } else {
        refresh_frame_flags = f(r, 8)
    }

    if !FrameIsIntra || refresh_frame_flags != allFrames {
        if error_resilient_mode && enable_order_hint {
            for i in 0..<NUM_REF_FRAMES {
                ref_order_hint[i] = f(r, OrderHintBits)
                if ref_order_hint[i] != RefOrderHint[i] {
                    RefValid[i] = 0
                }
            }
        }
    }

    if FrameIsIntra {
        frame_size()
        render_size()
        if allow_screen_content_tools && UpscaledWidth == FrameWidth {
            allow_intrabc = f(r, 1)
        }
    } else {
        if !enable_order_hint {
            frame_refs_short_signaling = 0
        } else {
            frame_refs_short_signaling = f(r, 1)
            if frame_refs_short_signaling {
                last_frame_id = f(r, 3)
                gold_frame_id = f(r, 3)
                set_frame_refs()
            }
        }

        for i in 0..<REFS_PER_FRAME {
            if !frame_refs_short_signaling {
                ref_frame_idx[i] = f(r, 3)
            }

            if seq_header.frame_id_numbers_present_flag {
                n = delta_frame_id_length_minus_2 + 2
                delta_frame_id_minus_1 = f(r, n)
                DeltaFrameId = delta_frame_id_minus_1 + 1
                expectedFrameId[i] = (current_frame_id + (1 << idLen) - DeltaFrameId ) % (1 << idLen)
            }
        }

        if frame_size_override_flag && !error_resilient_mode {
            frame_size_with_refs()
        } else {
            frame_size()
            render_size()
        }

        if force_integer_mv {
            allow_high_precision_mv = 0
        } else {
            allow_high_precision_mv = f(r, 1)
        }

        read_interpolation_filter()
        is_motion_mode_switchable = f(r, 1)

        if error_resilient_mode || !enable_ref_frame_mvs {
            use_ref_frame_mvs = 0
        } else {
            use_ref_frame_mvs = f(r, 1)
        }

        for i in 0..<REFS_PER_FRAME {
            refFrame = LAST_FRAME + i
            hint = RefOrderHint[ref_frame_idx[i]]
            OrderHints[refFrame] = hint
            if !enable_order_hint {
                RefFrameSignBias[refFrame] = 0
            } else {
                RefFrameSignBias[refFrame] = get_relative_dist(hint, OrderHint) > 0
            }
        }
    }

    if reduced_still_picture_header || disable_cdf_update {
        disable_frame_end_update_cdf = 1
    } else {
        disable_frame_end_update_cdf = f(r, 1)
    }

    if primary_ref_frame == PRIMARY_REF_NONE {
        init_non_coeff_cdfs()
        setup_past_independence()
    } else {
        load_cdfs(ref_frame_idx[primary_ref_frame])
        load_previous()
    }

    if use_ref_frame_mvs == 1 {
        motion_field_estimation()
    }

    tile_info()
    quantization_params()
    segmentation_params()
    delta_q_params()
    delta_lf_params()

    if primary_ref_frame == PRIMARY_REF_NONE {
        init_coeff_cdfs()
    } else {
        load_previous_segment_ids()
    }

    CodedLoseless = 1

    for segmentId in 0..<MAX_SEGMENTS {
        qindex = get_qindex(1, segmentId)
        LoselessArray[segmentId] = qindex == 0 && DeltaQYDc == 0 && DeltaQUAc == 0 && DeltaQUDc == 0 && DeltaQVAc == 0 && DeltaQVDc == 0

        if !LoselessArray[segmentId] {
            CodedLoseless = 0
        }

        if using_qmatrix {
            if LoselessArray[segmentId] {
                SegQMLevel[ 0 ][ segmentId ] = 15
                SegQMLevel[ 1 ][ segmentId ] = 15
                SegQMLevel[ 2 ][ segmentId ] = 15
            } else {
                SegQMLevel[ 0 ][ segmentId ] = qm_y
                SegQMLevel[ 1 ][ segmentId ] = qm_u
                SegQMLevel[ 2 ][ segmentId ] = qm_v
            }
        }
    }

    AllLossless = CodedLoseless && (FrameWidth == UpscaledWidth)
    loop_filter_params()
    cdef_params()
    lr_params()
    read_tx_mode()
    frame_reference_mode()
    skip_mode_params()

    if FrameIsIntra || error_resilient_mode || !enable_warped_motion {
        allow_wraped_motion = 0
    } else {
        allow_wraped_motion = f(r, 1)
    }

    reduced_tx_set = f(r, 1)
    global_motion_params()
    film_grain_params()
}

frame_header_copy :: proc() {
    // TODO:
}

decode_frame_wrapup :: proc(frame_header: ^FrameHeader) {
    // TODO:
    if frame_header.show_existing_frame {

    } else {

    }
}

parse_frame_header_obu :: proc(r: ^Reader, seq_header: ^SequenceHeader, frame_header: ^FrameHeader) {
    if frame_header.SeenFrameHeader {
        frame_header_copy()
    } else {
        frame_header.SeenFrameHeader = true
        uncompressed_header(r, seq_header, frame_header)

        if frame_header.show_existing_frame {
            decode_frame_wrapup(frame_header)
            frame_header.SeenFrameHeader = false
        } else {
            frame_header.TileNum = 0
            frame_header.SeenFrameHeader = true
        }
    }
}

parse_tile_group_obu :: proc(r: ^Reader, size: u64) {
    size := size

    NumTiles := TileCols * TileRows
    start_bit_pos := r.i * 8 + i64(r.bits_read_in_byte)
    tile_start_and_end_present_flags := false

    if NumTiles > 1 {
        tile_start_and_end_present_flags = auto_cast f(r, 1)
    }

    if NumTiles == 1 || !tile_start_and_end_present_flags {
        tg_start = 0
        tg_end = NumTiles - 1
    } else {
        tile_bits = TileColsLog2 + TileRowsLog2
        tg_start = f(r, tile_bits)
        tg_end = f(r, tile_bits)
    }
    byte_alignment(r)

    end_bit_pos := r.i * 8 + r.bits_read_in_byte
    header_bytes := (end_bit_pos - start_bit_pos) / 8
    size -= header_bytes

    for TileNum = tg_start; TileNum <= tg_end; TileNum+=1 {
        tile_row := TileNum / TileCols
        tile_col := TileNum % TileCols
        last_tile := TileNum == tg_end
        if last_tile {
            tile_size = size
        } else {
            tile_size_minus_1 := le(TileSizeBytes)
            tile_size = tile_size_minus_1 + 1
            size -= tile_size + TileSizeBytes
        }

        MiRowStart = MiRowStarts[tileRow]
        MiRowEnd = MiRowStarts[tileRow + 1]
        MiColStart = MiColStarts[tileCol]
        MiColEnd = MiColStarts[tileCol + 1]
        CurrentQIndex = base_q_idx
        init_symbol(tile_size)
        decode_tile()
        exit_symbol()
    }

    if tg_end == TileNum - 1 {
        if !disable_frame_end_update_cdf {
            frame_end_update_cdf()
        }

        decode_frame_wrapup()
        seen_frame_header = false
    }
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

le :: proc(r: ^Reader, n: int) -> u64 {
    t := 0

    for i in 0..<n {
        byte := f(r, 8)
        t += byte << (i * 8)
    }

    return t
}
