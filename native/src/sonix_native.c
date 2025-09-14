#define SONIX_BUILDING_DLL
#include "sonix_native.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

// Include audio decoder libraries
#define DR_WAV_IMPLEMENTATION
#include "dr_wav/dr_wav.h"

#define DR_FLAC_IMPLEMENTATION
#include "dr_flac/dr_flac.h"

#define MINIMP3_IMPLEMENTATION
#define MINIMP3_FLOAT_OUTPUT
#define MINIMP3_ONLY_MP3
#define MINIMP3_NO_SIMD
#include "minimp3/minimp3.h"

// Note: stb_vorbis integration would require separate compilation to avoid conflicts

// Global error message storage
static char error_message[256] = {0};
// MP3 debug stats storage
static SonixMp3DebugStats last_stats = {0};

// Chunked decoder structure
struct SonixChunkedDecoder {
    int format;
    char* file_path;
    FILE* file_handle;
    uint64_t file_size;
    uint64_t current_position;
    
    // Format-specific decoder state
    union {
        mp3dec_t mp3_decoder;
        drflac* flac_decoder;
        drwav wav_decoder;
    } decoder_state;
    
    // Audio properties (set after first successful decode)
    uint32_t sample_rate;
    uint32_t channels;
    uint64_t total_samples;
    int properties_initialized;
};

// Set error message
static void set_error(const char *msg)
{
    strncpy(error_message, msg, sizeof(error_message) - 1);
    error_message[sizeof(error_message) - 1] = '\0';
}

int sonix_detect_format(const uint8_t *data, size_t size)
{
    if (!data || size < 4)
    {
        set_error("Invalid data or size too small");
        return SONIX_FORMAT_UNKNOWN;
    }

    // Check MP3 signature (ID3 tag or sync frame)
    if (size >= 3 && data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33)
    {
        return SONIX_FORMAT_MP3;
    }
    if (size >= 2)
    {
        uint16_t sync_word = (data[0] << 8) | data[1];
        if ((sync_word & 0xFFE0) == 0xFFE0)
        {
            return SONIX_FORMAT_MP3;
        }
    }

    // Check WAV signature (RIFF + WAVE)
    if (size >= 12 &&
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x41 && data[10] == 0x56 && data[11] == 0x45)
    {
        return SONIX_FORMAT_WAV;
    }

    // Check FLAC signature (fLaC)
    if (size >= 4 &&
        data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43)
    {
        return SONIX_FORMAT_FLAC;
    }

    // Check OGG signature (OggS)
    if (size >= 4 &&
        data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53)
    {
        return SONIX_FORMAT_OGG;
    }

    set_error("Unknown audio format");
    return SONIX_FORMAT_UNKNOWN;
}

// Memory read callback for dr_wav
static size_t drwav_read_proc_memory(void *pUserData, void *pBufferOut, size_t bytesToRead)
{
    struct
    {
        const uint8_t *data;
        size_t size;
        size_t position;
    } *pMemory = (void *)pUserData;

    size_t bytesRemaining = pMemory->size - pMemory->position;
    size_t bytesToCopy = bytesToRead < bytesRemaining ? bytesToRead : bytesRemaining;

    if (bytesToCopy > 0)
    {
        memcpy(pBufferOut, pMemory->data + pMemory->position, bytesToCopy);
        pMemory->position += bytesToCopy;
    }

    return bytesToCopy;
}

// Memory seek callback for dr_wav
static drwav_bool32 drwav_seek_proc_memory(void *pUserData, int offset, drwav_seek_origin origin)
{
    struct
    {
        const uint8_t *data;
        size_t size;
        size_t position;
    } *pMemory = (void *)pUserData;

    size_t newPosition;

    switch (origin)
    {
    case DRWAV_SEEK_SET:
        newPosition = offset;
        break;
    case DRWAV_SEEK_CUR:
        newPosition = pMemory->position + offset;
        break;
    case DRWAV_SEEK_END:
        newPosition = pMemory->size + offset;
        break;
    default:
        return DRWAV_FALSE;
    }

    if (newPosition > pMemory->size)
    {
        return DRWAV_FALSE;
    }

    pMemory->position = newPosition;
    return DRWAV_TRUE;
}

// Memory tell callback for dr_wav
static drwav_bool32 drwav_tell_proc_memory(void *pUserData, drwav_int64 *pCursor)
{
    struct
    {
        const uint8_t *data;
        size_t size;
        size_t position;
    } *pMemory = (void *)pUserData;

    if (pCursor == NULL)
    {
        return DRWAV_FALSE;
    }

    *pCursor = (drwav_int64)pMemory->position;
    return DRWAV_TRUE;
}

