#include "sonix_native.h"
#include <libavformat/avformat.h>
#include <libavcodec/avcodec.h>
#include <libavutil/avutil.h>
#include <libavutil/log.h>
#include <libswresample/swresample.h>
#include <libavutil/opt.h>
#include <libavutil/channel_layout.h>
#include <libavutil/samplefmt.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// Global error message buffer
static char g_error_message[512] = {0};
static int g_ffmpeg_initialized = 0;

// Memory management tracking for debugging
#ifdef DEBUG
static int g_active_contexts = 0;
static int g_active_decoders = 0;
#define TRACK_CONTEXT_ALLOC() (g_active_contexts++)
#define TRACK_CONTEXT_FREE() (g_active_contexts--)
#define TRACK_DECODER_ALLOC() (g_active_decoders++)
#define TRACK_DECODER_FREE() (g_active_decoders--)
#else
#define TRACK_CONTEXT_ALLOC()
#define TRACK_CONTEXT_FREE()
#define TRACK_DECODER_ALLOC()
#define TRACK_DECODER_FREE()
#endif

// FFMPEG context structures for chunked processing (implementation)
struct SonixChunkedDecoder
{
    AVFormatContext *format_ctx;
    AVCodecContext *codec_ctx;
    SwrContext *swr_ctx;
    int audio_stream_index;
    int32_t format;
    char *file_path;
    int64_t total_samples;
    int64_t current_sample;
};

// Set error message
static void set_error_message(const char *message)
{
    strncpy(g_error_message, message, sizeof(g_error_message) - 1);
    g_error_message[sizeof(g_error_message) - 1] = '\0';
}

// Clear error message
static void clear_error_message(void)
{
    g_error_message[0] = '\0';
}

// Convert FFMPEG error to string with comprehensive error translation
static void set_ffmpeg_error(int error_code, const char *context)
{
    char av_error[AV_ERROR_MAX_STRING_SIZE];
    av_strerror(error_code, av_error, sizeof(av_error));

    // Translate common FFMPEG errors to user-friendly messages
    const char *user_message = NULL;
    switch (error_code)
    {
    case AVERROR_INVALIDDATA:
        user_message = "Invalid audio data format. File may be corrupted.";
        break;
    case AVERROR(ENOMEM):
        user_message = "Out of memory during audio processing.";
        break;
    case AVERROR_DECODER_NOT_FOUND:
        user_message = "Audio codec not supported by FFMPEG installation.";
        break;
    case AVERROR(ENOENT):
        user_message = "Audio file not found or cannot be accessed.";
        break;
    case AVERROR(EPERM):
        user_message = "Permission denied accessing audio file.";
        break;
    case AVERROR_DEMUXER_NOT_FOUND:
        user_message = "Audio format not supported by FFMPEG installation.";
        break;
    case AVERROR_EOF:
        user_message = "End of file reached during processing.";
        break;
    case AVERROR(EAGAIN):
        user_message = "Resource temporarily unavailable, try again.";
        break;
    default:
        user_message = av_error;
        break;
    }

    snprintf(g_error_message, sizeof(g_error_message), "%s: %s", context, user_message);
}

// Safe memory allocation with error handling
static void *safe_malloc(size_t size, const char *context)
{
    void *ptr = malloc(size);
    if (!ptr)
    {
        snprintf(g_error_message, sizeof(g_error_message), "Memory allocation failed: %s", context);
    }
    return ptr;
}

// Safe string duplication with error handling
static char *safe_strdup(const char *str, const char *context)
{
    if (!str)
    {
        snprintf(g_error_message, sizeof(g_error_message), "Invalid string for duplication: %s", context);
        return NULL;
    }

    size_t len = strlen(str);
    char *dup = (char *)safe_malloc(len + 1, context);
    if (dup)
    {
        strcpy(dup, str);
    }
    return dup;
}

// Initialize FFMPEG - FAIL FAST if not available
int32_t sonix_init_ffmpeg(void)
{
    if (g_ffmpeg_initialized)
    {
        return SONIX_OK;
    }

    clear_error_message();

    // Verify FFMPEG libraries are available by testing core functions
    if (avformat_version() == 0 || avcodec_version() == 0 || avutil_version() == 0 || swresample_version() == 0)
    {
        set_error_message("FFMPEG libraries not found. Please run: dart run tools/download_ffmpeg_binaries.dart");
        return SONIX_ERROR_FFMPEG_NOT_AVAILABLE;
    }

    // Initialize FFMPEG network components
    int ret = avformat_network_init();
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to initialize FFMPEG network components");
        return SONIX_ERROR_FFMPEG_INIT_FAILED;
    }

    // Set FFMPEG log level to suppress verbose codec warnings
    // AV_LOG_ERROR only shows actual errors, filtering out MP3 format detection warnings
    av_log_set_level(AV_LOG_ERROR);

