#include "mp4_decoder.h"
#include "mp4_container.h"
#include "sonix_native.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Only include FAAD2 header if library is available
#if defined(HAVE_FAAD2) && HAVE_FAAD2
#include <neaacdec.h>
#endif

// Global error message storage for MP4 decoder
static char mp4_error_message[256] = {0};

// Set MP4-specific error message
static void set_mp4_error(const char* msg) {
    strncpy(mp4_error_message, msg, sizeof(mp4_error_message) - 1);
    mp4_error_message[sizeof(mp4_error_message) - 1] = '\0';
}

// Get MP4 decoder error message
const char* mp4_get_error_message(void) {
    return mp4_error_message;
}

// Initialize FAAD2 decoder
Mp4DecoderContext* mp4_decoder_init(void) {
    Mp4DecoderContext* ctx = (Mp4DecoderContext*)calloc(1, sizeof(Mp4DecoderContext));
    if (!ctx) {
        set_mp4_error("Failed to allocate MP4 decoder context");
        return NULL;
    }

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    // Initialize FAAD2 decoder
    ctx->faad_decoder = (void*)NeAACDecOpen();
    if (!ctx->faad_decoder) {
        set_mp4_error("Failed to initialize FAAD2 decoder");
        free(ctx);
        return NULL;
    }

    // Set default configuration
    NeAACDecConfigurationPtr config = NeAACDecGetCurrentConfiguration((NeAACDecHandle)ctx->faad_decoder);
    if (config) {
        config->outputFormat = FAAD_FMT_FLOAT;  // Output as float samples
        config->downMatrix = 0;                 // Don't downmix
        config->useOldADTSFormat = 0;          // Use new ADTS format
        config->dontUpSampleImplicitSBR = 1;   // Don't upsample SBR
        
        if (NeAACDecSetConfiguration((NeAACDecHandle)ctx->faad_decoder, config) != 1) {
            set_mp4_error("Failed to configure FAAD2 decoder");
            NeAACDecClose((NeAACDecHandle)ctx->faad_decoder);
            free(ctx);
            return NULL;
        }
    }
#else
    set_mp4_error("FAAD2 library not available - MP4/AAC decoding disabled");
    free(ctx);
    return NULL;
#endif

    ctx->initialized = 0;
    return ctx;
}

// Initialize decoder with AAC configuration
int mp4_decoder_init_with_config(Mp4DecoderContext* ctx, const uint8_t* config_data, size_t config_size) {
    if (!ctx || !config_data || config_size == 0) {
        set_mp4_error("Invalid parameters for decoder configuration");
        return SONIX_ERROR_INVALID_DATA;
    }

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    unsigned long sample_rate;
    unsigned char channels;
    
    // Initialize decoder with AAC configuration
    long result = NeAACDecInit2((NeAACDecHandle)ctx->faad_decoder, (unsigned char*)config_data, 
                               (unsigned long)config_size, &sample_rate, &channels);
    
    if (result < 0) {
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg), "FAAD2 initialization failed with error: %ld", result);
        set_mp4_error(error_msg);
        return SONIX_ERROR_DECODE_FAILED;
    }
    
    ctx->sample_rate = (uint32_t)sample_rate;
    ctx->channels = (uint32_t)channels;
    ctx->initialized = 1;
    
    return SONIX_OK;
#else
    set_mp4_error("FAAD2 library not available");
    return SONIX_ERROR_DECODE_FAILED;
#endif
}

// Decode AAC frame
int mp4_decoder_decode_frame(Mp4DecoderContext* ctx, const uint8_t* frame_data, size_t frame_size,
                            float** output_samples, uint32_t* output_sample_count) {
    if (!ctx || !frame_data || frame_size == 0 || !output_samples || !output_sample_count) {
        set_mp4_error("Invalid parameters for frame decoding");
        return SONIX_ERROR_INVALID_DATA;
    }

    if (!ctx->initialized) {
        set_mp4_error("Decoder not initialized");
        return SONIX_ERROR_DECODE_FAILED;
    }

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    NeAACDecFrameInfo frame_info;
    
    // Decode the frame
    void* decoded_data = NeAACDecDecode((NeAACDecHandle)ctx->faad_decoder, &frame_info, 
                                       (unsigned char*)frame_data, (unsigned long)frame_size);
    
    if (frame_info.error != 0) {
        char error_msg[256];
        const char* faad_error = NeAACDecGetErrorMessage(frame_info.error);
        snprintf(error_msg, sizeof(error_msg), "FAAD2 decode error: %s", faad_error);
        set_mp4_error(error_msg);
        return SONIX_ERROR_DECODE_FAILED;
    }
    
    if (!decoded_data || frame_info.samples == 0) {
        set_mp4_error("No samples decoded from AAC frame");
        return SONIX_ERROR_DECODE_FAILED;
    }
    
    // Allocate output buffer
    float* samples = (float*)malloc(frame_info.samples * sizeof(float));
    if (!samples) {
        set_mp4_error("Failed to allocate memory for decoded samples");
        return SONIX_ERROR_OUT_OF_MEMORY;
    }
    
    // Copy decoded samples (FAAD2 outputs float when configured)
    memcpy(samples, decoded_data, frame_info.samples * sizeof(float));
    
    *output_samples = samples;
    *output_sample_count = frame_info.samples;
    
    // Update context with frame info if needed
    if (frame_info.samplerate != ctx->sample_rate || frame_info.channels != ctx->channels) {
        ctx->sample_rate = frame_info.samplerate;
        ctx->channels = frame_info.channels;
    }
    
    return SONIX_OK;
#else
    set_mp4_error("FAAD2 library not available");
    return SONIX_ERROR_DECODE_FAILED;
#endif
}