static SonixAudioData *decode_wav(const uint8_t *data, size_t size)
{
    // Memory context for dr_wav callbacks
    struct
    {
        const uint8_t *data;
        size_t size;
        size_t position;
    } memory_context = {data, size, 0};

    drwav wav;
    if (!drwav_init(&wav, drwav_read_proc_memory, drwav_seek_proc_memory, drwav_tell_proc_memory, &memory_context, NULL))
    {
        set_error("Failed to initialize WAV decoder");
        return NULL;
    }

    // Validate WAV parameters before allocation
    if (wav.channels == 0 || wav.channels > 8)
    {
        drwav_uninit(&wav);
        set_error("WAV decode failed: invalid channel count");
        return NULL;
    }

    if (wav.sampleRate == 0 || wav.sampleRate > 192000)
    {
        drwav_uninit(&wav);
        set_error("WAV decode failed: invalid sample rate");
        return NULL;
    }

    // Check for invalid or corrupted frame count (common with malformed WAV files)
    if (wav.totalPCMFrameCount == 0 || wav.totalPCMFrameCount > 1000000000ULL)
    {
        drwav_uninit(&wav);
        char error_msg[256];
        snprintf(error_msg, sizeof(error_msg),
                 "WAV decode failed: invalid frame count (%llu)", wav.totalPCMFrameCount);
        set_error(error_msg);
        return NULL;
    }

    // Calculate total sample count (frames * channels)
    drwav_uint64 totalSamples = wav.totalPCMFrameCount * wav.channels;

    // Sanity check for obvious corruption (but allow large legitimate files)
    if (totalSamples == 0)
    {
        drwav_uninit(&wav);
        set_error("WAV decode failed: no audio data found");
        return NULL;
    }

    // Additional sanity check - if totalSamples is suspiciously large, it's likely a callback issue
    if (totalSamples > 1000000000)
    { // More than 1 billion samples (~6 hours at 44.1kHz stereo)
        drwav_uninit(&wav);
        set_error("WAV file appears corrupted (invalid sample count)");
        return NULL;
    }

    // Allocate memory for decoded samples
    float *samples = (float *)malloc(totalSamples * sizeof(float));
    if (!samples)
    {
        drwav_uninit(&wav);
        set_error("Failed to allocate memory for audio samples");
        return NULL;
    }

    // Read all PCM frames as 32-bit float
    drwav_uint64 framesRead = drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, samples);
    if (framesRead != wav.totalPCMFrameCount)
    {
        free(samples);
        drwav_uninit(&wav);
        set_error("Failed to read all PCM frames from WAV file");
        return NULL;
    }

    // Create result structure
    SonixAudioData *result = (SonixAudioData *)malloc(sizeof(SonixAudioData));
    if (!result)
    {
        free(samples);
        drwav_uninit(&wav);
        set_error("Failed to allocate memory for audio data structure");
        return NULL;
    }

    result->samples = samples;
    result->sample_count = (uint32_t)totalSamples;
    result->sample_rate = wav.sampleRate;
    result->channels = wav.channels; // (bug fix) ensure channels is set for WAV results
    result->duration_ms = (uint32_t)(((double)wav.totalPCMFrameCount * 1000.0) / wav.sampleRate);

    drwav_uninit(&wav);
    return result;
}

static SonixAudioData *decode_flac(const uint8_t *data, size_t size)
{
    if (!data || size < 4)
    {
        set_error("Invalid FLAC data: null pointer or too small");
        return NULL;
    }

    // Check FLAC signature before attempting decode
    if (!(data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43))
    {
        set_error("Invalid FLAC signature");
        return NULL;
    }

    // Use the high-level API to decode all samples at once
    unsigned int channels = 0;
    unsigned int sampleRate = 0;
    drflac_uint64 totalPCMFrameCount = 0;

    // This function should not hang if the data is valid FLAC
    float *samples = drflac_open_memory_and_read_pcm_frames_f32(
        data, size, &channels, &sampleRate, &totalPCMFrameCount, NULL);

    if (!samples)
    {
        set_error("FLAC decode failed: drflac_open_memory_and_read_pcm_frames_f32 returned NULL");
        return NULL;
    }

    if (totalPCMFrameCount == 0)
    {
        drflac_free(samples, NULL);
        set_error("FLAC decode failed: zero PCM frames");
        return NULL;
    }

    if (channels == 0 || channels > 8)
    {
        drflac_free(samples, NULL);
        set_error("FLAC decode failed: invalid channel count");
        return NULL;
    }

    if (sampleRate == 0 || sampleRate > 192000)
    {
        drflac_free(samples, NULL);
        set_error("FLAC decode failed: invalid sample rate");
        return NULL;
    }

    // Calculate total sample count (frames * channels)
    drflac_uint64 totalSamples = totalPCMFrameCount * channels;

    // Sanity check for excessive memory usage (limit to ~100MB)
    if (totalSamples > 25000000)
    { // 25M samples * 4 bytes = 100MB
        drflac_free(samples, NULL);
        set_error("FLAC file too large or corrupt metadata");
        return NULL;
    }

    // Create result structure
    SonixAudioData *result = (SonixAudioData *)malloc(sizeof(SonixAudioData));
    if (!result)
    {
        drflac_free(samples, NULL);
        set_error("Failed to allocate memory for FLAC audio data structure");
        return NULL;
    }

    result->samples = samples;
    result->sample_count = (uint32_t)totalSamples;
    result->sample_rate = sampleRate;
    result->channels = channels;
    result->duration_ms = (uint32_t)((totalPCMFrameCount * 1000) / sampleRate);

    return result;
}