// Log FFMPEG version information for debugging
#ifdef DEBUG
    printf("FFMPEG initialized successfully:\n");
    printf("  libavformat: %u\n", avformat_version());
    printf("  libavcodec: %u\n", avcodec_version());
    printf("  libavutil: %u\n", avutil_version());
    printf("  libswresample: %u\n", swresample_version());
#endif

    g_ffmpeg_initialized = 1;
    return SONIX_OK;
}

// Cleanup FFMPEG with comprehensive resource cleanup
void sonix_cleanup_ffmpeg(void)
{
    if (g_ffmpeg_initialized)
    {
        // Cleanup network components
        avformat_network_deinit();

#ifdef DEBUG
        // Check for resource leaks in debug mode
        if (g_active_contexts > 0)
        {
            printf("WARNING: %d FFMPEG contexts still active during cleanup\n", g_active_contexts);
        }
        if (g_active_decoders > 0)
        {
            printf("WARNING: %d chunked decoders still active during cleanup\n", g_active_decoders);
        }
#endif

        g_ffmpeg_initialized = 0;
        clear_error_message();
    }
}

// Set FFMPEG log level
void sonix_set_ffmpeg_log_level(int32_t level)
{
    // Map common log levels for easier use from Dart
    // -1 = QUIET (no output)
    // 0 = PANIC (only critical errors)
    // 1 = FATAL
    // 2 = ERROR (recommended default)
    // 3 = WARNING
    // 4 = INFO
    // 5 = VERBOSE
    // 6 = DEBUG

    int av_level;
    switch (level)
    {
    case -1:
        av_level = AV_LOG_QUIET;
        break;
    case 0:
        av_level = AV_LOG_PANIC;
        break;
    case 1:
        av_level = AV_LOG_FATAL;
        break;
    case 2:
        av_level = AV_LOG_ERROR;
        break;
    case 3:
        av_level = AV_LOG_WARNING;
        break;
    case 4:
        av_level = AV_LOG_INFO;
        break;
    case 5:
        av_level = AV_LOG_VERBOSE;
        break;
    case 6:
        av_level = AV_LOG_DEBUG;
        break;
    default:
        av_level = AV_LOG_ERROR;
        break; // Default to ERROR level
    }

    av_log_set_level(av_level);
}

// Get backend type - always FFMPEG
int32_t sonix_get_backend_type(void)
{
    return SONIX_BACKEND_FFMPEG;
}

// Get error message
const char *sonix_get_error_message(void)
{
    return g_error_message;
}

// Memory debugging function (only available in debug builds)
#ifdef DEBUG
void sonix_debug_memory_status(void)
{
    printf("FFMPEG Memory Status:\n");
    printf("  Active contexts: %d\n", g_active_contexts);
    printf("  Active decoders: %d\n", g_active_decoders);
    printf("  FFMPEG initialized: %s\n", g_ffmpeg_initialized ? "Yes" : "No");

    if (g_active_contexts > 0 || g_active_decoders > 0)
    {
        printf("  WARNING: Memory leaks detected!\n");
    }
    else
    {
        printf("  Memory status: Clean\n");
    }
}
#endif

// Helper function to detect Opus codec within OGG container
static int32_t detect_opus_in_ogg(const unsigned char *buffer, size_t size, const AVInputFormat *input_format)
{
    AVFormatContext *probe_ctx = avformat_alloc_context();
    if (!probe_ctx)
    {
        return SONIX_FORMAT_OGG; // Fallback to OGG
    }

    // Create buffer for probing with padding
    const size_t buffer_size = size + AV_INPUT_BUFFER_PADDING_SIZE;
    unsigned char *probe_buffer = (unsigned char *)av_malloc(buffer_size);
    if (!probe_buffer)
    {
        avformat_free_context(probe_ctx);
        return SONIX_FORMAT_OGG;
    }

    // Copy data and add padding
    memcpy(probe_buffer, buffer, size);
    memset(probe_buffer + size, 0, AV_INPUT_BUFFER_PADDING_SIZE);

    // Create AVIO context for probing
    AVIOContext *probe_avio = avio_alloc_context(probe_buffer, size, 0, NULL, NULL, NULL, NULL);
    if (!probe_avio)
    {
        av_free(probe_buffer);
        avformat_free_context(probe_ctx);
        return SONIX_FORMAT_OGG;
    }

    probe_ctx->pb = probe_avio;

    // Try to open and analyze the stream
    int32_t detected_format = SONIX_FORMAT_OGG;
    if (avformat_open_input(&probe_ctx, NULL, input_format, NULL) == 0)
    {
        if (avformat_find_stream_info(probe_ctx, NULL) >= 0)
        {
            // Look for Opus codec in audio streams
            for (unsigned int i = 0; i < probe_ctx->nb_streams; i++)
            {
                AVStream *stream = probe_ctx->streams[i];
                if (stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO &&
                    stream->codecpar->codec_id == AV_CODEC_ID_OPUS)
                {
                    detected_format = SONIX_FORMAT_OPUS;
                    break;
                }
            }
        }
        avformat_close_input(&probe_ctx);
    }
    else
    {
        // Manual cleanup if avformat_open_input failed
        avio_context_free(&probe_avio);
        avformat_free_context(probe_ctx);
    }

    return detected_format;
}

