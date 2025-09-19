#ifndef MINIMP4_H
#define MINIMP4_H
/*
    https://github.com/aspt/mp4
    https://github.com/lieff/minimp4
    To the extent possible under law, the author(s) have dedicated all copyright and related and neighboring rights to this software to the public domain worldwide.
    This software is distributed without any warranty.
    See <http://creativecommons.org/publicdomain/zero/1.0/>.
*/

#include <stdio.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <limits.h>
#include <assert.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MINIMP4_MIN(x, y) ((x) < (y) ? (x) : (y))

/************************************************************************/
/*                  Build configuration                                */
/************************************************************************/

#define FIX_BAD_ANDROID_META_BOX  1

#define MAX_CHUNKS_DEPTH          64 // Max chunks nesting level

#define MINIMP4_MAX_SPS 32
#define MINIMP4_MAX_PPS 256

#define MINIMP4_TRANSCODE_SPS_ID  1

// Support indexing of MP4 files over 4 GB.
// If disabled, files with 64-bit offset fields is still supported,
// but error signaled if such field contains too big offset
// This switch affect return type of MP4D_frame_offset() function
#define MINIMP4_ALLOW_64BIT       1

#define MP4D_TRACE_SUPPORTED      0 // Debug trace
#define MP4D_TRACE_TIMESTAMPS     1
// Support parsing of supplementary information, not necessary for decoding:
// duration, language, bitrate, metadata tags, etc
#define MP4D_INFO_SUPPORTED       1

// Enable code, which prints to stdout supplementary MP4 information:
#define MP4D_PRINT_INFO_SUPPORTED 0

#define MP4D_AVC_SUPPORTED        1
#define MP4D_HEVC_SUPPORTED       1
#define MP4D_TIMESTAMPS_SUPPORTED 1

// Enable TrackFragmentBaseMediaDecodeTimeBox support
#define MP4D_TFDT_SUPPORT         0

/************************************************************************/
/*          Some values of MP4(E/D)_track_t->object_type_indication    */
/************************************************************************/
// MPEG-4 AAC (all profiles)
#define MP4_OBJECT_TYPE_AUDIO_ISO_IEC_14496_3                  0x40
// MPEG-2 AAC, Main profile
#define MP4_OBJECT_TYPE_AUDIO_ISO_IEC_13818_7_MAIN_PROFILE     0x66
// MPEG-2 AAC, LC profile
#define MP4_OBJECT_TYPE_AUDIO_ISO_IEC_13818_7_LC_PROFILE       0x67
// MPEG-2 AAC, SSR profile
#define MP4_OBJECT_TYPE_AUDIO_ISO_IEC_13818_7_SSR_PROFILE      0x68
// H.264 (AVC) video
#define MP4_OBJECT_TYPE_AVC                                     0x21
// H.265 (HEVC) video
#define MP4_OBJECT_TYPE_HEVC                                    0x23
// http://www.mp4ra.org/object.html 0xC0-E0  && 0xE2 - 0xFE are specified as "user private"
#define MP4_OBJECT_TYPE_USER_PRIVATE                            0xC0

/************************************************************************/
/*          API error codes                                            */
/************************************************************************/
#define MP4E_STATUS_OK                        0
#define MP4E_STATUS_BAD_ARGUMENTS            -1
#define MP4E_STATUS_NO_MEMORY                -2
#define MP4E_STATUS_FILE_WRITE_ERROR         -3
#define MP4E_STATUS_ONLY_ONE_DSI_ALLOWED     -4

/************************************************************************/
/*          Sample kind for MP4E_put_sample()                          */
/************************************************************************/
#define MP4E_SAMPLE_DEFAULT             0   // (beginning of) audio or video frame
#define MP4E_SAMPLE_RANDOM_ACCESS       1   // mark sample as random access point (key frame)
#define MP4E_SAMPLE_CONTINUATION        2   // Not a sample, but continuation of previous sample (new slice)

