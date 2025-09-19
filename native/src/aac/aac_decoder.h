/*
AAC ADTS Decoder
================

Simple AAC Low Complexity (LC) decoder implementation
Public Domain / CC0 - No licensing restrictions

This is a minimal AAC decoder supporting:
- AAC-LC (Low Complexity) profile only
- ADTS (Audio Data Transport Stream) format
- Basic stereo/mono decoding
- Sample rates: 8kHz to 96kHz

NOT SUPPORTED:
- HE-AAC v1/v2 (to avoid patent complications)
- AAC-Main, AAC-SSR profiles
- Spectral Band Replication (SBR)
- Parametric Stereo (PS)
- LATM/LOAS format
- Error concealment

Usage:
    AAC_Decoder decoder;
    aac_decoder_init(&decoder);
    
    // For ADTS stream
    AAC_Frame frame;
    if (aac_decode_adts_frame(&decoder, data, data_size, &frame) > 0) {
        // frame.samples contains PCM data
        // frame.num_samples is the sample count
        // frame.channels is channel count
        // frame.sample_rate is sample rate
    }
    
    aac_decoder_free(&decoder);
*/

#ifndef AAC_DECODER_H
#define AAC_DECODER_H

#ifdef __cplusplus
extern "C" {
#endif

#include <stdint.h>
#include <stddef.h>

#define AAC_MAX_CHANNELS 8
#define AAC_FRAME_SIZE 1024
#define AAC_MAX_SAMPLE_RATE 96000

// AAC profiles
typedef enum {
    AAC_PROFILE_MAIN = 1,
    AAC_PROFILE_LC = 2,    // Low Complexity - supported
    AAC_PROFILE_SSR = 3,
    AAC_PROFILE_LTP = 4
} AAC_Profile;

// ADTS header structure
typedef struct {
    uint8_t syncword_high;        // 0xFFF
    uint8_t syncword_low_and_flags;
    uint8_t profile_and_freq;     // profile (2 bits) + freq_index (4 bits) + private (1 bit) + channels_high (1 bit)
    uint8_t channels_and_flags;   // channels_low (2 bits) + other flags
    uint8_t frame_length_high;    // frame_length (13 bits) + other flags
    uint8_t frame_length_mid;
    uint8_t frame_length_low_and_buffer;
} ADTS_Header;

// Parsed ADTS info
typedef struct {
    int profile;
    int sample_rate_index;
    int sample_rate;
    int channels;
    int frame_length;
    int has_crc;
    int copyright;
    int original;
    int emphasis;
} ADTS_Info;

// Decoded AAC frame
typedef struct {
    float* samples;               // Interleaved PCM samples
    int num_samples;              // Number of samples per channel
    int channels;                 // Number of channels
    int sample_rate;              // Sample rate in Hz
    int valid;                    // 1 if frame is valid
} AAC_Frame;

// AAC decoder context
typedef struct {
    // Configuration
    int sample_rate;
    int channels;
    int profile;
    
    // Internal buffers
    float window_buffer[AAC_MAX_CHANNELS][AAC_FRAME_SIZE * 2];
    float mdct_buffer[AAC_FRAME_SIZE];
    float spectrum[AAC_FRAME_SIZE];
    
    // Previous frame state for overlap-add
    float prev_spectrum[AAC_MAX_CHANNELS][AAC_FRAME_SIZE];
    int has_prev_frame;
    
    // Memory management
    float* output_buffer;
    size_t output_buffer_size;
} AAC_Decoder;

// Sample rate table for AAC
static const int aac_sample_rates[16] = {
    96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050,
    16000, 12000, 11025, 8000, 7350, 0, 0, 0
};

// Function declarations
int aac_decoder_init(AAC_Decoder* decoder);
void aac_decoder_free(AAC_Decoder* decoder);
int aac_parse_adts_header(const uint8_t* data, size_t data_size, ADTS_Info* info);
int aac_decode_adts_frame(AAC_Decoder* decoder, const uint8_t* data, size_t data_size, AAC_Frame* frame);
int aac_decode_frame_data(AAC_Decoder* decoder, const uint8_t* frame_data, size_t frame_size, AAC_Frame* frame);
int aac_find_adts_sync(const uint8_t* data, size_t data_size);
size_t aac_estimate_decoded_memory(int sample_rate, int channels, int duration_ms);

// Utility functions
static inline int aac_get_sample_rate(int index) {
    return (index < 16) ? aac_sample_rates[index] : 0;
}

static inline int aac_sync_word_valid(const uint8_t* data) {
    return data[0] == 0xFF && (data[1] & 0xF0) == 0xF0;
}

#ifdef __cplusplus
}
#endif

#endif // AAC_DECODER_H