// Detect audio format using FFMPEG probe
int32_t sonix_detect_format(const uint8_t *data, size_t size)
{
    if (!data || size == 0)
    {
        set_error_message("Invalid input data for format detection");
        return SONIX_FORMAT_UNKNOWN;
    }

    clear_error_message();

    // Ensure FFMPEG is initialized
    if (sonix_init_ffmpeg() != SONIX_OK)
    {
        return SONIX_FORMAT_UNKNOWN;
    }

    // Create a copy of the data buffer for FFMPEG to manage
    // FFMPEG expects to own the buffer, so we need to allocate it properly
    const size_t buffer_size = size + AV_INPUT_BUFFER_PADDING_SIZE;
    unsigned char *buffer = (unsigned char *)av_malloc(buffer_size);
    if (!buffer)
    {
        set_error_message("Failed to allocate buffer for format detection");
        return SONIX_FORMAT_UNKNOWN;
    }

    // Copy the data and add padding
    memcpy(buffer, data, size);
    memset(buffer + size, 0, AV_INPUT_BUFFER_PADDING_SIZE);

    // Create AVIOContext from memory buffer
    AVIOContext *avio_ctx = avio_alloc_context(
        buffer, size, 0, NULL, NULL, NULL, NULL);

    if (!avio_ctx)
    {
        av_free(buffer);
        set_error_message("Failed to create AVIO context for format detection");
        return SONIX_FORMAT_UNKNOWN;
    }

    // Create format context
    AVFormatContext *fmt_ctx = avformat_alloc_context();
    if (!fmt_ctx)
    {
        avio_context_free(&avio_ctx);
        set_error_message("Failed to allocate format context");
        return SONIX_FORMAT_UNKNOWN;
    }

    fmt_ctx->pb = avio_ctx;

    // Probe the format using a safer approach
    AVProbeData probe_data;
    probe_data.buf = buffer;
    probe_data.buf_size = size;
    probe_data.filename = "";
    probe_data.mime_type = NULL;

    const AVInputFormat *input_format = av_probe_input_format(&probe_data, 1);
    int32_t detected_format = SONIX_FORMAT_UNKNOWN;

    if (input_format)
    {
        const char *format_name = input_format->name;

        if (strstr(format_name, "mp3"))
        {
            detected_format = SONIX_FORMAT_MP3;
        }
        else if (strstr(format_name, "wav"))
        {
            detected_format = SONIX_FORMAT_WAV;
        }
        else if (strstr(format_name, "flac"))
        {
            detected_format = SONIX_FORMAT_FLAC;
        }
        else if (strstr(format_name, "ogg"))
        {
            // For OGG files, probe deeper to check for Opus codec
            detected_format = detect_opus_in_ogg(buffer, size, input_format);
        }
        else if (strstr(format_name, "opus"))
        {
            detected_format = SONIX_FORMAT_OPUS;
        }
        else if (strstr(format_name, "mp4") || strstr(format_name, "m4a"))
        {
            detected_format = SONIX_FORMAT_MP4;
        }
    }

    // Cleanup - the avio_context_free will also free the buffer
    avformat_free_context(fmt_ctx);
    avio_context_free(&avio_ctx);

    return detected_format;
}