/************************************************************************/
/*                  Portable 64-bit type definition                    */
/************************************************************************/

#if MINIMP4_ALLOW_64BIT
    typedef uint64_t boxsize_t;
#else
    typedef unsigned int boxsize_t;
#endif
typedef boxsize_t MP4D_file_offset_t;

/************************************************************************/
/*          Some values of MP4D_track_t->handler_type                  */
/************************************************************************/
// Video track : 'vide'
#define MP4D_HANDLER_TYPE_VIDE                                  0x76696465
// Audio track : 'soun'
#define MP4D_HANDLER_TYPE_SOUN                                  0x736F756E
// General MPEG-4 systems streams (without specific handler).
// Used for private stream, as suggested in http://www.mp4ra.org/handler.html
#define MP4E_HANDLER_TYPE_GESM                                  0x6765736D

#define HEVC_NAL_VPS 32
#define HEVC_NAL_SPS 33
#define HEVC_NAL_PPS 34
#define HEVC_NAL_BLA_W_LP 16
#define HEVC_NAL_CRA_NUT 21

/************************************************************************/
/*          Data structures                                            */
/************************************************************************/

typedef struct MP4E_mux_tag MP4E_mux_t;

typedef enum
{
    e_audio,
    e_video,
    e_private
} track_media_kind_t;

typedef struct
{
    // MP4 object type code, which defined codec class for the track.
    // See MP4E_OBJECT_TYPE_* values for some codecs
    unsigned object_type_indication;

    // Track language: 3-char ISO 639-2T code: "und", "eng", "rus", "jpn" etc...
    unsigned char language[4];

    track_media_kind_t track_media_kind;

    // 90000 for video, sample rate for audio
    unsigned time_scale;
    unsigned default_duration;

    union
    {
        struct
        {
            // number of channels in the audio track.
            unsigned channelcount;
        } a;

        struct
        {
            int width;
            int height;
        } v;
    } u;

} MP4E_track_t;

typedef struct MP4D_sample_to_chunk_t_tag MP4D_sample_to_chunk_t;

typedef struct
{
    /************************************************************************/
    /*                 mandatory public data                               */
    /************************************************************************/
    // How many 'samples' in the track
    // The 'sample' is MP4 term, denoting audio or video frame
    unsigned sample_count;

    // Decoder-specific info (DSI) data
    unsigned char *dsi;

    // DSI data size
    unsigned dsi_bytes;

    // MP4 object type code
    unsigned object_type_indication;

#if MP4D_INFO_SUPPORTED
    /************************************************************************/
    /*                 informational public data                           */
    /************************************************************************/
    // handler_type when present in a media box, is an integer containing one of
    // the following values, or a value from a derived specification:
    // 'vide' Video track
    // 'soun' Audio track
    // 'hint' Hint track
    unsigned handler_type;

    // Track duration: 64-bit value split into 2 variables
    unsigned duration_hi;
    unsigned duration_lo;

    // duration scale: duration = timescale*seconds
    unsigned timescale;

    // Average bitrate, bits per second
    unsigned avg_bitrate_bps;

    // Track language: 3-char ISO 639-2T code: "und", "eng", "rus", "jpn" etc...
    unsigned char language[4];

    // MP4 stream type
    unsigned stream_type;

    union
    {
        // for handler_type == 'soun' tracks
        struct
        {
            unsigned channelcount;
            unsigned samplerate_hz;
        } audio;

        // for handler_type == 'vide' tracks
        struct
        {
            unsigned width;
            unsigned height;
        } video;
    } SampleDescription;
#endif

    /************************************************************************/
    /*                 private data: MP4 indexes                           */
    /************************************************************************/
    unsigned *entry_size;

    unsigned sample_to_chunk_count;
    struct MP4D_sample_to_chunk_t_tag *sample_to_chunk;

    unsigned chunk_count;
    MP4D_file_offset_t *chunk_offset;

#if MP4D_TIMESTAMPS_SUPPORTED
    unsigned *timestamp;
    unsigned *duration;
#endif

} MP4D_track_t;