// Helper function to skip ID3v2 tags
static size_t skip_id3v2_tag(const uint8_t *data, size_t size)
{
    if (size < 10)
        return 0;

    // Check for ID3v2 header "ID3"
    if (data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33)
    {
        // ID3v2 tag size is stored in bytes 6-9 (synchsafe integer)
        uint32_t tag_size = ((data[6] & 0x7F) << 21) |
                            ((data[7] & 0x7F) << 14) |
                            ((data[8] & 0x7F) << 7) |
                            (data[9] & 0x7F);
        return 10 + tag_size; // Header (10 bytes) + tag data
    }
    return 0;
}

static SonixAudioData *decode_mp3(const uint8_t *data, size_t size)
{
    mp3dec_t mp3d;
    mp3dec_init(&mp3d);

    // Skip ID3v2 tags at the beginning
    size_t offset = skip_id3v2_tag(data, size);
    float *all_samples = NULL;
    size_t total_samples = 0;
    size_t samples_capacity = 0;
    uint32_t sample_rate = 0;
    uint32_t channels = 0;

    // Initial capacity (estimate)
    samples_capacity = size * 10; // Conservative estimate
    all_samples = (float *)malloc(samples_capacity * sizeof(float));
    if (!all_samples)
    {
        set_error("Failed to allocate initial memory for MP3 samples");
        return NULL;
    }

    // Single pass: decode all frames and collect samples
    size_t consecutive_failures = 0;
    size_t frame_count = 0;
    size_t processed_bytes = offset; // start after ID3 skip
    while (offset < size)
    {
        mp3dec_frame_info_t info;
        float pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];

        // Quick sync word check to avoid excessive decode attempts on arbitrary data
        if (size - offset >= 2)
        {
            uint16_t sync = (data[offset] << 8) | data[offset + 1];
            if ((sync & 0xFFE0) != 0xFFE0 && !(data[offset] == 'I' && data[offset + 1] == 'D'))
            {             // not frame sync and not ID3
                offset++; // advance and continue scanning
                continue;
            }
        }

        // mp3dec_decode_frame returns number of samples PER CHANNEL.
        // Our storage is interleaved total samples (channels * per_channel_samples).
        int samples_per_channel = mp3dec_decode_frame(&mp3d, data + offset, size - offset, pcm, &info);
        int frame_samples_total = samples_per_channel * info.channels; // total interleaved samples in this frame

        if (samples_per_channel == 0)
        {
            consecutive_failures++;
            if (info.frame_bytes == 0)
            {
                // Try to skip ahead to find more frames (byte-wise scan)
                offset++;
                if (offset >= size)
                    break; // reached end
                continue;  // do not prematurely abort on many failures; some files have large gaps/non-audio data
            }
            // Skip this frame and continue
            offset += info.frame_bytes;
            continue;
        }

        consecutive_failures = 0; // Reset failure counter on successful decode
        frame_count++;

        // Set audio parameters from first valid frame
        if (sample_rate == 0)
        {
            sample_rate = info.hz;
            channels = info.channels;
        }

        // Ensure we have enough capacity
        if (total_samples + frame_samples_total > samples_capacity)
        {
            samples_capacity = (total_samples + frame_samples_total) * 2; // Double the capacity
            float *new_samples = (float *)realloc(all_samples, samples_capacity * sizeof(float));
            if (!new_samples)
            {
                free(all_samples);
                set_error("Failed to reallocate memory for MP3 samples");
                return NULL;
            }
            all_samples = new_samples;
        }

        // Copy samples to output buffer
        memcpy(all_samples + total_samples, pcm, frame_samples_total * sizeof(float));
        total_samples += frame_samples_total;
        offset += info.frame_bytes;
        processed_bytes = offset;
    }

    if (total_samples == 0 || sample_rate == 0 || channels == 0)
    {
        free(all_samples);
        set_error("Failed to decode MP3: no valid frames found");
        return NULL;
    }

    // Shrink to actual size
    float *final_samples = (float *)realloc(all_samples, total_samples * sizeof(float));
    if (final_samples)
    {
        all_samples = final_samples;
    }

    // Create result structure
    SonixAudioData *result = (SonixAudioData *)malloc(sizeof(SonixAudioData));
    if (!result)
    {
        free(all_samples);
        set_error("Failed to allocate memory for MP3 audio data structure");
        return NULL;
    }

    result->samples = all_samples;
    result->sample_count = (uint32_t)total_samples;
    result->sample_rate = sample_rate;
    result->channels = channels;
    // Duration: sample_count already reflects per-channel samples aggregated across frames? Empirical evidence shows
    // dividing by channels halves real duration, so we omit channel division here.
    // total_samples is interleaved (frames * channels). Real frames = total_samples / channels.
    result->duration_ms = (uint32_t)(((double)total_samples * 1000.0) / (sample_rate * channels));

    // Store debug stats (static so retrievable after decode)
    last_stats.frame_count = (uint32_t)frame_count;
    last_stats.total_samples = (uint32_t)total_samples;
    last_stats.channels = channels;
    last_stats.sample_rate = sample_rate;
    last_stats.processed_bytes = processed_bytes;
    last_stats.file_size = size;

    return result;
}

