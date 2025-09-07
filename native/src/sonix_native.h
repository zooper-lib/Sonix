#ifndef SONIX_NATIVE_H
#define SONIX_NATIVE_H

#include <stdint.h>
#include <stddef.h>

// Export macro for Windows DLL
#ifndef SONIX_EXPORT
    #ifdef _WIN32
        #ifdef SONIX_BUILDING_DLL
            #define SONIX_EXPORT __declspec(dllexport)
        #else
            #define SONIX_EXPORT __declspec(dllimport)
        #endif
    #else
        #define SONIX_EXPORT __attribute__((visibility("default")))
    #endif
#endif

#ifdef __cplusplus
extern "C" {
#endif

// Audio format constants
#define SONIX_FORMAT_UNKNOWN 0
#define SONIX_FORMAT_MP3     1
#define SONIX_FORMAT_FLAC    2
#define SONIX_FORMAT_WAV     3
#define SONIX_FORMAT_OGG     4
#define SONIX_FORMAT_OPUS    5

// Error codes
#define SONIX_OK                    0
#define SONIX_ERROR_INVALID_FORMAT -1
#define SONIX_ERROR_DECODE_FAILED  -2
#define SONIX_ERROR_OUT_OF_MEMORY  -3
#define SONIX_ERROR_INVALID_DATA   -4

// Audio data structure
typedef struct {
    float* samples;          // Interleaved audio samples
    uint32_t sample_count;   // Total number of samples (channels * frames)
    uint32_t sample_rate;    // Sample rate in Hz
    uint32_t channels;       // Number of channels
    uint32_t duration_ms;    // Duration in milliseconds
} SonixAudioData;

/**
 * Detect audio format from file data
 * @param data Pointer to file data
 * @param size Size of data in bytes
 * @return Format constant (SONIX_FORMAT_*) or SONIX_FORMAT_UNKNOWN
 */
SONIX_EXPORT int sonix_detect_format(const uint8_t* data, size_t size);

/**
 * Decode audio data from memory
 * @param data Pointer to audio file data
 * @param size Size of data in bytes
 * @param format Audio format (SONIX_FORMAT_*)
 * @return Pointer to SonixAudioData or NULL on error
 */
SONIX_EXPORT SonixAudioData* sonix_decode_audio(const uint8_t* data, size_t size, int format);

/**
 * Free audio data allocated by sonix_decode_audio
 * @param audio_data Pointer to SonixAudioData to free
 */
SONIX_EXPORT void sonix_free_audio_data(SonixAudioData* audio_data);

/**
 * Get error message for the last error
 * @return Pointer to error message string
 */
SONIX_EXPORT const char* sonix_get_error_message(void);

#ifdef __cplusplus
}
#endif

#endif // SONIX_NATIVE_H