typedef struct MP4D_demux_tag
{
    /************************************************************************/
    /*                 mandatory public data                               */
    /************************************************************************/
    int64_t read_pos;
    int64_t read_size;
    MP4D_track_t *track;
    int (*read_callback)(int64_t offset, void *buffer, size_t size, void *token);
    void *token;

    unsigned track_count; // number of tracks in the movie

#if MP4D_INFO_SUPPORTED
    /************************************************************************/
    /*                  informational public data                          */
    /************************************************************************/
    // Movie duration: 64-bit value split into 2 variables
    unsigned duration_hi;
    unsigned duration_lo;

    // duration scale: duration = timescale*seconds
    unsigned timescale;

    // Metadata tag (optional)
    // Tags provided 'as-is', without any re-encoding
    struct
    {
        unsigned char *title;
        unsigned char *artist;
        unsigned char *album;
        unsigned char *year;
        unsigned char *comment;
        unsigned char *genre;
    } tag;
#endif

} MP4D_demux_t;

struct MP4D_sample_to_chunk_t_tag
{
    unsigned first_chunk;
    unsigned samples_per_chunk;
};

/************************************************************************/
/*          API                                                         */
/************************************************************************/

/**
*   Parse given input stream as MP4 file. Allocate and store data indexes.
*   return 1 on success, 0 on failure
*
*   The MP4 indexes may be stored at the end of stream, so this
*   function may parse all stream.
*   It is guaranteed that function will read/seek sequentially,
*   and will never jump back.
*/
int MP4D_open(MP4D_demux_t *mp4, int (*read_callback)(int64_t offset, void *buffer, size_t size, void *token), void *token, int64_t file_size);

/**
*   Return position and size for given sample from given track. The 'sample' is a
*   MP4 term for 'frame'
*
*   frame_bytes [OUT]   - return coded frame size in bytes
*   timestamp [OUT]     - return frame timestamp (in mp4->timescale units)
*   duration [OUT]      - return frame duration (in mp4->timescale units)
*
*   function return offset for the frame
*/
MP4D_file_offset_t MP4D_frame_offset(const MP4D_demux_t *mp4, unsigned int ntrack, unsigned int nsample, unsigned int *frame_bytes, unsigned *timestamp, unsigned *duration);

/**
*   De-allocated memory
*/
void MP4D_close(MP4D_demux_t *mp4);

/**
*   Helper functions to parse mp4.track[ntrack].dsi for H.264 SPS/PPS
*   Return pointer to internal mp4 memory, it must not be free()-ed
*
*   Example: process all SPS in MP4 file:
*       while (sps = MP4D_read_sps(mp4, num_of_avc_track, sps_count, &sps_bytes))
*       {
*           process(sps, sps_bytes);
*           sps_count++;
*       }
*/
const void *MP4D_read_sps(const MP4D_demux_t *mp4, unsigned int ntrack, int nsps, int *sps_bytes);
const void *MP4D_read_pps(const MP4D_demux_t *mp4, unsigned int ntrack, int npps, int *pps_bytes);

#if MP4D_PRINT_INFO_SUPPORTED
/**
*   Print MP4 information to stdout.
*   Uses printf() as well as floating-point functions
*   Given as implementation example and for test purposes
*/
void MP4D_printf_info(const MP4D_demux_t *mp4);
#endif

#ifdef __cplusplus
}
#endif
#endif //MINIMP4_H

// Implementation follows when MINIMP4_IMPLEMENTATION is defined
#if defined(MINIMP4_IMPLEMENTATION) && !defined(MINIMP4_IMPLEMENTATION_GUARD)
#define MINIMP4_IMPLEMENTATION_GUARD

// [The rest of the implementation would go here - truncated for brevity]
// This includes all the parsing logic, box definitions, and demuxing code

#endif // MINIMP4_IMPLEMENTATION