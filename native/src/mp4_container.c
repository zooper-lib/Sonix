#include "mp4_container.h"
#include "sonix_native.h"
#include <string.h>
#include <stdlib.h>
#include <stdio.h>

// MP4 box type constants (4-byte identifiers)
#define BOX_TYPE_FTYP 0x66747970  // 'ftyp'
#define BOX_TYPE_MOOV 0x6D6F6F76  // 'moov'
#define BOX_TYPE_TRAK 0x7472616B  // 'trak'
#define BOX_TYPE_MDIA 0x6D646961  // 'mdia'
#define BOX_TYPE_MINF 0x6D696E66  // 'minf'
#define BOX_TYPE_STBL 0x7374626C  // 'stbl'
#define BOX_TYPE_STSD 0x73747364  // 'stsd'
#define BOX_TYPE_STTS 0x73747473  // 'stts'
#define BOX_TYPE_STSC 0x73747363  // 'stsc'
#define BOX_TYPE_STSZ 0x7374737A  // 'stsz'
#define BOX_TYPE_STCO 0x7374636F  // 'stco'
#define BOX_TYPE_CO64 0x636F3634  // 'co64'
#define BOX_TYPE_MDHD 0x6D646864  // 'mdhd'
#define BOX_TYPE_TKHD 0x746B6864  // 'tkhd'
#define BOX_TYPE_HDLR 0x68646C72  // 'hdlr'

// Audio codec constants
#define CODEC_TYPE_MP4A 0x6D703461  // 'mp4a'
#define HANDLER_TYPE_SOUN 0x736F756E  // 'soun'

// Helper function to read 32-bit big-endian integer
static uint32_t read_be32(const uint8_t* data) {
    return ((uint32_t)data[0] << 24) | 
           ((uint32_t)data[1] << 16) | 
           ((uint32_t)data[2] << 8) | 
           (uint32_t)data[3];
}

// Helper function to read 64-bit big-endian integer
static uint64_t read_be64(const uint8_t* data) {
    return ((uint64_t)read_be32(data) << 32) | read_be32(data + 4);
}

// Helper function to read 16-bit big-endian integer
static uint16_t read_be16(const uint8_t* data) {
    return ((uint16_t)data[0] << 8) | (uint16_t)data[1];
}

