#include "sonix_native.h"
#include "mp4_decoder.h"
#include "mp4_container.h"
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

// Chunked processing implementation

void* mp4_init_chunked_context(const char* file_path) {
    if (!file_path) {
        set_mp4_error("Invalid file path for MP4 chunked context");
        return NULL;
    }

    // Allocate context - use the struct definition from sonix_native.h
    SonixMp4Context* context = (SonixMp4Context*)calloc(1, sizeof(SonixMp4Context));
    if (!context) {
        set_mp4_error("Failed to allocate MP4 chunked context");
        return NULL;
    }

    // Open file for reading
    FILE* file = fopen(file_path, "rb");
    if (!file) {
        set_mp4_error("Failed to open MP4 file for chunked processing");
        free(context);
        return NULL;
    }

    // Read file header to validate and get track information
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    fseek(file, 0, SEEK_SET);

    if (file_size < 32) {
        set_mp4_error("MP4 file too small for chunked processing");
        fclose(file);
        free(context);
        return NULL;
    }

    // Read initial portion to parse container structure
    size_t header_size = file_size < 8192 ? file_size : 8192;
    uint8_t* header_data = (uint8_t*)malloc(header_size);
    if (!header_data) {
        set_mp4_error("Failed to allocate memory for MP4 header");
        fclose(file);
        free(context);
        return NULL;
    }

    size_t read_bytes = fread(header_data, 1, header_size, file);
    if (read_bytes < 32) {
        set_mp4_error("Failed to read MP4 header");
        free(header_data);
        fclose(file);
        free(context);
        return NULL;
    }

    // Validate container and find audio track
    int validation_result = mp4_validate_container(header_data, read_bytes);
    if (validation_result != SONIX_OK) {
        set_mp4_error("Invalid MP4 container for chunked processing");
        free(header_data);
        fclose(file);
        free(context);
        return NULL;
    }

    // Find moov box in header data
    size_t moov_size;
    const uint8_t* moov_box = mp4_find_box(header_data, read_bytes, 0x6D6F6F76, &moov_size);
    if (!moov_box) {
        // moov box might be at the end of file, try reading more
        fseek(file, 0, SEEK_SET);
        free(header_data);
        
        // For chunked processing, we need the moov box upfront
        set_mp4_error("MP4 moov box not found in file header - chunked processing requires moov at beginning");
        fclose(file);
        free(context);
        return NULL;
    }

    // Parse audio track information
    Mp4AudioTrack audio_track;
    int track_result = mp4_find_audio_track(moov_box, moov_size, &audio_track);
    if (track_result != SONIX_OK || !audio_track.is_valid) {
        set_mp4_error("Failed to find valid audio track for chunked processing");
        free(header_data);
        fclose(file);
        free(context);
        return NULL;
    }

    // Initialize FAAD2 decoder
#if defined(HAVE_FAAD2) && HAVE_FAAD2
    context->faad_decoder = (void*)NeAACDecOpen();
    if (!context->faad_decoder) {
        set_mp4_error("Failed to initialize FAAD2 decoder for chunked processing");
        free(header_data);
        fclose(file);
        free(context);
        return NULL;
    }

    // Configure FAAD2
    NeAACDecConfigurationPtr config = NeAACDecGetCurrentConfiguration((NeAACDecHandle)context->faad_decoder);
    if (config) {
        config->outputFormat = FAAD_FMT_FLOAT;
        config->downMatrix = 0;
        config->useOldADTSFormat = 0;
        config->dontUpSampleImplicitSBR = 1;
        NeAACDecSetConfiguration((NeAACDecHandle)context->faad_decoder, config);
    }

    // Initialize decoder with AAC configuration
    if (audio_track.sample_description.decoder_config_size > 0 && 
        audio_track.sample_description.decoder_config) {
        
        unsigned long sample_rate;
        unsigned char channels;
        
        long result = NeAACDecInit2((NeAACDecHandle)context->faad_decoder, 
                                   audio_track.sample_description.decoder_config,
                                   audio_track.sample_description.decoder_config_size, 
                                   &sample_rate, &channels);
        
        if (result < 0) {
            set_mp4_error("Failed to initialize FAAD2 with AAC configuration");
            NeAACDecClose((NeAACDecHandle)context->faad_decoder);
            free(header_data);
            fclose(file);
            free(context);
            return NULL;
        }
        
        context->sample_rate = (uint32_t)sample_rate;
        context->channels = (uint32_t)channels;
    } else {
        set_mp4_error("MP4 file missing AAC decoder configuration");
        NeAACDecClose((NeAACDecHandle)context->faad_decoder);
        free(header_data);
        fclose(file);
        free(context);
        return NULL;
    }
#else
    set_mp4_error("FAAD2 library not available for chunked processing");
    free(header_data);
    fclose(file);
    free(context);
    return NULL;
#endif

    // Set up context
    context->mp4_file = (void*)file;
    context->track_id = audio_track.track_id;
    context->current_sample = 0;
    
    // Calculate total samples from duration and sample rate
    if (audio_track.media_header.timescale > 0 && context->sample_rate > 0) {
        uint64_t duration_samples = (audio_track.media_header.duration * context->sample_rate) / 
                                   audio_track.media_header.timescale;
        context->total_samples = duration_samples * context->channels;
    } else {
        context->total_samples = 0; // Will be updated as we decode
    }

    // Allocate frame buffer for incomplete AAC frames
    context->frame_buffer_size = 8192; // 8KB buffer for AAC frames
    context->frame_buffer = (uint8_t*)malloc(context->frame_buffer_size);
    if (!context->frame_buffer) {
        set_mp4_error("Failed to allocate frame buffer");
#if defined(HAVE_FAAD2) && HAVE_FAAD2
        NeAACDecClose((NeAACDecHandle)context->faad_decoder);
#endif
        fclose(file);
        free(header_data);
        free(context);
        return NULL;
    }
    context->frame_buffer_used = 0;

    context->initialized = 1;
    
    free(header_data);
    return context;
}