SonixAudioData *sonix_decode_audio(const uint8_t *data, size_t size, int format)
{
    if (!data || size == 0)
    {
        set_error("Invalid input data");
        return NULL;
    }

    switch (format)
    {
    case SONIX_FORMAT_WAV:
        return decode_wav(data, size);
    case SONIX_FORMAT_MP3:
        return decode_mp3(data, size);
    case SONIX_FORMAT_FLAC:
        return decode_flac(data, size);
    case SONIX_FORMAT_OGG:
        set_error("OGG decoding not yet implemented - stb_vorbis integration needed");
        break;
    case SONIX_FORMAT_OPUS:
        set_error("Opus decoding not yet implemented - libopus integration needed");
        break;
    default:
        set_error("Unsupported audio format");
        break;
    }

    return NULL;
}

void sonix_free_audio_data(SonixAudioData *audio_data)
{
    if (audio_data)
    {
        if (audio_data->samples)
        {
            free(audio_data->samples);
        }
        free(audio_data);
    }
}

const char *sonix_get_error_message(void)
{
    return error_message;
}

// Accessor for MP3 debug stats
const SonixMp3DebugStats *sonix_get_last_mp3_debug_stats(void) { return &last_stats; }

// Chunked processing implementation

SonixChunkedDecoder* sonix_init_chunked_decoder(int format, const char* file_path)
{
    if (!file_path || format < SONIX_FORMAT_MP3 || format > SONIX_FORMAT_OPUS)
    {
        set_error("Invalid format or file path for chunked decoder");
        return NULL;
    }

    // Allocate decoder structure
    SonixChunkedDecoder* decoder = (SonixChunkedDecoder*)malloc(sizeof(SonixChunkedDecoder));
    if (!decoder)
    {
        set_error("Failed to allocate memory for chunked decoder");
        return NULL;
    }

    // Initialize decoder
    memset(decoder, 0, sizeof(SonixChunkedDecoder));
    decoder->format = format;
    
    // Copy file path
    size_t path_len = strlen(file_path);
    decoder->file_path = (char*)malloc(path_len + 1);
    if (!decoder->file_path)
    {
        free(decoder);
        set_error("Failed to allocate memory for file path");
        return NULL;
    }
    strcpy(decoder->file_path, file_path);

    // Open file for reading
    decoder->file_handle = fopen(file_path, "rb");
    if (!decoder->file_handle)
    {
        free(decoder->file_path);
        free(decoder);
        set_error("Failed to open audio file for chunked processing");
        return NULL;
    }

    // Get file size
    fseek(decoder->file_handle, 0, SEEK_END);
    decoder->file_size = ftell(decoder->file_handle);
    fseek(decoder->file_handle, 0, SEEK_SET);
    decoder->current_position = 0;

    // Initialize format-specific decoder
    switch (format)
    {
        case SONIX_FORMAT_MP3:
            mp3dec_init(&decoder->decoder_state.mp3_decoder);
            break;
        case SONIX_FORMAT_FLAC:
            // FLAC decoder will be initialized per chunk
            decoder->decoder_state.flac_decoder = NULL;
            break;
        case SONIX_FORMAT_WAV:
            // WAV decoder will be initialized per chunk
            memset(&decoder->decoder_state.wav_decoder, 0, sizeof(drwav));
            break;
        case SONIX_FORMAT_OGG:
            fclose(decoder->file_handle);
            free(decoder->file_path);
            free(decoder);
            set_error("OGG format requires separate compilation to avoid symbol conflicts");
            return NULL;
        default:
            fclose(decoder->file_handle);
            free(decoder->file_path);
            free(decoder);
            set_error("Unsupported format for chunked processing");
            return NULL;
    }

    return decoder;
}

