#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>

// FFMPEG includes
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>

// Sonix data structures (matching existing bindings)
typedef struct {
    float* samples;
    uint32_t sample_count;
    uint32_t sample_rate;
    uint32_t channels;
    uint32_t duration_ms;
} SonixAudioData;

typedef struct {
    uint8_t* data;
    size_t size;
    uint64_t position;
    int32_t is_last;
} SonixFileChunk;

typedef struct {
    float* samples;
    uint32_t sample_count;
    uint64_t start_sample;
    int32_t is_last;
} SonixAudioChunk;

typedef struct {
    SonixAudioChunk* chunks;
    uint32_t chunk_count;
    int32_t error_code;
    char* error_message;
} SonixChunkResult;

typedef struct {
    AVFormatContext* format_ctx;
    AVCodecContext* codec_ctx;
    SwrContext* swr_ctx;
    int audio_stream_index;
    AVPacket* packet;
    AVFrame* frame;
    uint8_t* audio_buffer;
    int audio_buffer_size;
    int64_t total_samples;
    int64_t current_sample;
    char* file_path;
} SonixChunkedDecoder;

// Format constants (matching existing bindings)
#define SONIX_FORMAT_UNKNOWN 0
#define SONIX_FORMAT_MP3 1
#define SONIX_FORMAT_FLAC 2
#define SONIX_FORMAT_WAV 3
#define SONIX_FORMAT_OGG 4
#define SONIX_FORMAT_MP4 5

// Error codes (matching existing bindings)
#define SONIX_OK 0
#define SONIX_ERROR_INVALID_FORMAT -1
#define SONIX_ERROR_DECODE_FAILED -2
#define SONIX_ERROR_OUT_OF_MEMORY -3
#define SONIX_ERROR_INVALID_DATA -4

// FFMPEG-specific error codes
#define SONIX_ERROR_FFMPEG_INIT_FAILED -20
#define SONIX_ERROR_FFMPEG_PROBE_FAILED -21
#define SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND -22
#define SONIX_ERROR_FFMPEG_DECODE_FAILED -23

// Forward declarations
void sonix_cleanup_chunked_decoder(SonixChunkedDecoder* decoder);

// Global error message buffer
static char g_error_message[512] = {0};
static int g_ffmpeg_initialized = 0;

// Initialize FFMPEG (called once)
static int init_ffmpeg() {
    if (g_ffmpeg_initialized) {
        return SONIX_OK;
    }
    
    // Set log level to error only
    av_log_set_level(AV_LOG_ERROR);
    
    g_ffmpeg_initialized = 1;
    return SONIX_OK;
}

// Set error message
static void set_error_message(const char* message) {
    strncpy(g_error_message, message, sizeof(g_error_message) - 1);
    g_error_message[sizeof(g_error_message) - 1] = '\0';
}

// Translate FFMPEG error codes to Sonix error codes
static int translate_ffmpeg_error(int ffmpeg_error) {
    switch (ffmpeg_error) {
        case AVERROR_INVALIDDATA:
            return SONIX_ERROR_INVALID_DATA;
        case AVERROR(ENOMEM):
            return SONIX_ERROR_OUT_OF_MEMORY;
        case AVERROR_DECODER_NOT_FOUND:
            return SONIX_ERROR_FFMPEG_CODEC_NOT_FOUND;
        case AVERROR_EOF:
            return SONIX_OK; // End of file is not an error
        default:
            return SONIX_ERROR_FFMPEG_DECODE_FAILED;
    }
}

// Map FFMPEG format to Sonix format constants
static int map_ffmpeg_format_to_sonix(const AVInputFormat* fmt) {
    if (!fmt || !fmt->name) {
        return SONIX_FORMAT_UNKNOWN;
    }
    
    if (strstr(fmt->name, "mp3")) {
        return SONIX_FORMAT_MP3;
    } else if (strstr(fmt->name, "flac")) {
        return SONIX_FORMAT_FLAC;
    } else if (strstr(fmt->name, "wav")) {
        return SONIX_FORMAT_WAV;
    } else if (strstr(fmt->name, "ogg")) {
        return SONIX_FORMAT_OGG;
    } else if (strstr(fmt->name, "mp4") || strstr(fmt->name, "m4a")) {
        return SONIX_FORMAT_MP4;
    }
    
    return SONIX_FORMAT_UNKNOWN;
}