// Decode audio data using FFMPEG with robust memory management
SonixAudioData *sonix_decode_audio(const uint8_t *data, size_t size, int32_t format)
{
    if (!data || size == 0)
    {
        set_error_message("Invalid input data for audio decoding");
        return NULL;
    }

    clear_error_message();

    // Ensure FFMPEG is initialized
    if (sonix_init_ffmpeg() != SONIX_OK)
    {
        return NULL;
    }

    // Initialize all pointers to NULL for safe cleanup
    AVFormatContext *fmt_ctx = NULL;
    AVCodecContext *codec_ctx = NULL;
    SwrContext *swr_ctx = NULL;
    AVIOContext *avio_ctx = NULL;
    AVPacket *packet = NULL;
    AVFrame *frame = NULL;
    SonixAudioData *audio_data = NULL;

    TRACK_CONTEXT_ALLOC();

    // Create a copy of the data buffer for FFMPEG to manage
    // FFMPEG expects to own the buffer, so we need to allocate it properly
    const size_t input_buffer_size = size + AV_INPUT_BUFFER_PADDING_SIZE;
    unsigned char *buffer = (unsigned char *)av_malloc(input_buffer_size);
    if (!buffer)
    {
        set_error_message("Failed to allocate buffer for audio decoding");
        goto cleanup;
    }

    // Copy the data and add padding
    memcpy(buffer, data, size);
    memset(buffer + size, 0, AV_INPUT_BUFFER_PADDING_SIZE);

    // Create AVIOContext from memory buffer
    avio_ctx = avio_alloc_context(
        buffer, size, 0, NULL, NULL, NULL, NULL);

    if (!avio_ctx)
    {
        av_free(buffer);
        set_error_message("Failed to create AVIO context");
        goto cleanup;
    }

    // Allocate format context
    fmt_ctx = avformat_alloc_context();
    if (!fmt_ctx)
    {
        set_error_message("Failed to allocate format context");
        goto cleanup;
    }

    fmt_ctx->pb = avio_ctx;

    // Open input
    int ret = avformat_open_input(&fmt_ctx, NULL, NULL, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to open input");
        goto cleanup;
    }

    // Find stream info
    ret = avformat_find_stream_info(fmt_ctx, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to find stream info");
        goto cleanup;
    }

    // Find audio stream
    int audio_stream_index = -1;
    for (unsigned int i = 0; i < fmt_ctx->nb_streams; i++)
    {
        if (fmt_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            audio_stream_index = i;
            break;
        }
    }

    if (audio_stream_index == -1)
    {
        set_error_message("No audio stream found");
        goto cleanup;
    }

    AVStream *audio_stream = fmt_ctx->streams[audio_stream_index];

    // Find decoder
    const AVCodec *codec = avcodec_find_decoder(audio_stream->codecpar->codec_id);
    if (!codec)
    {
        set_error_message("Codec not supported");
        goto cleanup;
    }

    // Allocate codec context
    codec_ctx = avcodec_alloc_context3(codec);
    if (!codec_ctx)
    {
        set_error_message("Failed to allocate codec context");
        goto cleanup;
    }

    // Copy codec parameters
    ret = avcodec_parameters_to_context(codec_ctx, audio_stream->codecpar);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to copy codec parameters");
        goto cleanup;
    }

    // Open codec
    ret = avcodec_open2(codec_ctx, codec, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to open codec");
        goto cleanup;
    }

    uint32_t sample_rate = codec_ctx->sample_rate;
    uint32_t channels = codec_ctx->ch_layout.nb_channels;

    // Use very generous buffer allocation to avoid overflow issues
    size_t estimated_samples;

    // Try to get duration from the stream for better estimation
    int64_t duration = audio_stream->duration;
    if (duration != AV_NOPTS_VALUE && audio_stream->time_base.den > 0)
    {
        // Calculate from stream duration with very generous margins
        double duration_seconds = (double)duration * audio_stream->time_base.num / audio_stream->time_base.den;
        estimated_samples = (size_t)(duration_seconds * sample_rate * channels * 3.0); // 200% safety margin
    }
    else
    {
        // Fallback: use file size with very generous multipliers
        size_t compression_multiplier;
        switch (format)
        {
        case SONIX_FORMAT_WAV:
            compression_multiplier = 2; // Even uncompressed gets extra safety
            break;
        case SONIX_FORMAT_FLAC:
            compression_multiplier = 4;
            break;
        case SONIX_FORMAT_MP3:
            compression_multiplier = 20;
            break;
        case SONIX_FORMAT_OGG:
            compression_multiplier = 25; // Very generous for OGG Vorbis
            break;
        case SONIX_FORMAT_OPUS:
            compression_multiplier = 30; // Very generous for Opus
            break;
        case SONIX_FORMAT_MP4:
            compression_multiplier = 20;
            break;
        default:
            compression_multiplier = 20; // Default generous
            break;
        }

        estimated_samples = size * compression_multiplier;
    }

    // Ensure minimum reasonable size (30 seconds worth)
    const size_t min_samples = sample_rate * channels * 30;
    if (estimated_samples < min_samples)
    {
        estimated_samples = min_samples;
    }

    // Add final safety buffer (minimum 10MB worth of samples)
    const size_t min_buffer_samples = 10 * 1024 * 1024 / sizeof(float);
    if (estimated_samples < min_buffer_samples)
    {
        estimated_samples = min_buffer_samples;
    }

    // Allocate audio data structure
    audio_data = (SonixAudioData *)safe_malloc(sizeof(SonixAudioData), "audio data structure");
    if (!audio_data)
    {
        goto cleanup;
    }

    // Initialize audio data structure
    memset(audio_data, 0, sizeof(SonixAudioData));

    // Allocate sample buffer with generous safety margin
    const size_t buffer_size = estimated_samples * sizeof(float);
    audio_data->samples = (float *)safe_malloc(buffer_size, "sample buffer");
    if (!audio_data->samples)
    {
        free(audio_data);
        audio_data = NULL;
        goto cleanup;
    }

    // Store the buffer capacity for dynamic resizing
    uint64_t max_samples = estimated_samples;

    // Initialize resampler to convert to float
    swr_ctx = swr_alloc();
    if (!swr_ctx)
    {
        set_error_message("Failed to allocate resampler");
        goto cleanup;
    }

    // Set resampler options
    av_opt_set_chlayout(swr_ctx, "in_chlayout", &codec_ctx->ch_layout, 0);
    av_opt_set_int(swr_ctx, "in_sample_rate", codec_ctx->sample_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", codec_ctx->sample_fmt, 0);

    av_opt_set_chlayout(swr_ctx, "out_chlayout", &codec_ctx->ch_layout, 0);
    av_opt_set_int(swr_ctx, "out_sample_rate", codec_ctx->sample_rate, 0);
    av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);

    ret = swr_init(swr_ctx);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to initialize resampler");
        goto cleanup;
    }

    // Allocate packet and frame for decoding
    packet = av_packet_alloc();
    frame = av_frame_alloc();
    uint64_t sample_index = 0;

    if (!packet || !frame)
    {
        set_error_message("Failed to allocate packet or frame");
        goto cleanup;
    }

    while (av_read_frame(fmt_ctx, packet) >= 0)
    {
        if (packet->stream_index == audio_stream_index)
        {
            ret = avcodec_send_packet(codec_ctx, packet);
            if (ret < 0)
            {
                av_packet_unref(packet);
                continue;
            }

            while (ret >= 0)
            {
                ret = avcodec_receive_frame(codec_ctx, frame);
                if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
                {
                    break;
                }
                if (ret < 0)
                {
                    set_ffmpeg_error(ret, "Error during decoding");
                    goto cleanup;
                }

                // Check if we need to expand the buffer dynamically
                uint64_t required_samples = sample_index + (frame->nb_samples * channels);
                if (required_samples > max_samples)
                {
                    // Expand buffer by 50% or required size + safety margin, whichever is larger
                    uint64_t new_max_samples = max_samples + (max_samples / 2);
                    uint64_t required_with_margin = required_samples + (sample_rate * channels); // Add 1 second buffer
                    if (new_max_samples < required_with_margin)
                    {
                        new_max_samples = required_with_margin;
                    }

                    // Reallocate the buffer
                    size_t new_buffer_size = new_max_samples * sizeof(float);
                    float *new_buffer = (float *)realloc(audio_data->samples, new_buffer_size);
                    if (!new_buffer)
                    {
                        set_error_message("Failed to expand sample buffer during decoding");
                        goto cleanup;
                    }

                    audio_data->samples = new_buffer;
                    max_samples = new_max_samples;
                }

                // Convert to float samples
                uint8_t *output_buffer = (uint8_t *)(audio_data->samples + sample_index);
                int converted_samples = swr_convert(swr_ctx, &output_buffer, frame->nb_samples,
                                                    (const uint8_t **)frame->data, frame->nb_samples);

                if (converted_samples < 0)
                {
                    set_ffmpeg_error(converted_samples, "Error during resampling");
                    goto cleanup;
                }

                sample_index += converted_samples * channels;
            }
        }
        av_packet_unref(packet);
    }

    // Flush decoder
    avcodec_send_packet(codec_ctx, NULL);
    while (ret >= 0)
    {
        ret = avcodec_receive_frame(codec_ctx, frame);
        if (ret == AVERROR_EOF)
        {
            break;
        }
        if (ret < 0)
        {
            break;
        }

        uint8_t *output_buffer = (uint8_t *)(audio_data->samples + sample_index);
        int converted_samples = swr_convert(swr_ctx, &output_buffer, frame->nb_samples,
                                            (const uint8_t **)frame->data, frame->nb_samples);

        if (converted_samples > 0)
        {
            sample_index += converted_samples * channels;
        }
    }

    // Set final audio data properties
    if (audio_data)
    {
        audio_data->sample_count = (uint32_t)sample_index;
        audio_data->sample_rate = sample_rate;
        audio_data->channels = channels;
        // Calculate duration from actual samples
        audio_data->duration_ms = (uint32_t)((sample_index * 1000) / (sample_rate * channels));
    }