static SonixChunkResult* process_flac_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk)
{
    if (!decoder || !file_chunk || !file_chunk->data)
    {
        set_error("Invalid parameters for FLAC chunk processing");
        return NULL;
    }

    // Allocate result structure
    SonixChunkResult* result = (SonixChunkResult*)malloc(sizeof(SonixChunkResult));
    if (!result)
    {
        set_error("Failed to allocate memory for FLAC chunk result");
        return NULL;
    }
    memset(result, 0, sizeof(SonixChunkResult));

    // For FLAC, we'll decode the entire chunk as one audio chunk
    // This is a simplified implementation - a more sophisticated version
    // would parse FLAC frames within the chunk
    
    unsigned int channels = 0;
    unsigned int sampleRate = 0;
    drflac_uint64 totalPCMFrameCount = 0;

    // Decode FLAC data from memory
    float* samples = drflac_open_memory_and_read_pcm_frames_f32(
        file_chunk->data, file_chunk->size, &channels, &sampleRate, &totalPCMFrameCount, NULL);

    if (!samples || totalPCMFrameCount == 0)
    {
        free(result);
        set_error("Failed to decode FLAC chunk");
        return NULL;
    }

    // Set decoder properties from first successful decode
    if (!decoder->properties_initialized)
    {
        decoder->sample_rate = sampleRate;
        decoder->channels = channels;
        decoder->properties_initialized = 1;
    }

    // Create single audio chunk
    SonixAudioChunk* audio_chunks = (SonixAudioChunk*)malloc(sizeof(SonixAudioChunk));
    if (!audio_chunks)
    {
        drflac_free(samples, NULL);
        free(result);
        set_error("Failed to allocate memory for FLAC audio chunk");
        return NULL;
    }

    // Fill audio chunk structure
    audio_chunks[0].samples = samples;
    audio_chunks[0].sample_count = (uint32_t)(totalPCMFrameCount * channels);
    audio_chunks[0].start_sample = file_chunk->position; // Approximate
    audio_chunks[0].is_last = file_chunk->is_last;

    // Fill result structure
    result->chunks = audio_chunks;
    result->chunk_count = 1;
    result->error_code = SONIX_OK;
    result->error_message = NULL;

    return result;
}