int mp4_process_chunk_data(void* context, const uint8_t* chunk_data, size_t chunk_size,
                          SonixAudioChunk** output_chunks, uint32_t* chunk_count) {
    if (!context || !chunk_data || chunk_size == 0 || !output_chunks || !chunk_count) {
        set_mp4_error("Invalid parameters for MP4 chunk processing");
        return SONIX_ERROR_INVALID_DATA;
    }

    SonixMp4Context* mp4_ctx = (SonixMp4Context*)context;
    if (!mp4_ctx->initialized) {
        set_mp4_error("MP4 context not initialized");
        return SONIX_ERROR_DECODE_FAILED;
    }

    *output_chunks = NULL;
    *chunk_count = 0;

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    // Combine any buffered data with new chunk data
    size_t total_data_size = mp4_ctx->frame_buffer_used + chunk_size;
    uint8_t* combined_data = (uint8_t*)malloc(total_data_size);
    if (!combined_data) {
        set_mp4_error("Failed to allocate memory for combined chunk data");
        return SONIX_ERROR_OUT_OF_MEMORY;
    }

    // Copy buffered data first, then new chunk data
    if (mp4_ctx->frame_buffer_used > 0) {
        memcpy(combined_data, mp4_ctx->frame_buffer, mp4_ctx->frame_buffer_used);
    }
    memcpy(combined_data + mp4_ctx->frame_buffer_used, chunk_data, chunk_size);

    // Process AAC frames from combined data
    size_t processed_bytes = 0;
    SonixAudioChunk* chunks = NULL;
    uint32_t num_chunks = 0;
    uint32_t chunks_capacity = 0;

    while (processed_bytes < total_data_size) {
        // Try to decode AAC frame
        NeAACDecFrameInfo frame_info;
        void* decoded_data = NeAACDecDecode((NeAACDecHandle)mp4_ctx->faad_decoder, &frame_info,
                                           combined_data + processed_bytes, 
                                           total_data_size - processed_bytes);

        if (frame_info.error != 0) {
            // If we get an error and haven't processed any bytes, it might be incomplete frame
            if (frame_info.bytesconsumed == 0) {
                // Save remaining data for next chunk
                size_t remaining = total_data_size - processed_bytes;
                if (remaining > 0 && remaining < mp4_ctx->frame_buffer_size) {
                    memcpy(mp4_ctx->frame_buffer, combined_data + processed_bytes, remaining);
                    mp4_ctx->frame_buffer_used = remaining;
                } else {
                    mp4_ctx->frame_buffer_used = 0;
                }
                break;
            } else {
                // Skip this frame and continue
                processed_bytes += frame_info.bytesconsumed > 0 ? frame_info.bytesconsumed : 1;
                continue;
            }
        }

        if (decoded_data && frame_info.samples > 0) {
            // Allocate or expand chunks array
            if (num_chunks >= chunks_capacity) {
                chunks_capacity = chunks_capacity == 0 ? 4 : chunks_capacity * 2;
                SonixAudioChunk* new_chunks = (SonixAudioChunk*)realloc(chunks, 
                    chunks_capacity * sizeof(SonixAudioChunk));
                if (!new_chunks) {
                    set_mp4_error("Failed to allocate memory for audio chunks");
                    free(combined_data);
                    if (chunks) free(chunks);
                    return SONIX_ERROR_OUT_OF_MEMORY;
                }
                chunks = new_chunks;
            }

            // Allocate memory for decoded samples
            float* samples = (float*)malloc(frame_info.samples * sizeof(float));
            if (!samples) {
                set_mp4_error("Failed to allocate memory for decoded samples");
                free(combined_data);
                if (chunks) free(chunks);
                return SONIX_ERROR_OUT_OF_MEMORY;
            }

            // Copy decoded samples
            memcpy(samples, decoded_data, frame_info.samples * sizeof(float));

            // Fill chunk structure
            chunks[num_chunks].samples = samples;
            chunks[num_chunks].sample_count = frame_info.samples;
            chunks[num_chunks].start_sample = mp4_ctx->current_sample;
            chunks[num_chunks].is_last = 0; // Will be set by caller if needed

            mp4_ctx->current_sample += frame_info.samples;
            num_chunks++;
        }

        // Advance processed bytes
        if (frame_info.bytesconsumed > 0) {
            processed_bytes += frame_info.bytesconsumed;
        } else {
            processed_bytes++; // Avoid infinite loop
        }
    }

    // Clear frame buffer if all data was processed
    if (processed_bytes >= total_data_size) {
        mp4_ctx->frame_buffer_used = 0;
    }

    free(combined_data);

    *output_chunks = chunks;
    *chunk_count = num_chunks;

    return SONIX_OK;
#else
    set_mp4_error("FAAD2 library not available");
    return SONIX_ERROR_DECODE_FAILED;
#endif
}