cleanup:
    // Comprehensive cleanup in reverse order of allocation
    if (packet)
    {
        av_packet_free(&packet);
    }
    if (frame)
    {
        av_frame_free(&frame);
    }
    if (swr_ctx)
    {
        swr_free(&swr_ctx);
    }
    if (codec_ctx)
    {
        avcodec_free_context(&codec_ctx);
    }
    if (fmt_ctx)
    {
        avformat_close_input(&fmt_ctx);
    }
    if (avio_ctx)
    {
        avio_context_free(&avio_ctx);
    }

    TRACK_CONTEXT_FREE();

    // If we failed and allocated audio_data, clean it up
    if (!audio_data || g_error_message[0] != '\0')
    {
        if (audio_data)
        {
            sonix_free_audio_data(audio_data);
            audio_data = NULL;
        }
    }

    return audio_data;
}

// Free audio data with comprehensive cleanup
void sonix_free_audio_data(SonixAudioData *audio_data)
{
    if (!audio_data)
    {
        return;
    }

    if (audio_data->samples)
    {
        free(audio_data->samples);
        audio_data->samples = NULL;
    }

    // Clear fields for safety
    audio_data->sample_count = 0;
    audio_data->sample_rate = 0;
    audio_data->channels = 0;
    audio_data->duration_ms = 0;

    free(audio_data);
}