static SonixChunkResult* process_wav_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk)
{
    if (!decoder || !file_chunk || !file_chunk->data)
    {
        set_error("Invalid parameters for WAV chunk processing");
        return NULL;
    }

    // Allocate result structure
    SonixChunkResult* result = (SonixChunkResult*)malloc(sizeof(SonixChunkResult));
    if (!result)
    {
        set_error("Failed to allocate memory for WAV chunk result");
        return NULL;
    }
    memset(result, 0, sizeof(SonixChunkResult));

    // For WAV, we need to handle the chunk based on whether it contains header or data
    // This is a simplified implementation that assumes the chunk contains raw PCM data
    
    // If this is the first chunk and contains WAV header, parse it
    if (file_chunk->position == 0 && file_chunk->size >= 44)
    {
        // Check for WAV header
        if (file_chunk->data[0] == 'R' && file_chunk->data[1] == 'I' && 
            file_chunk->data[2] == 'F' && file_chunk->data[3] == 'F')
        {
            // Parse WAV header to get format information
            uint32_t sample_rate = *(uint32_t*)(file_chunk->data + 24);
            uint16_t channels = *(uint16_t*)(file_chunk->data + 22);
            uint16_t bits_per_sample = *(uint16_t*)(file_chunk->data + 34);
            
            // Set decoder properties
            if (!decoder->properties_initialized)
            {
                decoder->sample_rate = sample_rate;
                decoder->channels = channels;
                decoder->properties_initialized = 1;
            }
            
            // Find data chunk start (skip header)
            size_t data_start = 44; // Basic WAV header size
            size_t data_size = file_chunk->size - data_start;
            
            if (data_size == 0)
            {
                // No audio data in this chunk
                result->chunks = NULL;
                result->chunk_count = 0;
                result->error_code = SONIX_OK;
                result->error_message = NULL;
                return result;
            }
            
            // Process the audio data portion
            uint32_t bytes_per_sample = bits_per_sample / 8;
            uint32_t samples_in_chunk = (uint32_t)(data_size / (bytes_per_sample * channels));
            
            if (samples_in_chunk == 0)
            {
                result->chunks = NULL;
                result->chunk_count = 0;
                result->error_code = SONIX_OK;
                result->error_message = NULL;
                return result;
            }
            
            // Allocate memory for converted samples
            float* samples = (float*)malloc(samples_in_chunk * channels * sizeof(float));
            if (!samples)
            {
                free(result);
                set_error("Failed to allocate memory for WAV samples");
                return NULL;
            }
            
            // Convert samples to float (simplified - assumes 16-bit PCM)
            if (bits_per_sample == 16)
            {
                int16_t* pcm_data = (int16_t*)(file_chunk->data + data_start);
                for (uint32_t i = 0; i < samples_in_chunk * channels; i++)
                {
                    samples[i] = (float)pcm_data[i] / 32768.0f;
                }
            }
            else
            {
                // Unsupported bit depth for this simplified implementation
                free(samples);
                free(result);
                set_error("Unsupported WAV bit depth for chunked processing");
                return NULL;
            }
            
            // Create audio chunk
            SonixAudioChunk* audio_chunks = (SonixAudioChunk*)malloc(sizeof(SonixAudioChunk));
            if (!audio_chunks)
            {
                free(samples);
                free(result);
                set_error("Failed to allocate memory for WAV audio chunk");
                return NULL;
            }
            
            audio_chunks[0].samples = samples;
            audio_chunks[0].sample_count = samples_in_chunk * channels;
            audio_chunks[0].start_sample = 0;
            audio_chunks[0].is_last = file_chunk->is_last;
            
            result->chunks = audio_chunks;
            result->chunk_count = 1;
            result->error_code = SONIX_OK;
            result->error_message = NULL;
            
            return result;
        }
    }
    
    // For subsequent chunks or chunks without header, assume raw PCM data
    if (decoder->properties_initialized)
    {
        uint32_t bytes_per_sample = 2; // Assume 16-bit for simplicity
        uint32_t samples_in_chunk = (uint32_t)(file_chunk->size / (bytes_per_sample * decoder->channels));
        
        if (samples_in_chunk == 0)
        {
            result->chunks = NULL;
            result->chunk_count = 0;
            result->error_code = SONIX_OK;
            result->error_message = NULL;
            return result;
        }
        
        // Allocate memory for converted samples
        float* samples = (float*)malloc(samples_in_chunk * decoder->channels * sizeof(float));
        if (!samples)
        {
            free(result);
            set_error("Failed to allocate memory for WAV chunk samples");
            return NULL;
        }
        
        // Convert 16-bit PCM to float
        int16_t* pcm_data = (int16_t*)file_chunk->data;
        for (uint32_t i = 0; i < samples_in_chunk * decoder->channels; i++)
        {
            samples[i] = (float)pcm_data[i] / 32768.0f;
        }
        
        // Create audio chunk
        SonixAudioChunk* audio_chunks = (SonixAudioChunk*)malloc(sizeof(SonixAudioChunk));
        if (!audio_chunks)
        {
            free(samples);
            free(result);
            set_error("Failed to allocate memory for WAV audio chunk");
            return NULL;
        }
        
        audio_chunks[0].samples = samples;
        audio_chunks[0].sample_count = samples_in_chunk * decoder->channels;
        audio_chunks[0].start_sample = file_chunk->position / (bytes_per_sample * decoder->channels);
        audio_chunks[0].is_last = file_chunk->is_last;
        
        result->chunks = audio_chunks;
        result->chunk_count = 1;
        result->error_code = SONIX_OK;
        result->error_message = NULL;
        
        return result;
    }
    
    // Cannot process without format information
    free(result);
    set_error("WAV format not initialized for chunk processing");
    return NULL;
}