int mp4_parse_box_header(const uint8_t* data, size_t data_size, Mp4BoxHeader* header) {
    if (!data || !header || data_size < 8) {
        return SONIX_ERROR_INVALID_DATA;
    }

    header->size = read_be32(data);
    header->type = read_be32(data + 4);
    header->header_size = 8;

    // Handle 64-bit size
    if (header->size == 1) {
        if (data_size < 16) {
            return SONIX_ERROR_INVALID_DATA;
        }
        header->size = read_be64(data + 8);
        header->header_size = 16;
    } else if (header->size == 0) {
        // Size extends to end of file - not supported in this implementation
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    // Validate box size
    if (header->size < header->header_size || header->size > data_size) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    return SONIX_OK;
}

int mp4_validate_ftyp_box(const uint8_t* data, size_t size) {
    if (!data || size < 16) {
        return SONIX_ERROR_INVALID_DATA;
    }

    Mp4BoxHeader header;
    int result = mp4_parse_box_header(data, size, &header);
    if (result != SONIX_OK) {
        return result;
    }

    if (header.type != BOX_TYPE_FTYP) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    // Check for supported brands (simplified check)
    const uint8_t* brand_data = data + header.header_size;
    uint32_t major_brand = read_be32(brand_data);
    
    // Accept common MP4 brands
    if (major_brand == 0x69736F6D ||  // 'isom'
        major_brand == 0x6D703431 ||  // 'mp41'
        major_brand == 0x6D703432 ||  // 'mp42'
        major_brand == 0x4D344120 ||  // 'M4A '
        major_brand == 0x4D344220) {  // 'M4B '
        return SONIX_OK;
    }

    return SONIX_ERROR_MP4_UNSUPPORTED_CODEC;
}

const uint8_t* mp4_find_box(const uint8_t* data, size_t data_size, uint32_t box_type, size_t* box_size) {
    if (!data || !box_size) {
        return NULL;
    }

    const uint8_t* current = data;
    size_t remaining = data_size;

    while (remaining >= 8) {
        Mp4BoxHeader header;
        if (mp4_parse_box_header(current, remaining, &header) != SONIX_OK) {
            break;
        }

        if (header.type == box_type) {
            *box_size = (size_t)header.size;
            return current;
        }

        // Move to next box
        if (header.size > remaining) {
            break;
        }
        current += header.size;
        remaining -= header.size;
    }

    return NULL;
}

int mp4_parse_mdhd_box(const uint8_t* data, size_t size, Mp4MediaHeader* mdhd) {
    if (!data || !mdhd || size < 24) {
        return SONIX_ERROR_INVALID_DATA;
    }

    Mp4BoxHeader header;
    int result = mp4_parse_box_header(data, size, &header);
    if (result != SONIX_OK) {
        return result;
    }

    if (header.type != BOX_TYPE_MDHD) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    const uint8_t* box_data = data + header.header_size;
    uint8_t version = box_data[0];

    if (version == 0) {
        // 32-bit version
        if (header.size < header.header_size + 20) {
            return SONIX_ERROR_INVALID_DATA;
        }
        mdhd->creation_time = read_be32(box_data + 4);
        mdhd->modification_time = read_be32(box_data + 8);
        mdhd->timescale = read_be32(box_data + 12);
        mdhd->duration = read_be32(box_data + 16);
    } else if (version == 1) {
        // 64-bit version
        if (header.size < header.header_size + 32) {
            return SONIX_ERROR_INVALID_DATA;
        }
        mdhd->creation_time = read_be64(box_data + 4);
        mdhd->modification_time = read_be64(box_data + 12);
        mdhd->timescale = read_be32(box_data + 20);
        mdhd->duration = read_be64(box_data + 24);
    } else {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    return SONIX_OK;
}

int mp4_parse_hdlr_box(const uint8_t* data, size_t size, Mp4HandlerReference* hdlr) {
    if (!data || !hdlr || size < 24) {
        return SONIX_ERROR_INVALID_DATA;
    }

    Mp4BoxHeader header;
    int result = mp4_parse_box_header(data, size, &header);
    if (result != SONIX_OK) {
        return result;
    }

    if (header.type != BOX_TYPE_HDLR) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    const uint8_t* box_data = data + header.header_size;
    
    // Skip version and flags (4 bytes) and pre_defined (4 bytes)
    hdlr->handler_type = read_be32(box_data + 8);
    
    // Check if this is an audio track
    hdlr->is_audio = (hdlr->handler_type == HANDLER_TYPE_SOUN);

    return SONIX_OK;
}

int mp4_parse_stsd_box(const uint8_t* data, size_t size, Mp4SampleDescription* stsd) {
    if (!data || !stsd || size < 16) {
        return SONIX_ERROR_INVALID_DATA;
    }

    Mp4BoxHeader header;
    int result = mp4_parse_box_header(data, size, &header);
    if (result != SONIX_OK) {
        return result;
    }

    if (header.type != BOX_TYPE_STSD) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    const uint8_t* box_data = data + header.header_size;
    
    // Skip version and flags (4 bytes)
    uint32_t entry_count = read_be32(box_data + 4);
    
    if (entry_count == 0) {
        return SONIX_ERROR_MP4_NO_AUDIO_TRACK;
    }

    // Parse first sample entry
    const uint8_t* entry_data = box_data + 8;
    if (entry_data + 16 > data + size) {
        return SONIX_ERROR_INVALID_DATA;
    }

    uint32_t entry_size = read_be32(entry_data);
    uint32_t codec_type = read_be32(entry_data + 4);

    stsd->codec_type = codec_type;
    stsd->is_supported = (codec_type == CODEC_TYPE_MP4A);

    // For audio sample entries, extract additional info
    if (stsd->is_supported && entry_size >= 36) {
        // Skip reserved fields (6 bytes) and data reference index (2 bytes)
        // Skip audio-specific reserved fields (8 bytes)
        stsd->channels = read_be16(entry_data + 24);
        stsd->sample_size = read_be16(entry_data + 26);
        // Skip compression ID and packet size (4 bytes)
        stsd->sample_rate = read_be32(entry_data + 32) >> 16; // Fixed-point 16.16
    }

    return SONIX_OK;
}

int mp4_parse_sample_table(const uint8_t* stbl_data, size_t stbl_size, Mp4SampleTable* sample_table) {
    if (!stbl_data || !sample_table) {
        return SONIX_ERROR_INVALID_DATA;
    }

    // Initialize sample table
    memset(sample_table, 0, sizeof(Mp4SampleTable));

    // Find and parse STSZ (sample sizes)
    size_t stsz_size;
    const uint8_t* stsz_box = mp4_find_box(stbl_data, stbl_size, BOX_TYPE_STSZ, &stsz_size);
    if (stsz_box) {
        Mp4BoxHeader header;
        if (mp4_parse_box_header(stsz_box, stsz_size, &header) == SONIX_OK) {
            const uint8_t* stsz_data = stsz_box + header.header_size;
            // Skip version and flags (4 bytes)
            uint32_t default_size = read_be32(stsz_data + 4);
            sample_table->sample_count = read_be32(stsz_data + 8);
            
            if (default_size == 0 && sample_table->sample_count > 0) {
                // Variable sample sizes - would need to read the table
                // For now, just store the count
                sample_table->has_sample_sizes = 1;
            } else {
                sample_table->default_sample_size = default_size;
                sample_table->has_sample_sizes = 1;
            }
        }
    }

    // Find and parse STCO/CO64 (chunk offsets)
    size_t stco_size;
    const uint8_t* stco_box = mp4_find_box(stbl_data, stbl_size, BOX_TYPE_STCO, &stco_size);
    if (!stco_box) {
        stco_box = mp4_find_box(stbl_data, stbl_size, BOX_TYPE_CO64, &stco_size);
    }
    
    if (stco_box) {
        Mp4BoxHeader header;
        if (mp4_parse_box_header(stco_box, stco_size, &header) == SONIX_OK) {
            const uint8_t* stco_data = stco_box + header.header_size;
            // Skip version and flags (4 bytes)
            sample_table->chunk_count = read_be32(stco_data + 4);
            sample_table->has_chunk_offsets = 1;
        }
    }

    return SONIX_OK;
}

int mp4_find_audio_track(const uint8_t* moov_data, size_t moov_size, Mp4AudioTrack* audio_track) {
    if (!moov_data || !audio_track) {
        return SONIX_ERROR_INVALID_DATA;
    }

    // Initialize audio track
    memset(audio_track, 0, sizeof(Mp4AudioTrack));

    const uint8_t* current = moov_data;
    size_t remaining = moov_size;

    // Skip moov box header
    Mp4BoxHeader moov_header;
    if (mp4_parse_box_header(current, remaining, &moov_header) != SONIX_OK) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }
    
    current += moov_header.header_size;
    remaining -= moov_header.header_size;

    // Search for trak boxes
    while (remaining >= 8) {
        size_t trak_size;
        const uint8_t* trak_box = mp4_find_box(current, remaining, BOX_TYPE_TRAK, &trak_size);
        if (!trak_box) {
            break;
        }

        // Parse this track
        Mp4BoxHeader trak_header;
        if (mp4_parse_box_header(trak_box, trak_size, &trak_header) != SONIX_OK) {
            break;
        }

        const uint8_t* trak_data = trak_box + trak_header.header_size;
        size_t trak_content_size = trak_size - trak_header.header_size;

        // Find mdia box within trak
        size_t mdia_size;
        const uint8_t* mdia_box = mp4_find_box(trak_data, trak_content_size, BOX_TYPE_MDIA, &mdia_size);
        if (mdia_box) {
            Mp4BoxHeader mdia_header;
            if (mp4_parse_box_header(mdia_box, mdia_size, &mdia_header) == SONIX_OK) {
                const uint8_t* mdia_data = mdia_box + mdia_header.header_size;
                size_t mdia_content_size = mdia_size - mdia_header.header_size;

                // Check handler reference to see if this is an audio track
                size_t hdlr_size;
                const uint8_t* hdlr_box = mp4_find_box(mdia_data, mdia_content_size, BOX_TYPE_HDLR, &hdlr_size);
                if (hdlr_box) {
                    Mp4HandlerReference hdlr;
                    if (mp4_parse_hdlr_box(hdlr_box, hdlr_size, &hdlr) == SONIX_OK && hdlr.is_audio) {
                        // This is an audio track - parse its information
                        audio_track->track_id = 1; // Simplified - would need to parse tkhd for real ID

                        // Parse media header for timing info
                        size_t mdhd_size;
                        const uint8_t* mdhd_box = mp4_find_box(mdia_data, mdia_content_size, BOX_TYPE_MDHD, &mdhd_size);
                        if (mdhd_box) {
                            mp4_parse_mdhd_box(mdhd_box, mdhd_size, &audio_track->media_header);
                        }

                        // Find minf box and then stbl box for sample table
                        size_t minf_size;
                        const uint8_t* minf_box = mp4_find_box(mdia_data, mdia_content_size, BOX_TYPE_MINF, &minf_size);
                        if (minf_box) {
                            Mp4BoxHeader minf_header;
                            if (mp4_parse_box_header(minf_box, minf_size, &minf_header) == SONIX_OK) {
                                const uint8_t* minf_data = minf_box + minf_header.header_size;
                                size_t minf_content_size = minf_size - minf_header.header_size;

                                size_t stbl_size;
                                const uint8_t* stbl_box = mp4_find_box(minf_data, minf_content_size, BOX_TYPE_STBL, &stbl_size);
                                if (stbl_box) {
                                    Mp4BoxHeader stbl_header;
                                    if (mp4_parse_box_header(stbl_box, stbl_size, &stbl_header) == SONIX_OK) {
                                        const uint8_t* stbl_data = stbl_box + stbl_header.header_size;
                                        size_t stbl_content_size = stbl_size - stbl_header.header_size;

                                        // Parse sample description
                                        size_t stsd_size;
                                        const uint8_t* stsd_box = mp4_find_box(stbl_data, stbl_content_size, BOX_TYPE_STSD, &stsd_size);
                                        if (stsd_box) {
                                            mp4_parse_stsd_box(stsd_box, stsd_size, &audio_track->sample_description);
                                        }

                                        // Parse sample table
                                        mp4_parse_sample_table(stbl_data, stbl_content_size, &audio_track->sample_table);
                                        
                                        audio_track->is_valid = 1;
                                        return SONIX_OK;
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // Move to next potential trak box
        size_t advance = trak_size;
        if (advance > remaining) {
            break;
        }
        current = trak_box + advance;
        remaining = (current < moov_data + moov_size) ? (moov_data + moov_size - current) : 0;
    }

    return SONIX_ERROR_MP4_NO_AUDIO_TRACK;
}

int mp4_validate_container(const uint8_t* data, size_t size) {
    if (!data || size < 32) {
        return SONIX_ERROR_INVALID_DATA;
    }

    // Check ftyp box
    size_t ftyp_size;
    const uint8_t* ftyp_box = mp4_find_box(data, size, BOX_TYPE_FTYP, &ftyp_size);
    if (!ftyp_box) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    int result = mp4_validate_ftyp_box(ftyp_box, ftyp_size);
    if (result != SONIX_OK) {
        return result;
    }

    // Check for moov box
    size_t moov_size;
    const uint8_t* moov_box = mp4_find_box(data, size, BOX_TYPE_MOOV, &moov_size);
    if (!moov_box) {
        return SONIX_ERROR_MP4_CONTAINER_INVALID;
    }

    // Try to find an audio track
    Mp4AudioTrack audio_track;
    result = mp4_find_audio_track(moov_box, moov_size, &audio_track);
    if (result != SONIX_OK) {
        return result;
    }

    if (!audio_track.is_valid || !audio_track.sample_description.is_supported) {
        return SONIX_ERROR_MP4_UNSUPPORTED_CODEC;
    }

    return SONIX_OK;
}