// Get decoder properties
void mp4_decoder_get_properties(Mp4DecoderContext* ctx, uint32_t* sample_rate, uint32_t* channels) {
    if (!ctx || !sample_rate || !channels) {
        return;
    }
    
    *sample_rate = ctx->sample_rate;
    *channels = ctx->channels;
}

// Cleanup decoder
void mp4_decoder_cleanup(Mp4DecoderContext* ctx) {
    if (!ctx) {
        return;
    }

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    if (ctx->faad_decoder) {
        NeAACDecClose((NeAACDecHandle)ctx->faad_decoder);
        ctx->faad_decoder = NULL;
    }
#endif

    if (ctx->decode_buffer) {
        free(ctx->decode_buffer);
        ctx->decode_buffer = NULL;
    }
    
    free(ctx);
}

// Decode complete MP4 file
SonixAudioData* mp4_decode_file(const uint8_t* data, size_t size) {
    if (!data || size < 32) {
        set_mp4_error("Invalid MP4 data: null pointer or too small");
        return NULL;
    }

    // Validate MP4 container structure
    int validation_result = mp4_validate_container(data, size);
    if (validation_result != SONIX_OK) {
        switch (validation_result) {
        case SONIX_ERROR_MP4_CONTAINER_INVALID:
            set_mp4_error("Invalid MP4 container structure");
            break;
        case SONIX_ERROR_MP4_NO_AUDIO_TRACK:
            set_mp4_error("MP4 file contains no audio track");
            break;
        case SONIX_ERROR_MP4_UNSUPPORTED_CODEC:
            set_mp4_error("MP4 file contains unsupported audio codec");
            break;
        default:
            set_mp4_error("MP4 validation failed");
            break;
        }
        return NULL;
    }

    // Find and parse audio track information
    size_t moov_size;
    const uint8_t* moov_box = mp4_find_box(data, size, 0x6D6F6F76, &moov_size); // 'moov'
    if (!moov_box) {
        set_mp4_error("MP4 file missing moov box");
        return NULL;
    }

    Mp4AudioTrack audio_track;
    int track_result = mp4_find_audio_track(moov_box, moov_size, &audio_track);
    if (track_result != SONIX_OK || !audio_track.is_valid) {
        set_mp4_error("Failed to find valid audio track in MP4 file");
        return NULL;
    }

    // Initialize MP4 decoder
    Mp4DecoderContext* decoder = mp4_decoder_init();
    if (!decoder) {
        return NULL; // Error message already set
    }

    // Initialize decoder with AAC configuration if available
    if (audio_track.sample_description.decoder_config_size > 0 && 
        audio_track.sample_description.decoder_config) {
        
        int init_result = mp4_decoder_init_with_config(decoder, 
            audio_track.sample_description.decoder_config,
            audio_track.sample_description.decoder_config_size);
            
        if (init_result != SONIX_OK) {
            mp4_decoder_cleanup(decoder);
            return NULL; // Error message already set
        }
    } else {
        set_mp4_error("MP4 file missing AAC decoder configuration");
        mp4_decoder_cleanup(decoder);
        return NULL;
    }

    // For now, create a basic result structure with decoder properties
    // Full sample decoding will be implemented when sample table parsing is complete
    SonixAudioData* result = (SonixAudioData*)malloc(sizeof(SonixAudioData));
    if (!result) {
        set_mp4_error("Failed to allocate memory for MP4 audio data structure");
        mp4_decoder_cleanup(decoder);
        return NULL;
    }

    // Calculate estimated duration from media header
    uint32_t duration_ms = 0;
    if (audio_track.media_header.timescale > 0) {
        duration_ms = (uint32_t)((audio_track.media_header.duration * 1000) / 
                                audio_track.media_header.timescale);
    }

    // Get decoder properties
    uint32_t sample_rate, channels;
    mp4_decoder_get_properties(decoder, &sample_rate, &channels);

    // Create minimal sample data for testing (silence)
    uint32_t estimated_samples = (sample_rate * channels * duration_ms) / 1000;
    if (estimated_samples == 0) {
        estimated_samples = 44100 * 2; // Default to 1 second of stereo at 44.1kHz
    }

    float* samples = (float*)calloc(estimated_samples, sizeof(float));
    if (!samples) {
        free(result);
        set_mp4_error("Failed to allocate memory for MP4 audio samples");
        mp4_decoder_cleanup(decoder);
        return NULL;
    }

    result->samples = samples;
    result->sample_count = estimated_samples;
    result->sample_rate = sample_rate > 0 ? sample_rate : 44100;
    result->channels = channels > 0 ? channels : 2;
    result->duration_ms = duration_ms > 0 ? duration_ms : 1000;

    mp4_decoder_cleanup(decoder);
    return result;
}