static SonixChunkResult* process_mp3_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk)
{
    if (!decoder || !file_chunk || !file_chunk->data)
    {
        set_error("Invalid parameters for MP3 chunk processing");
        return NULL;
    }

    // Allocate result structure
    SonixChunkResult* result = (SonixChunkResult*)malloc(sizeof(SonixChunkResult));
    if (!result)
    {
        set_error("Failed to allocate memory for chunk result");
        return NULL;
    }
    memset(result, 0, sizeof(SonixChunkResult));

    // Process MP3 frames in the chunk
    size_t offset = 0;
    size_t chunk_capacity = 10; // Initial capacity for audio chunks
    SonixAudioChunk* audio_chunks = (SonixAudioChunk*)malloc(chunk_capacity * sizeof(SonixAudioChunk));
    if (!audio_chunks)
    {
        free(result);
        set_error("Failed to allocate memory for audio chunks");
        return NULL;
    }

    uint32_t chunk_count = 0;
    uint64_t current_sample_position = 0;

    while (offset < file_chunk->size)
    {
        mp3dec_frame_info_t info;
        float pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];

        // Decode MP3 frame
        int samples_per_channel = mp3dec_decode_frame(
            &decoder->decoder_state.mp3_decoder,
            file_chunk->data + offset,
            file_chunk->size - offset,
            pcm,
            &info
        );

        if (samples_per_channel == 0)
        {
            if (info.frame_bytes == 0)
            {
                offset++;
                continue;
            }
            offset += info.frame_bytes;
            continue;
        }

        // Set decoder properties from first successful frame
        if (!decoder->properties_initialized)
        {
            decoder->sample_rate = info.hz;
            decoder->channels = info.channels;
            decoder->properties_initialized = 1;
        }

        // Expand audio chunks array if needed
        if (chunk_count >= chunk_capacity)
        {
            chunk_capacity *= 2;
            SonixAudioChunk* new_chunks = (SonixAudioChunk*)realloc(audio_chunks, chunk_capacity * sizeof(SonixAudioChunk));
            if (!new_chunks)
            {
                // Cleanup and return error
                for (uint32_t i = 0; i < chunk_count; i++)
                {
                    free(audio_chunks[i].samples);
                }
                free(audio_chunks);
                free(result);
                set_error("Failed to reallocate memory for audio chunks");
                return NULL;
            }
            audio_chunks = new_chunks;
        }

        // Allocate memory for this audio chunk's samples
        int total_samples = samples_per_channel * info.channels;
        float* chunk_samples = (float*)malloc(total_samples * sizeof(float));
        if (!chunk_samples)
        {
            // Cleanup and return error
            for (uint32_t i = 0; i < chunk_count; i++)
            {
                free(audio_chunks[i].samples);
            }
            free(audio_chunks);
            free(result);
            set_error("Failed to allocate memory for chunk samples");
            return NULL;
        }

        // Copy samples to chunk
        memcpy(chunk_samples, pcm, total_samples * sizeof(float));

        // Fill audio chunk structure
        audio_chunks[chunk_count].samples = chunk_samples;
        audio_chunks[chunk_count].sample_count = total_samples;
        audio_chunks[chunk_count].start_sample = current_sample_position;
        audio_chunks[chunk_count].is_last = 0; // Will be set later if needed

        current_sample_position += samples_per_channel; // Per-channel samples
        chunk_count++;
        offset += info.frame_bytes;
    }

    // Mark last chunk if this is the last file chunk
    if (file_chunk->is_last && chunk_count > 0)
    {
        audio_chunks[chunk_count - 1].is_last = 1;
    }

    // Fill result structure
    result->chunks = audio_chunks;
    result->chunk_count = chunk_count;
    result->error_code = SONIX_OK;
    result->error_message = NULL;

    return result;
}

SonixChunkResult* sonix_process_file_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk)
{
    if (!decoder || !file_chunk)
    {
        set_error("Invalid decoder or file chunk");
        return NULL;
    }

    switch (decoder->format)
    {
        case SONIX_FORMAT_MP3:
            return process_mp3_chunk(decoder, file_chunk);
        case SONIX_FORMAT_FLAC:
            return process_flac_chunk(decoder, file_chunk);
        case SONIX_FORMAT_WAV:
            return process_wav_chunk(decoder, file_chunk);
        case SONIX_FORMAT_OGG:
            set_error("OGG format requires separate compilation to avoid symbol conflicts");
            return NULL;
        default:
            set_error("Unsupported format for chunked processing");
            return NULL;
    }
}

