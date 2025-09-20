#ifndef MP4_DECODER_H
#define MP4_DECODER_H

#include <stdint.h>
#include <stddef.h>
#include "sonix_native.h"

#ifdef __cplusplus
extern "C" {
#endif

// MP4 decoder context structure
typedef struct {
    void* faad_decoder;             // FAAD2 decoder handle (NeAACDecHandle when available)
    uint32_t sample_rate;           // Sample rate
    uint32_t channels;              // Channel count
    uint8_t* decode_buffer;         // Temporary decode buffer
    size_t buffer_size;             // Buffer size
    int initialized;                // Decoder initialization flag
} Mp4DecoderContext;

/**
 * Initialize MP4 decoder with FAAD2
 * @return Pointer to decoder context or NULL on error
 */
Mp4DecoderContext* mp4_decoder_init(void);

/**
 * Initialize decoder with AAC configuration data
 * @param ctx Decoder context
 * @param config_data AAC decoder configuration data
 * @param config_size Size of configuration data
 * @return SONIX_OK on success, error code on failure
 */
int mp4_decoder_init_with_config(Mp4DecoderContext* ctx, const uint8_t* config_data, size_t config_size);

/**
 * Decode AAC frame using FAAD2
 * @param ctx Decoder context
 * @param frame_data AAC frame data
 * @param frame_size Size of frame data
 * @param output_samples Pointer to store decoded samples (caller must free)
 * @param output_sample_count Pointer to store number of decoded samples
 * @return SONIX_OK on success, error code on failure
 */
int mp4_decoder_decode_frame(Mp4DecoderContext* ctx, const uint8_t* frame_data, size_t frame_size,
                            float** output_samples, uint32_t* output_sample_count);

/**
 * Get decoder properties (sample rate, channels)
 * @param ctx Decoder context
 * @param sample_rate Pointer to store sample rate
 * @param channels Pointer to store channel count
 */
void mp4_decoder_get_properties(Mp4DecoderContext* ctx, uint32_t* sample_rate, uint32_t* channels);

/**
 * Cleanup decoder and free resources
 * @param ctx Decoder context
 */
void mp4_decoder_cleanup(Mp4DecoderContext* ctx);

/**
 * Decode complete MP4 file
 * @param data MP4 file data
 * @param size Size of file data
 * @return Pointer to decoded audio data or NULL on error
 */
SonixAudioData* mp4_decode_file(const uint8_t* data, size_t size);

/**
 * Get MP4 decoder error message
 * @return Pointer to error message string
 */
const char* mp4_get_error_message(void);

#ifdef __cplusplus
}
#endif

#endif // MP4_DECODER_H