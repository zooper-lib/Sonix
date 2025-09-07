#define SONIX_BUILDING_DLL
#include "sonix_native.h"
#include <stdlib.h>
#include <string.h>

// Include audio decoder libraries
#define DR_WAV_IMPLEMENTATION
#include "dr_wav/dr_wav.h"

#define MINIMP3_IMPLEMENTATION
#define MINIMP3_FLOAT_OUTPUT
#define MINIMP3_ONLY_MP3
#define MINIMP3_NO_SIMD
#include "minimp3/minimp3.h"

// Global error message storage
static char error_message[256] = {0};
// MP3 debug stats storage
static SonixMp3DebugStats last_stats = {0};

// Set error message
static void set_error(const char* msg) {
    strncpy(error_message, msg, sizeof(error_message) - 1);
    error_message[sizeof(error_message) - 1] = '\0';
}

int sonix_detect_format(const uint8_t* data, size_t size) {
    if (!data || size < 4) {
        set_error("Invalid data or size too small");
        return SONIX_FORMAT_UNKNOWN;
    }

    // Check MP3 signature (ID3 tag or sync frame)
    if (size >= 3 && data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) {
        return SONIX_FORMAT_MP3;
    }
    if (size >= 2) {
        uint16_t sync_word = (data[0] << 8) | data[1];
        if ((sync_word & 0xFFE0) == 0xFFE0) {
            return SONIX_FORMAT_MP3;
        }
    }

    // Check WAV signature (RIFF + WAVE)
    if (size >= 12 && 
        data[0] == 0x52 && data[1] == 0x49 && data[2] == 0x46 && data[3] == 0x46 &&
        data[8] == 0x57 && data[9] == 0x41 && data[10] == 0x56 && data[11] == 0x45) {
        return SONIX_FORMAT_WAV;
    }

    // Check FLAC signature (fLaC)
    if (size >= 4 && 
        data[0] == 0x66 && data[1] == 0x4C && data[2] == 0x61 && data[3] == 0x43) {
        return SONIX_FORMAT_FLAC;
    }

    // Check OGG signature (OggS)
    if (size >= 4 && 
        data[0] == 0x4F && data[1] == 0x67 && data[2] == 0x67 && data[3] == 0x53) {
        return SONIX_FORMAT_OGG;
    }

    set_error("Unknown audio format");
    return SONIX_FORMAT_UNKNOWN;
}

// Memory read callback for dr_wav
static size_t drwav_read_proc_memory(void* pUserData, void* pBufferOut, size_t bytesToRead) {
    struct {
        const uint8_t* data;
        size_t size;
        size_t position;
    }* pMemory = (void*)pUserData;
    
    size_t bytesRemaining = pMemory->size - pMemory->position;
    size_t bytesToCopy = bytesToRead < bytesRemaining ? bytesToRead : bytesRemaining;
    
    if (bytesToCopy > 0) {
        memcpy(pBufferOut, pMemory->data + pMemory->position, bytesToCopy);
        pMemory->position += bytesToCopy;
    }
    
    return bytesToCopy;
}