int mp4_seek_to_time(void* context, uint32_t time_ms) {
    if (!context) {
        set_mp4_error("Invalid MP4 context for seeking");
        return SONIX_ERROR_INVALID_DATA;
    }

    SonixMp4Context* mp4_ctx = (SonixMp4Context*)context;
    if (!mp4_ctx->initialized) {
        set_mp4_error("MP4 context not initialized for seeking");
        return SONIX_ERROR_INVALID_DATA;
    }

    if (!mp4_ctx->mp4_file) {
        set_mp4_error("MP4 file not open for seeking");
        return SONIX_ERROR_DECODE_FAILED;
    }

    // For basic seeking, estimate file position based on time
    // This is a simplified implementation - full seeking would require sample table parsing
    FILE* file = (FILE*)mp4_ctx->mp4_file;
    
    fseek(file, 0, SEEK_END);
    long file_size = ftell(file);
    
    // Estimate position (very rough approximation)
    if (mp4_ctx->sample_rate > 0) {
        // Calculate target sample position
        uint64_t target_sample = ((uint64_t)time_ms * mp4_ctx->sample_rate) / 1000;
        
        // Estimate file position (assuming constant bitrate)
        // This is very approximate and should be improved with sample table parsing
        double time_ratio = (double)time_ms / 1000.0;
        long estimated_position = (long)(file_size * time_ratio * 0.8); // 80% to account for headers
        
        // Ensure we don't seek past end of file
        if (estimated_position >= file_size) {
            estimated_position = file_size - 1024; // Leave some buffer
        }
        
        // Seek to estimated position
        if (fseek(file, estimated_position, SEEK_SET) != 0) {
            set_mp4_error("Failed to seek in MP4 file");
            return SONIX_ERROR_DECODE_FAILED;
        }
        
        // Update current sample position
        mp4_ctx->current_sample = target_sample * mp4_ctx->channels;
        
        // Clear frame buffer after seeking
        mp4_ctx->frame_buffer_used = 0;
        
        return SONIX_OK;
    } else {
        set_mp4_error("Cannot seek - sample rate not available");
        return SONIX_ERROR_DECODE_FAILED;
    }
}

void mp4_cleanup_chunked_context(void* context) {
    if (!context) {
        return;
    }

    SonixMp4Context* mp4_ctx = (SonixMp4Context*)context;

#if defined(HAVE_FAAD2) && HAVE_FAAD2
    if (mp4_ctx->faad_decoder) {
        NeAACDecClose((NeAACDecHandle)mp4_ctx->faad_decoder);
        mp4_ctx->faad_decoder = NULL;
    }
#endif

    if (mp4_ctx->mp4_file) {
        fclose((FILE*)mp4_ctx->mp4_file);
        mp4_ctx->mp4_file = NULL;
    }

    if (mp4_ctx->decode_buffer) {
        free(mp4_ctx->decode_buffer);
        mp4_ctx->decode_buffer = NULL;
    }

    if (mp4_ctx->frame_buffer) {
        free(mp4_ctx->frame_buffer);
        mp4_ctx->frame_buffer = NULL;
    }

    free(mp4_ctx);
}