int sonix_seek_to_time(SonixChunkedDecoder* decoder, uint32_t time_ms)
{
    if (!decoder || !decoder->file_handle)
    {
        set_error("Invalid decoder for seeking");
        return SONIX_ERROR_INVALID_DATA;
    }

    switch (decoder->format)
    {
        case SONIX_FORMAT_MP3:
            // For MP3, we can only approximate seeking by file position
            // This is a basic implementation - more sophisticated seeking would require
            // building a seek table or using VBR headers
            if (decoder->properties_initialized && decoder->sample_rate > 0)
            {
                // Estimate file position based on time and file size
                double time_ratio = (double)time_ms / 1000.0;
                uint64_t estimated_position = (uint64_t)(time_ratio * decoder->file_size);
                
                // Seek to estimated position
                if (fseek(decoder->file_handle, estimated_position, SEEK_SET) != 0)
                {
                    set_error("Failed to seek in MP3 file");
                    return SONIX_ERROR_DECODE_FAILED;
                }
                
                decoder->current_position = estimated_position;
                return SONIX_OK;
            }
            else
            {
                set_error("Cannot seek in MP3 file - decoder not initialized");
                return SONIX_ERROR_INVALID_DATA;
            }
            
        case SONIX_FORMAT_WAV:
            // WAV files have predictable structure for seeking
            if (decoder->properties_initialized && decoder->sample_rate > 0)
            {
                // Calculate byte position for WAV seeking
                // Assume 16-bit stereo for simplicity
                uint32_t bytes_per_sample = 2 * decoder->channels;
                uint64_t target_sample = ((uint64_t)time_ms * decoder->sample_rate) / 1000;
                uint64_t target_byte = 44 + (target_sample * bytes_per_sample); // 44 = WAV header size
                
                if (fseek(decoder->file_handle, target_byte, SEEK_SET) != 0)
                {
                    set_error("Failed to seek in WAV file");
                    return SONIX_ERROR_DECODE_FAILED;
                }
                
                decoder->current_position = target_byte;
                return SONIX_OK;
            }
            else
            {
                set_error("Cannot seek in WAV file - decoder not initialized");
                return SONIX_ERROR_INVALID_DATA;
            }
            
        case SONIX_FORMAT_FLAC:
            // FLAC seeking is complex and would require seek table parsing
            // For now, implement basic file position estimation
            if (decoder->properties_initialized && decoder->sample_rate > 0)
            {
                double time_ratio = (double)time_ms / 1000.0;
                uint64_t estimated_position = (uint64_t)(time_ratio * decoder->file_size);
                
                if (fseek(decoder->file_handle, estimated_position, SEEK_SET) != 0)
                {
                    set_error("Failed to seek in FLAC file");
                    return SONIX_ERROR_DECODE_FAILED;
                }
                
                decoder->current_position = estimated_position;
                return SONIX_OK;
            }
            else
            {
                set_error("Cannot seek in FLAC file - decoder not initialized");
                return SONIX_ERROR_INVALID_DATA;
            }
            
        case SONIX_FORMAT_OGG:
            set_error("OGG seeking not implemented - requires separate compilation");
            return SONIX_ERROR_DECODE_FAILED;
            
        default:
            set_error("Unsupported format for seeking");
            return SONIX_ERROR_INVALID_FORMAT;
    }
}

uint32_t sonix_get_optimal_chunk_size(int format, uint64_t file_size)
{
    // Default chunk sizes based on format and file size
    uint32_t base_chunk_size;
    
    switch (format)
    {
        case SONIX_FORMAT_MP3:
            // MP3 frames are variable size, use larger chunks for efficiency
            base_chunk_size = 1024 * 1024; // 1MB
            break;
        case SONIX_FORMAT_FLAC:
            // FLAC blocks are larger, can use bigger chunks
            base_chunk_size = 2 * 1024 * 1024; // 2MB
            break;
        case SONIX_FORMAT_WAV:
            // WAV is uncompressed, smaller chunks are fine
            base_chunk_size = 512 * 1024; // 512KB
            break;
        case SONIX_FORMAT_OGG:
            // OGG pages are variable, use medium chunks
            base_chunk_size = 1024 * 1024; // 1MB
            break;
        default:
            base_chunk_size = 1024 * 1024; // 1MB default
            break;
    }
    
    // Adjust based on file size
    if (file_size < 10 * 1024 * 1024) // < 10MB
    {
        return base_chunk_size / 4; // Smaller chunks for small files
    }
    else if (file_size < 100 * 1024 * 1024) // < 100MB
    {
        return base_chunk_size / 2; // Medium chunks
    }
    else
    {
        return base_chunk_size; // Full size for large files
    }
}

void sonix_cleanup_chunked_decoder(SonixChunkedDecoder* decoder)
{
    if (decoder)
    {
        // Cleanup format-specific decoder state
        switch (decoder->format)
        {
            case SONIX_FORMAT_FLAC:
                if (decoder->decoder_state.flac_decoder)
                {
                    drflac_close(decoder->decoder_state.flac_decoder);
                }
                break;
            case SONIX_FORMAT_WAV:
                // WAV decoder cleanup if needed
                drwav_uninit(&decoder->decoder_state.wav_decoder);
                break;
            case SONIX_FORMAT_OGG:
                // OGG cleanup not implemented
                break;
            case SONIX_FORMAT_MP3:
            default:
                // No special cleanup needed for MP3 or unsupported formats
                break;
        }
        
        if (decoder->file_handle)
        {
            fclose(decoder->file_handle);
        }
        if (decoder->file_path)
        {
            free(decoder->file_path);
        }
        free(decoder);
    }
}

void sonix_free_chunk_result(SonixChunkResult* result)
{
    if (result)
    {
        if (result->chunks)
        {
            // Free individual chunk samples
            for (uint32_t i = 0; i < result->chunk_count; i++)
            {
                if (result->chunks[i].samples)
                {
                    free(result->chunks[i].samples);
                }
            }
            free(result->chunks);
        }
        if (result->error_message)
        {
            free(result->error_message);
        }
        free(result);
    }
}