// Format detection using FFMPEG probing
int sonix_detect_format(const uint8_t* data, size_t size) {
    if (init_ffmpeg() != SONIX_OK) {
        set_error_message("Failed to initialize FFMPEG");
        return SONIX_FORMAT_UNKNOWN;
    }
    
    if (!data || size == 0) {
        set_error_message("Invalid input data for format detection");
        return SONIX_FORMAT_UNKNOWN;
    }
    
    AVProbeData probe_data = {0};
    probe_data.buf = (unsigned char*)data;
    probe_data.buf_size = (int)size;
    probe_data.filename = "";
    
    const AVInputFormat* fmt = av_probe_input_format(&probe_data, 1);
    if (!fmt) {
        set_error_message("Could not probe input format");
        return SONIX_FORMAT_UNKNOWN;
    }
    
    return map_ffmpeg_format_to_sonix(fmt);
}

// Audio decoding using FFMPEG
SonixAudioData* sonix_decode_audio(const uint8_t* data, size_t size, int format) {
    if (init_ffmpeg() != SONIX_OK) {
        set_error_message("Failed to initialize FFMPEG");
        return NULL;
    }
    
    if (!data || size == 0) {
        set_error_message("Invalid input data for decoding");
        return NULL;
    }
    
    AVFormatContext* format_ctx = NULL;
    AVCodecContext* codec_ctx = NULL;
    SwrContext* swr_ctx = NULL;
    AVPacket* packet = NULL;
    AVFrame* frame = NULL;
    SonixAudioData* result = NULL;
    
    // Create IO context from memory buffer
    AVIOContext* avio_ctx = avio_alloc_context(
        (unsigned char*)data, (int)size, 0, NULL, NULL, NULL, NULL);
    if (!avio_ctx) {
        set_error_message("Failed to create AVIO context");
        goto cleanup;
    }
    
    // Allocate format context
    format_ctx = avformat_alloc_context();
    if (!format_ctx) {
        set_error_message("Failed to allocate format context");
        goto cleanup;
    }
    format_ctx->pb = avio_ctx;
    
    // Open input
    int ret = avformat_open_input(&format_ctx, NULL, NULL, NULL);
    if (ret < 0) {
        set_error_message("Failed to open input");
        goto cleanup;
    }
    
    // Find stream info
    ret = avformat_find_stream_info(format_ctx, NULL);
    if (ret < 0) {
        set_error_message("Failed to find stream info");
        goto cleanup;
    }
    
    // Find audio stream
    int audio_stream_index = -1;
    for (unsigned int i = 0; i < format_ctx->nb_streams; i++) {
        if (format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            audio_stream_index = i;
            break;
        }
    }
    
    if (audio_stream_index == -1) {
        set_error_message("No audio stream found");
        goto cleanup;
    }
    
    // Get codec parameters
    AVCodecParameters* codecpar = format_ctx->streams[audio_stream_index]->codecpar;
    
    // Find decoder
    const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) {
        set_error_message("Codec not found");
        goto cleanup;
    }
    
    // Allocate codec context
    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx) {
        set_error_message("Failed to allocate codec context");
        goto cleanup;
    }
    
    // Copy codec parameters to context
    ret = avcodec_parameters_to_context(codec_ctx, codecpar);
    if (ret < 0) {
        set_error_message("Failed to copy codec parameters");
        goto cleanup;
    }
    
    // Open codec
    ret = avcodec_open2(codec_ctx, codec, NULL);
    if (ret < 0) {
        set_error_message("Failed to open codec");
        goto cleanup;
    }
    
    // Allocate packet and frame
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    if (!packet || !frame) {
        set_error_message("Failed to allocate packet or frame");
        goto cleanup;
    }
    
    // Setup resampler for float output
    swr_ctx = swr_alloc();
    if (!swr_ctx) {
        set_error_message("Failed to allocate resampler");
        goto cleanup;
    }
    
    // Configure resampler
    av_opt_set_int(swr_ctx, "in_channel_layout", codecpar->channel_layout ? codecpar->channel_layout : av_get_default_channel_layout(codecpar->channels), 0);
    av_opt_set_int(swr_ctx, "in_sample_rate", codecpar->sample_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", codecpar->format, 0);
    
    av_opt_set_int(swr_ctx, "out_channel_layout", codecpar->channel_layout ? codecpar->channel_layout : av_get_default_channel_layout(codecpar->channels), 0);
    av_opt_set_int(swr_ctx, "out_sample_rate", codecpar->sample_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
    
    ret = swr_init(swr_ctx);
    if (ret < 0) {
        set_error_message("Failed to initialize resampler");
        goto cleanup;
    }
    
    // Estimate total samples for allocation
    int64_t duration = format_ctx->duration;
    int sample_rate = codecpar->sample_rate;
    int channels = codecpar->channels;
    
    size_t estimated_samples = 0;
    if (duration != AV_NOPTS_VALUE) {
        estimated_samples = (size_t)((duration * sample_rate * channels) / AV_TIME_BASE);
    } else {
        // Fallback estimation based on file size and bitrate
        estimated_samples = (size * 8 * sample_rate * channels) / (codecpar->bit_rate ? codecpar->bit_rate : 128000);
    }
    
    // Allocate output buffer (with some extra space)
    size_t buffer_size = estimated_samples + (sample_rate * channels); // Extra 1 second
    float* output_buffer = (float*)malloc(buffer_size * sizeof(float));
    if (!output_buffer) {
        set_error_message("Failed to allocate output buffer");
        goto cleanup;
    }
    
    size_t total_output_samples = 0;
    
    // Decode loop
    while (av_read_frame(format_ctx, packet) >= 0) {
        if (packet->stream_index == audio_stream_index) {
            ret = avcodec_send_packet(codec_ctx, packet);
            if (ret < 0) {
                av_packet_unref(packet);
                continue;
            }
            
            while (ret >= 0) {
                ret = avcodec_receive_frame(codec_ctx, frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    break;
                }
                if (ret < 0) {
                    break;
                }
                
                // Resample to float
                int out_samples = swr_convert(swr_ctx,
                    (uint8_t**)&output_buffer[total_output_samples], 
                    (int)(buffer_size - total_output_samples),
                    (const uint8_t**)frame->data, 
                    frame->nb_samples);
                
                if (out_samples < 0) {
                    set_error_message("Failed to resample audio");
                    free(output_buffer);
                    goto cleanup;
                }
                
                total_output_samples += out_samples * channels;
                
                // Check buffer overflow
                if (total_output_samples >= buffer_size) {
                    // Reallocate buffer
                    buffer_size *= 2;
                    float* new_buffer = (float*)realloc(output_buffer, buffer_size * sizeof(float));
                    if (!new_buffer) {
                        set_error_message("Failed to reallocate output buffer");
                        free(output_buffer);
                        goto cleanup;
                    }
                    output_buffer = new_buffer;
                }
            }
        }
        av_packet_unref(packet);
    }
    
    // Flush decoder
    avcodec_send_packet(codec_ctx, NULL);
    while (avcodec_receive_frame(codec_ctx, frame) >= 0) {
        int out_samples = swr_convert(swr_ctx,
            (uint8_t**)&output_buffer[total_output_samples], 
            (int)(buffer_size - total_output_samples),
            (const uint8_t**)frame->data, 
            frame->nb_samples);
        
        if (out_samples > 0) {
            total_output_samples += out_samples * channels;
        }
    }
    
    // Create result structure
    result = (SonixAudioData*)malloc(sizeof(SonixAudioData));
    if (!result) {
        set_error_message("Failed to allocate result structure");
        free(output_buffer);
        goto cleanup;
    }
    
    result->samples = output_buffer;
    result->sample_count = (uint32_t)total_output_samples;
    result->sample_rate = (uint32_t)sample_rate;
    result->channels = (uint32_t)channels;
    result->duration_ms = (uint32_t)((total_output_samples * 1000) / (sample_rate * channels));
    
cleanup:
    if (swr_ctx) swr_free(&swr_ctx);
    if (frame) av_frame_free(&frame);
    if (packet) av_packet_free(&packet);
    if (codec_ctx) avcodec_free_context(&codec_ctx);
    if (format_ctx) avformat_close_input(&format_ctx);
    if (avio_ctx) {
        av_freep(&avio_ctx->buffer);
        av_freep(&avio_ctx);
    }
    
    return result;
}

// Free audio data allocated by decode_audio
void sonix_free_audio_data(SonixAudioData* audio_data) {
    if (audio_data) {
        if (audio_data->samples) {
            free(audio_data->samples);
        }
        free(audio_data);
    }
}

// Get error message for the last error
char* sonix_get_error_message() {
    return g_error_message;
}

// Chunked processing functions

// Initialize chunked decoder for a specific format
SonixChunkedDecoder* sonix_init_chunked_decoder(int format, const char* file_path) {
    if (init_ffmpeg() != SONIX_OK) {
        set_error_message("Failed to initialize FFMPEG");
        return NULL;
    }
    
    if (!file_path) {
        set_error_message("Invalid file path");
        return NULL;
    }
    
    SonixChunkedDecoder* decoder = (SonixChunkedDecoder*)calloc(1, sizeof(SonixChunkedDecoder));
    if (!decoder) {
        set_error_message("Failed to allocate chunked decoder");
        return NULL;
    }
    
    // Store file path
    size_t path_len = strlen(file_path);
    decoder->file_path = (char*)malloc(path_len + 1);
    if (!decoder->file_path) {
        set_error_message("Failed to allocate file path");
        free(decoder);
        return NULL;
    }
    strcpy(decoder->file_path, file_path);
    
    // Open input file
    int ret = avformat_open_input(&decoder->format_ctx, file_path, NULL, NULL);
    if (ret < 0) {
        set_error_message("Failed to open input file");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Find stream info
    ret = avformat_find_stream_info(decoder->format_ctx, NULL);
    if (ret < 0) {
        set_error_message("Failed to find stream info");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Find audio stream
    decoder->audio_stream_index = -1;
    for (unsigned int i = 0; i < decoder->format_ctx->nb_streams; i++) {
        if (decoder->format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            decoder->audio_stream_index = i;
            break;
        }
    }
    
    if (decoder->audio_stream_index == -1) {
        set_error_message("No audio stream found");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Get codec parameters
    AVCodecParameters* codecpar = decoder->format_ctx->streams[decoder->audio_stream_index]->codecpar;
    
    // Find decoder
    const AVCodec* codec = avcodec_find_decoder(codecpar->codec_id);
    if (!codec) {
        set_error_message("Codec not found");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Allocate codec context
    decoder->codec_ctx = avcodec_alloc_context3(codec);
    if (!decoder->codec_ctx) {
        set_error_message("Failed to allocate codec context");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Copy codec parameters to context
    ret = avcodec_parameters_to_context(decoder->codec_ctx, codecpar);
    if (ret < 0) {
        set_error_message("Failed to copy codec parameters");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Open codec
    ret = avcodec_open2(decoder->codec_ctx, codec, NULL);
    if (ret < 0) {
        set_error_message("Failed to open codec");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Setup resampler for float output
    decoder->swr_ctx = swr_alloc();
    if (!decoder->swr_ctx) {
        set_error_message("Failed to allocate resampler");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Configure resampler
    av_opt_set_int(decoder->swr_ctx, "in_channel_layout", 
        codecpar->channel_layout ? codecpar->channel_layout : av_get_default_channel_layout(codecpar->channels), 0);
    av_opt_set_int(decoder->swr_ctx, "in_sample_rate", codecpar->sample_rate, 0);
    av_opt_set_sample_fmt(decoder->swr_ctx, "in_sample_fmt", codecpar->format, 0);
    
    av_opt_set_int(decoder->swr_ctx, "out_channel_layout", 
        codecpar->channel_layout ? codecpar->channel_layout : av_get_default_channel_layout(codecpar->channels), 0);
    av_opt_set_int(decoder->swr_ctx, "out_sample_rate", codecpar->sample_rate, 0);
    av_opt_set_sample_fmt(decoder->swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);
    
    ret = swr_init(decoder->swr_ctx);
    if (ret < 0) {
        set_error_message("Failed to initialize resampler");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Allocate packet and frame
    decoder->packet = av_packet_alloc();
    decoder->frame = av_frame_alloc();
    if (!decoder->packet || !decoder->frame) {
        set_error_message("Failed to allocate packet or frame");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    // Calculate total samples for progress tracking
    int64_t duration = decoder->format_ctx->duration;
    if (duration != AV_NOPTS_VALUE) {
        decoder->total_samples = (duration * codecpar->sample_rate) / AV_TIME_BASE;
    } else {
        decoder->total_samples = 0; // Unknown duration
    }
    
    decoder->current_sample = 0;
    
    // Allocate audio buffer for chunk processing
    decoder->audio_buffer_size = codecpar->sample_rate * codecpar->channels * sizeof(float); // 1 second buffer
    decoder->audio_buffer = (uint8_t*)malloc(decoder->audio_buffer_size);
    if (!decoder->audio_buffer) {
        set_error_message("Failed to allocate audio buffer");
        sonix_cleanup_chunked_decoder(decoder);
        return NULL;
    }
    
    return decoder;
}

// Process a file chunk and return decoded audio chunks
SonixChunkResult* sonix_process_file_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk) {
    if (!decoder || !file_chunk) {
        set_error_message("Invalid decoder or file chunk");
        return NULL;
    }
    
    SonixChunkResult* result = (SonixChunkResult*)calloc(1, sizeof(SonixChunkResult));
    if (!result) {
        set_error_message("Failed to allocate chunk result");
        return NULL;
    }
    
    // For file-based chunked processing, we read packets sequentially
    // The file_chunk parameter is used for progress tracking
    
    // Allocate temporary buffer for decoded samples
    size_t temp_buffer_size = decoder->codec_ctx->sample_rate * decoder->codec_ctx->channels * sizeof(float);
    float* temp_buffer = (float*)malloc(temp_buffer_size);
    if (!temp_buffer) {
        set_error_message("Failed to allocate temporary buffer");
        result->error_code = SONIX_ERROR_OUT_OF_MEMORY;
        return result;
    }
    
    size_t total_samples = 0;
    int packets_processed = 0;
    const int max_packets_per_chunk = 10; // Process up to 10 packets per chunk
    
    // Process packets
    while (packets_processed < max_packets_per_chunk && av_read_frame(decoder->format_ctx, decoder->packet) >= 0) {
        if (decoder->packet->stream_index == decoder->audio_stream_index) {
            packets_processed++;
            
            int ret = avcodec_send_packet(decoder->codec_ctx, decoder->packet);
            if (ret < 0) {
                av_packet_unref(decoder->packet);
                continue;
            }
            
            while (ret >= 0) {
                ret = avcodec_receive_frame(decoder->codec_ctx, decoder->frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                    break;
                }
                if (ret < 0) {
                    break;
                }
                
                // Check if we have enough space in temp buffer
                size_t needed_samples = decoder->frame->nb_samples * decoder->codec_ctx->channels;
                if ((total_samples + needed_samples) * sizeof(float) > temp_buffer_size) {
                    // Reallocate buffer
                    temp_buffer_size *= 2;
                    float* new_buffer = (float*)realloc(temp_buffer, temp_buffer_size);
                    if (!new_buffer) {
                        set_error_message("Failed to reallocate temporary buffer");
                        free(temp_buffer);
                        result->error_code = SONIX_ERROR_OUT_OF_MEMORY;
                        return result;
                    }
                    temp_buffer = new_buffer;
                }
                
                // Resample to float
                int out_samples = swr_convert(decoder->swr_ctx,
                    (uint8_t**)&temp_buffer[total_samples], 
                    (int)((temp_buffer_size - total_samples * sizeof(float)) / sizeof(float)),
                    (const uint8_t**)decoder->frame->data, 
                    decoder->frame->nb_samples);
                
                if (out_samples < 0) {
                    set_error_message("Failed to resample audio");
                    free(temp_buffer);
                    result->error_code = SONIX_ERROR_FFMPEG_DECODE_FAILED;
                    return result;
                }
                
                total_samples += out_samples * decoder->codec_ctx->channels;
                decoder->current_sample += out_samples;
            }
        }
        av_packet_unref(decoder->packet);
    }
    
    // Check if we've reached the end of file
    int is_last = (packets_processed == 0 || av_read_frame(decoder->format_ctx, decoder->packet) < 0);
    if (!is_last) {
        // Put the packet back (seek back one packet)
        av_seek_frame(decoder->format_ctx, decoder->audio_stream_index, 
            decoder->packet->pts, AVSEEK_FLAG_BACKWARD);
    }
    av_packet_unref(decoder->packet);
    
    // Create result chunk
    if (total_samples > 0) {
        result->chunks = (SonixAudioChunk*)malloc(sizeof(SonixAudioChunk));
        if (!result->chunks) {
            set_error_message("Failed to allocate result chunks");
            free(temp_buffer);
            result->error_code = SONIX_ERROR_OUT_OF_MEMORY;
            return result;
        }
        
        result->chunks[0].samples = temp_buffer;
        result->chunks[0].sample_count = (uint32_t)total_samples;
        result->chunks[0].start_sample = (uint64_t)(decoder->current_sample - total_samples / decoder->codec_ctx->channels);
        result->chunks[0].is_last = is_last;
        result->chunk_count = 1;
    } else {
        free(temp_buffer);
        result->chunk_count = 0;
    }
    
    result->error_code = SONIX_OK;
    return result;
}

// Seek to a specific time position in the audio file
int sonix_seek_to_time(SonixChunkedDecoder* decoder, uint32_t time_ms) {
    if (!decoder || !decoder->format_ctx) {
        set_error_message("Invalid decoder");
        return SONIX_ERROR_INVALID_DATA;
    }
    
    // Convert time to timestamp
    int64_t timestamp = (int64_t)time_ms * AV_TIME_BASE / 1000;
    
    // Seek in the format context
    int ret = av_seek_frame(decoder->format_ctx, -1, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0) {
        set_error_message("Failed to seek to time position");
        return translate_ffmpeg_error(ret);
    }
    
    // Flush codec buffers
    avcodec_flush_buffers(decoder->codec_ctx);
    
    // Update current sample position
    if (decoder->total_samples > 0) {
        decoder->current_sample = (decoder->total_samples * time_ms) / 
            ((decoder->format_ctx->duration / AV_TIME_BASE) * 1000);
    }
    
    return SONIX_OK;
}

// Get optimal chunk size for a given format and file size
uint32_t sonix_get_optimal_chunk_size(int format, uint64_t file_size) {
    // Base chunk size on format and file size
    uint32_t base_size;
    
    switch (format) {
        case SONIX_FORMAT_MP3:
            base_size = 64 * 1024; // 64KB for MP3
            break;
        case SONIX_FORMAT_FLAC:
            base_size = 128 * 1024; // 128KB for FLAC
            break;
        case SONIX_FORMAT_WAV:
            base_size = 256 * 1024; // 256KB for WAV
            break;
        case SONIX_FORMAT_OGG:
            base_size = 64 * 1024; // 64KB for OGG
            break;
        case SONIX_FORMAT_MP4:
            base_size = 128 * 1024; // 128KB for MP4
            break;
        default:
            base_size = 64 * 1024; // Default 64KB
            break;
    }
    
    // Scale based on file size
    if (file_size < 1024 * 1024) { // < 1MB
        return base_size / 2;
    } else if (file_size < 10 * 1024 * 1024) { // < 10MB
        return base_size;
    } else if (file_size < 100 * 1024 * 1024) { // < 100MB
        return base_size * 2;
    } else { // >= 100MB
        return base_size * 4;
    }
}

// Cleanup chunked decoder and free resources
void sonix_cleanup_chunked_decoder(SonixChunkedDecoder* decoder) {
    if (!decoder) return;
    
    if (decoder->swr_ctx) {
        swr_free(&decoder->swr_ctx);
    }
    
    if (decoder->frame) {
        av_frame_free(&decoder->frame);
    }
    
    if (decoder->packet) {
        av_packet_free(&decoder->packet);
    }
    
    if (decoder->codec_ctx) {
        avcodec_free_context(&decoder->codec_ctx);
    }
    
    if (decoder->format_ctx) {
        avformat_close_input(&decoder->format_ctx);
    }
    
    if (decoder->audio_buffer) {
        free(decoder->audio_buffer);
    }
    
    if (decoder->file_path) {
        free(decoder->file_path);
    }
    
    free(decoder);
}

// Free chunk result allocated by processFileChunk
void sonix_free_chunk_result(SonixChunkResult* result) {
    if (!result) return;
    
    if (result->chunks) {
        for (uint32_t i = 0; i < result->chunk_count; i++) {
            if (result->chunks[i].samples) {
                free(result->chunks[i].samples);
            }
        }
        free(result->chunks);
    }
    
    if (result->error_message) {
        free(result->error_message);
    }
    
    free(result);
}