// MP3 debug stats - not applicable for FFMPEG backend
SonixMp3DebugStats *sonix_get_last_mp3_debug_stats(void)
{
    return NULL;
}

// Initialize chunked decoder with robust memory management
SonixChunkedDecoder *sonix_init_chunked_decoder(int32_t format, const char *file_path)
{
    if (!file_path)
    {
        set_error_message("Invalid file path for chunked decoder");
        return NULL;
    }

    clear_error_message();

    // Ensure FFMPEG is initialized
    if (sonix_init_ffmpeg() != SONIX_OK)
    {
        return NULL;
    }

    SonixChunkedDecoder *decoder = (SonixChunkedDecoder *)safe_malloc(sizeof(SonixChunkedDecoder), "chunked decoder");
    if (!decoder)
    {
        return NULL;
    }

    // Initialize all fields to safe defaults
    memset(decoder, 0, sizeof(SonixChunkedDecoder));
    decoder->format = format;
    decoder->audio_stream_index = -1;
    decoder->total_samples = 0;
    decoder->current_sample = 0;

    TRACK_DECODER_ALLOC();

    // Copy file path safely
    decoder->file_path = safe_strdup(file_path, "file path");
    if (!decoder->file_path)
    {
        free(decoder);
        TRACK_DECODER_FREE();
        return NULL;
    }

    // Open format context
    int ret = avformat_open_input(&decoder->format_ctx, file_path, NULL, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to open input file");
        goto init_cleanup;
    }

    // Find stream info
    ret = avformat_find_stream_info(decoder->format_ctx, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to find stream info");
        goto init_cleanup;
    }

    // Find audio stream
    for (unsigned int i = 0; i < decoder->format_ctx->nb_streams; i++)
    {
        if (decoder->format_ctx->streams[i]->codecpar->codec_type == AVMEDIA_TYPE_AUDIO)
        {
            decoder->audio_stream_index = i;
            break;
        }
    }

    if (decoder->audio_stream_index == -1)
    {
        set_error_message("No audio stream found");
        goto init_cleanup;
    }

    // Initialize codec context
    AVStream *audio_stream = decoder->format_ctx->streams[decoder->audio_stream_index];
    const AVCodec *codec = avcodec_find_decoder(audio_stream->codecpar->codec_id);
    if (!codec)
    {
        set_error_message("Codec not supported");
        goto init_cleanup;
    }

    decoder->codec_ctx = avcodec_alloc_context3(codec);
    if (!decoder->codec_ctx)
    {
        set_error_message("Failed to allocate codec context");
        goto init_cleanup;
    }

    ret = avcodec_parameters_to_context(decoder->codec_ctx, audio_stream->codecpar);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to copy codec parameters");
        goto init_cleanup;
    }

    ret = avcodec_open2(decoder->codec_ctx, codec, NULL);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to open codec");
        goto init_cleanup;
    }

    // Initialize resampler
    decoder->swr_ctx = swr_alloc();
    if (!decoder->swr_ctx)
    {
        set_error_message("Failed to allocate resampler");
        goto init_cleanup;
    }

    av_opt_set_chlayout(decoder->swr_ctx, "in_chlayout", &decoder->codec_ctx->ch_layout, 0);
    av_opt_set_int(decoder->swr_ctx, "in_sample_rate", decoder->codec_ctx->sample_rate, 0);
    av_opt_set_sample_fmt(decoder->swr_ctx, "in_sample_fmt", decoder->codec_ctx->sample_fmt, 0);

    av_opt_set_chlayout(decoder->swr_ctx, "out_chlayout", &decoder->codec_ctx->ch_layout, 0);
    av_opt_set_int(decoder->swr_ctx, "out_sample_rate", decoder->codec_ctx->sample_rate, 0);
    av_opt_set_sample_fmt(decoder->swr_ctx, "out_sample_fmt", AV_SAMPLE_FMT_FLT, 0);

    ret = swr_init(decoder->swr_ctx);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to initialize resampler");
        goto init_cleanup;
    }

    // Calculate total samples for the file
    int64_t duration = audio_stream->duration;
    if (duration != AV_NOPTS_VALUE)
    {
        decoder->total_samples = duration * decoder->codec_ctx->sample_rate *
                                 decoder->codec_ctx->ch_layout.nb_channels /
                                 audio_stream->time_base.den * audio_stream->time_base.num;
    }

    return decoder;