// Memory seek callback for dr_wav
static drwav_bool32 drwav_seek_proc_memory(void* pUserData, int offset, drwav_seek_origin origin) {
    struct {
        const uint8_t* data;
        size_t size;
        size_t position;
    }* pMemory = (void*)pUserData;
    
    size_t newPosition;
    
    switch (origin) {
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
    
    if (newPosition > pMemory->size) {
        return DRWAV_FALSE;
    }
    
    pMemory->position = newPosition;
    return DRWAV_TRUE;
}

// Memory tell callback for dr_wav
static drwav_uint64 drwav_tell_proc_memory(void* pUserData) {
    struct {
        const uint8_t* data;
        size_t size;
        size_t position;
    }* pMemory = (void*)pUserData;
    
    return pMemory->position;
}

static SonixAudioData* decode_wav(const uint8_t* data, size_t size) {
    // Memory context for dr_wav callbacks
    struct {
        const uint8_t* data;
        size_t size;
        size_t position;
    } memory_context = { data, size, 0 };

    drwav wav;
    if (!drwav_init(&wav, drwav_read_proc_memory, drwav_seek_proc_memory, drwav_tell_proc_memory, &memory_context, NULL)) {
        set_error("Failed to initialize WAV decoder");
        return NULL;
    }
    
    // Allocate memory for decoded samples
    size_t totalSamples = wav.totalPCMFrameCount * wav.channels;
    float* samples = (float*)malloc(totalSamples * sizeof(float));
    if (!samples) {
        drwav_uninit(&wav);
        set_error("Failed to allocate memory for audio samples");
        return NULL;
    }
    
    // Read all PCM frames as 32-bit float
    drwav_uint64 framesRead = drwav_read_pcm_frames_f32(&wav, wav.totalPCMFrameCount, samples);
    if (framesRead != wav.totalPCMFrameCount) {
        free(samples);
        drwav_uninit(&wav);
        set_error("Failed to read all PCM frames from WAV file");
        return NULL;
    }
    
    // Create result structure
    SonixAudioData* result = (SonixAudioData*)malloc(sizeof(SonixAudioData));
    if (!result) {
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

// Helper function to skip ID3v2 tags
static size_t skip_id3v2_tag(const uint8_t* data, size_t size) {
    if (size < 10) return 0;
    
    // Check for ID3v2 header "ID3"
    if (data[0] == 0x49 && data[1] == 0x44 && data[2] == 0x33) {
        // ID3v2 tag size is stored in bytes 6-9 (synchsafe integer)
        uint32_t tag_size = ((data[6] & 0x7F) << 21) |
                           ((data[7] & 0x7F) << 14) |
                           ((data[8] & 0x7F) << 7) |
                           (data[9] & 0x7F);
        return 10 + tag_size; // Header (10 bytes) + tag data
    }
    return 0;
}

static SonixAudioData* decode_mp3(const uint8_t* data, size_t size) {
    mp3dec_t mp3d;
    mp3dec_init(&mp3d);
    
    // Skip ID3v2 tags at the beginning
    size_t offset = skip_id3v2_tag(data, size);
    float* all_samples = NULL;
    size_t total_samples = 0;
    size_t samples_capacity = 0;
    uint32_t sample_rate = 0;
    uint32_t channels = 0;
    
    // Initial capacity (estimate)
    samples_capacity = size * 10; // Conservative estimate
    all_samples = (float*)malloc(samples_capacity * sizeof(float));
    if (!all_samples) {
        set_error("Failed to allocate initial memory for MP3 samples");
        return NULL;
    }
    
    // Single pass: decode all frames and collect samples
    size_t consecutive_failures = 0;
    size_t frame_count = 0;
    size_t processed_bytes = offset; // start after ID3 skip
    while (offset < size) {
        mp3dec_frame_info_t info;
        float pcm[MINIMP3_MAX_SAMPLES_PER_FRAME];

        // Quick sync word check to avoid excessive decode attempts on arbitrary data
        if (size - offset >= 2) {
            uint16_t sync = (data[offset] << 8) | data[offset + 1];
            if ((sync & 0xFFE0) != 0xFFE0 && !(data[offset] == 'I' && data[offset+1] == 'D')) { // not frame sync and not ID3
                offset++; // advance and continue scanning
                continue;
            }
        }

        // mp3dec_decode_frame returns number of samples PER CHANNEL.
        // Our storage is interleaved total samples (channels * per_channel_samples).
        int samples_per_channel = mp3dec_decode_frame(&mp3d, data + offset, size - offset, pcm, &info);
        int frame_samples_total = samples_per_channel * info.channels; // total interleaved samples in this frame

        if (samples_per_channel == 0) {
            consecutive_failures++;
            if (info.frame_bytes == 0) {
                // Try to skip ahead to find more frames (byte-wise scan)
                offset++;
                if (offset >= size) break; // reached end
                continue; // do not prematurely abort on many failures; some files have large gaps/non-audio data
            }
            // Skip this frame and continue
            offset += info.frame_bytes;
            continue;
        }
        
        consecutive_failures = 0; // Reset failure counter on successful decode
        frame_count++;
        
        // Set audio parameters from first valid frame
        if (sample_rate == 0) {
            sample_rate = info.hz;
            channels = info.channels;
        }
        
        // Ensure we have enough capacity
        if (total_samples + frame_samples_total > samples_capacity) {
            samples_capacity = (total_samples + frame_samples_total) * 2; // Double the capacity
            float* new_samples = (float*)realloc(all_samples, samples_capacity * sizeof(float));
            if (!new_samples) {
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
    
    if (total_samples == 0 || sample_rate == 0 || channels == 0) {
        free(all_samples);
        set_error("Failed to decode MP3: no valid frames found");
        return NULL;
    }
    
    // Shrink to actual size
    float* final_samples = (float*)realloc(all_samples, total_samples * sizeof(float));
    if (final_samples) {
        all_samples = final_samples;
    }
    
    // Create result structure
    SonixAudioData* result = (SonixAudioData*)malloc(sizeof(SonixAudioData));
    if (!result) {
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

SonixAudioData* sonix_decode_audio(const uint8_t* data, size_t size, int format) {
    if (!data || size == 0) {
        set_error("Invalid input data");
        return NULL;
    }

    switch (format) {
        case SONIX_FORMAT_WAV:
            return decode_wav(data, size);
        case SONIX_FORMAT_MP3:
            return decode_mp3(data, size);
        case SONIX_FORMAT_FLAC:
            set_error("FLAC decoding not yet implemented - dr_flac integration needed");
            break;
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

void sonix_free_audio_data(SonixAudioData* audio_data) {
    if (audio_data) {
        if (audio_data->samples) {
            free(audio_data->samples);
        }
        free(audio_data);
    }
}

const char* sonix_get_error_message(void) {
    return error_message;
}

// Accessor for MP3 debug stats
const SonixMp3DebugStats* sonix_get_last_mp3_debug_stats(void) { return &last_stats; }

