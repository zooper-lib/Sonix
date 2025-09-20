#ifndef MP4_CONTAINER_H
#define MP4_CONTAINER_H

#include <stdint.h>
#include <stddef.h>

#ifdef __cplusplus
extern "C" {
#endif

// MP4 box header structure
typedef struct {
    uint64_t size;          // Box size (including header)
    uint32_t type;          // Box type (4-character code)
    uint8_t header_size;    // Size of the box header (8 or 16 bytes)
} Mp4BoxHeader;

// MP4 media header (mdhd box)
typedef struct {
    uint64_t creation_time;
    uint64_t modification_time;
    uint32_t timescale;
    uint64_t duration;
} Mp4MediaHeader;

// MP4 handler reference (hdlr box)
typedef struct {
    uint32_t handler_type;
    int is_audio;           // 1 if this is an audio track, 0 otherwise
} Mp4HandlerReference;

// MP4 sample description (stsd box)
typedef struct {
    uint32_t codec_type;    // Codec type (e.g., 'mp4a')
    int is_supported;       // 1 if codec is supported, 0 otherwise
    uint16_t channels;      // Number of audio channels
    uint16_t sample_size;   // Sample size in bits
    uint32_t sample_rate;   // Sample rate in Hz
} Mp4SampleDescription;

// MP4 sample table information
typedef struct {
    uint32_t sample_count;      // Number of samples
    uint32_t chunk_count;       // Number of chunks
    uint32_t default_sample_size; // Default sample size (0 if variable)
    int has_sample_sizes;       // 1 if sample size table is present
    int has_chunk_offsets;      // 1 if chunk offset table is present
} Mp4SampleTable;

// MP4 audio track information
typedef struct {
    uint32_t track_id;              // Track identifier
    Mp4MediaHeader media_header;    // Media header information
    Mp4SampleDescription sample_description; // Sample description
    Mp4SampleTable sample_table;    // Sample table information
    int is_valid;                   // 1 if track is valid and usable
} Mp4AudioTrack;

/**
 * Parse MP4 box header from data
 * @param data Pointer to box data
 * @param data_size Size of available data
 * @param header Pointer to header structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_parse_box_header(const uint8_t* data, size_t data_size, Mp4BoxHeader* header);

/**
 * Validate MP4 ftyp box and check for supported brands
 * @param data Pointer to ftyp box data
 * @param size Size of ftyp box
 * @return SONIX_OK if valid and supported, error code otherwise
 */
int mp4_validate_ftyp_box(const uint8_t* data, size_t size);

/**
 * Find a specific box type within MP4 data
 * @param data Pointer to MP4 data to search
 * @param data_size Size of data to search
 * @param box_type Box type to find (4-byte identifier)
 * @param box_size Pointer to store found box size
 * @return Pointer to box data or NULL if not found
 */
const uint8_t* mp4_find_box(const uint8_t* data, size_t data_size, uint32_t box_type, size_t* box_size);

/**
 * Parse MP4 media header (mdhd) box
 * @param data Pointer to mdhd box data
 * @param size Size of mdhd box
 * @param mdhd Pointer to media header structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_parse_mdhd_box(const uint8_t* data, size_t size, Mp4MediaHeader* mdhd);

/**
 * Parse MP4 handler reference (hdlr) box
 * @param data Pointer to hdlr box data
 * @param size Size of hdlr box
 * @param hdlr Pointer to handler reference structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_parse_hdlr_box(const uint8_t* data, size_t size, Mp4HandlerReference* hdlr);

/**
 * Parse MP4 sample description (stsd) box
 * @param data Pointer to stsd box data
 * @param size Size of stsd box
 * @param stsd Pointer to sample description structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_parse_stsd_box(const uint8_t* data, size_t size, Mp4SampleDescription* stsd);

/**
 * Parse MP4 sample table from stbl box data
 * @param stbl_data Pointer to stbl box content data
 * @param stbl_size Size of stbl box content
 * @param sample_table Pointer to sample table structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_parse_sample_table(const uint8_t* stbl_data, size_t stbl_size, Mp4SampleTable* sample_table);

/**
 * Find and parse audio track information from moov box
 * @param moov_data Pointer to moov box data
 * @param moov_size Size of moov box
 * @param audio_track Pointer to audio track structure to fill
 * @return SONIX_OK on success, error code on failure
 */
int mp4_find_audio_track(const uint8_t* moov_data, size_t moov_size, Mp4AudioTrack* audio_track);

/**
 * Validate MP4 container structure and audio track presence
 * @param data Pointer to MP4 file data
 * @param size Size of MP4 file data
 * @return SONIX_OK if valid container with supported audio, error code otherwise
 */
int mp4_validate_container(const uint8_t* data, size_t size);

#ifdef __cplusplus
}
#endif

#endif // MP4_CONTAINER_H