init_cleanup:
    // Cleanup on initialization failure
    if (decoder->swr_ctx)
    {
        swr_free(&decoder->swr_ctx);
    }
    if (decoder->codec_ctx)
    {
        avcodec_free_context(&decoder->codec_ctx);
    }
    if (decoder->format_ctx)
    {
        avformat_close_input(&decoder->format_ctx);
    }
    if (decoder->file_path)
    {
        free(decoder->file_path);
    }
    free(decoder);
    TRACK_DECODER_FREE();
    return NULL;
}

// Process file chunk with real FFMPEG contexts and proper memory management
SonixChunkResult *sonix_process_file_chunk(SonixChunkedDecoder *decoder, SonixFileChunk *file_chunk)
{
    if (!decoder || !file_chunk)
    {
        set_error_message("Invalid decoder or file chunk");
        return NULL;
    }

    clear_error_message();

    SonixChunkResult *result = (SonixChunkResult *)safe_malloc(sizeof(SonixChunkResult), "chunk result");
    if (!result)
    {
        return NULL;
    }

    // Initialize result structure
    memset(result, 0, sizeof(SonixChunkResult));
    result->chunk_index = file_chunk->chunk_index;
    result->success = 0;
    result->is_final_chunk = 0;
    result->audio_data = NULL;
    result->error_message = NULL;

    // Allocate packet and frame for processing
    AVPacket *packet = av_packet_alloc();
    AVFrame *frame = av_frame_alloc();

    if (!packet || !frame)
    {
        set_error_message("Failed to allocate packet or frame for chunk processing");
        goto chunk_cleanup;
    }

    // Estimate samples for this chunk
    const uint32_t estimated_samples_per_chunk = 8192; // Conservative estimate
    const uint32_t channels = decoder->codec_ctx->ch_layout.nb_channels;
    const uint32_t buffer_size = estimated_samples_per_chunk * channels;

    // Allocate audio data for this chunk
    result->audio_data = (SonixAudioData *)safe_malloc(sizeof(SonixAudioData), "chunk audio data");
    if (!result->audio_data)
    {
        goto chunk_cleanup;
    }

    memset(result->audio_data, 0, sizeof(SonixAudioData));
    result->audio_data->samples = (float *)safe_malloc(buffer_size * sizeof(float), "chunk samples");
    if (!result->audio_data->samples)
    {
        goto chunk_cleanup;
    }

    result->audio_data->sample_rate = decoder->codec_ctx->sample_rate;
    result->audio_data->channels = channels;

    // Process packets for this chunk
    uint32_t samples_processed = 0;
    uint32_t packets_processed = 0;
    const uint32_t max_packets_per_chunk = 100; // Limit packets per chunk

    while (packets_processed < max_packets_per_chunk && samples_processed < estimated_samples_per_chunk)
    {
        int ret = av_read_frame(decoder->format_ctx, packet);
        if (ret < 0)
        {
            if (ret == AVERROR_EOF)
            {
                result->is_final_chunk = 1;
                break;
            }
            else
            {
                set_ffmpeg_error(ret, "Error reading frame during chunk processing");
                goto chunk_cleanup;
            }
        }

        if (packet->stream_index != decoder->audio_stream_index)
        {
            av_packet_unref(packet);
            continue;
        }

        packets_processed++;

        // Send packet to decoder
        ret = avcodec_send_packet(decoder->codec_ctx, packet);
        if (ret < 0)
        {
            av_packet_unref(packet);
            continue;
        }

        // Receive frames from decoder
        while (ret >= 0 && samples_processed < estimated_samples_per_chunk)
        {
            ret = avcodec_receive_frame(decoder->codec_ctx, frame);
            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF)
            {
                break;
            }
            if (ret < 0)
            {
                set_ffmpeg_error(ret, "Error receiving frame during chunk processing");
                av_packet_unref(packet);
                goto chunk_cleanup;
            }

            // Check if we have room for more samples
            if (samples_processed + (frame->nb_samples * channels) > buffer_size)
            {
                break; // Chunk is full
            }

            // Convert samples using resampler
            uint8_t *output_buffer = (uint8_t *)(result->audio_data->samples + samples_processed);
            int converted_samples = swr_convert(decoder->swr_ctx, &output_buffer, frame->nb_samples,
                                                (const uint8_t **)frame->data, frame->nb_samples);

            if (converted_samples < 0)
            {
                set_ffmpeg_error(converted_samples, "Error during chunk resampling");
                av_packet_unref(packet);
                goto chunk_cleanup;
            }

            samples_processed += converted_samples * channels;
            decoder->current_sample += converted_samples * channels;
        }

        av_packet_unref(packet);
    }

    // Set final chunk properties
    result->audio_data->sample_count = samples_processed;
    result->audio_data->duration_ms = (samples_processed * 1000) / (result->audio_data->sample_rate * channels);
    result->success = 1;

    // Check if this is the final chunk
    if (decoder->total_samples > 0 && decoder->current_sample >= decoder->total_samples)
    {
        result->is_final_chunk = 1;
    }

chunk_cleanup:
    if (packet)
    {
        av_packet_free(&packet);
    }
    if (frame)
    {
        av_frame_free(&frame);
    }

    // If processing failed, cleanup and set error message
    if (!result->success && g_error_message[0] != '\0')
    {
        if (result->error_message)
        {
            free(result->error_message);
        }
        result->error_message = safe_strdup(g_error_message, "chunk error message");

        if (result->audio_data)
        {
            sonix_free_audio_data(result->audio_data);
            result->audio_data = NULL;
        }
    }

    return result;
}

// Seek to time
int32_t sonix_seek_to_time(SonixChunkedDecoder *decoder, uint32_t time_ms)
{
    if (!decoder)
    {
        set_error_message("Invalid decoder for seek operation");
        return SONIX_ERROR_SEEK_FAILED;
    }

    // Convert time to stream time base
    AVStream *audio_stream = decoder->format_ctx->streams[decoder->audio_stream_index];
    int64_t timestamp = (int64_t)time_ms * audio_stream->time_base.den / (audio_stream->time_base.num * 1000);

    int ret = av_seek_frame(decoder->format_ctx, decoder->audio_stream_index, timestamp, AVSEEK_FLAG_BACKWARD);
    if (ret < 0)
    {
        set_ffmpeg_error(ret, "Failed to seek");
        return SONIX_ERROR_SEEK_FAILED;
    }

    // Flush codec buffers
    avcodec_flush_buffers(decoder->codec_ctx);

    return SONIX_OK;
}

// Get optimal chunk size
uint32_t sonix_get_optimal_chunk_size(int32_t format, uint64_t file_size)
{
    // Return a reasonable default chunk size based on format
    switch (format)
    {
    case SONIX_FORMAT_MP3:
        return (uint32_t)(file_size / 100); // 1% chunks for MP3
    case SONIX_FORMAT_WAV:
        return (uint32_t)(file_size / 50); // 2% chunks for WAV
    case SONIX_FORMAT_FLAC:
        return (uint32_t)(file_size / 80); // 1.25% chunks for FLAC
    case SONIX_FORMAT_OGG:
        return (uint32_t)(file_size / 120); // 0.83% chunks for OGG (smaller due to compression)
    case SONIX_FORMAT_OPUS:
        return (uint32_t)(file_size / 150); // 0.67% chunks for Opus (smaller due to high compression)
    case SONIX_FORMAT_MP4:
        return (uint32_t)(file_size / 100); // 1% chunks for MP4
    default:
        return (uint32_t)(file_size / 100); // Default 1% chunks
    }
}

// Cleanup chunked decoder with comprehensive resource management
void sonix_cleanup_chunked_decoder(SonixChunkedDecoder *decoder)
{
    if (!decoder)
    {
        return;
    }

    // Cleanup in reverse order of initialization
    if (decoder->swr_ctx)
    {
        swr_free(&decoder->swr_ctx);
        decoder->swr_ctx = NULL;
    }

    if (decoder->codec_ctx)
    {
        // Flush any remaining frames before cleanup
        avcodec_send_packet(decoder->codec_ctx, NULL);
        AVFrame *flush_frame = av_frame_alloc();
        if (flush_frame)
        {
            while (avcodec_receive_frame(decoder->codec_ctx, flush_frame) >= 0)
            {
                // Discard flushed frames
            }
            av_frame_free(&flush_frame);
        }

        avcodec_free_context(&decoder->codec_ctx);
        decoder->codec_ctx = NULL;
    }

    if (decoder->format_ctx)
    {
        avformat_close_input(&decoder->format_ctx);
        decoder->format_ctx = NULL;
    }

    if (decoder->file_path)
    {
        free(decoder->file_path);
        decoder->file_path = NULL;
    }

    // Clear other fields for safety
    decoder->audio_stream_index = -1;
    decoder->format = SONIX_FORMAT_UNKNOWN;
    decoder->total_samples = 0;
    decoder->current_sample = 0;

    free(decoder);
    TRACK_DECODER_FREE();
}

// Free chunk result with comprehensive cleanup
void sonix_free_chunk_result(SonixChunkResult *result)
{
    if (!result)
    {
        return;
    }

    if (result->audio_data)
    {
        sonix_free_audio_data(result->audio_data);
        result->audio_data = NULL;
    }

    if (result->error_message)
    {
        free(result->error_message);
        result->error_message = NULL;
    }

    // Clear other fields for safety
    result->chunk_index = 0;
    result->is_final_chunk = 0;
    result->success = 0;

    free(result);
}