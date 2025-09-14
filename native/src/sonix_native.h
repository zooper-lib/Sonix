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

// Chunked processing structures
typedef struct {
    uint8_t* data;           // Chunk data
    size_t size;             // Size of chunk in bytes
    uint64_t position;       // Position in file
    int is_last;             // 1 if this is the last chunk, 0 otherwise
} SonixFileChunk;

typedef struct {
    float* samples;          // Decoded audio samples
    uint32_t sample_count;   // Number of samples in this chunk
    uint64_t start_sample;   // Starting sample position in the full audio
    int is_last;             // 1 if this is the last audio chunk, 0 otherwise
} SonixAudioChunk;

typedef struct {
    SonixAudioChunk* chunks; // Array of audio chunks
    uint32_t chunk_count;    // Number of chunks in array
    int error_code;          // Error code (SONIX_OK if successful)
    char* error_message;     // Error message (NULL if successful)
} SonixChunkResult;

// Chunked decoder handle
typedef struct SonixChunkedDecoder SonixChunkedDecoder;

// Debug statistics for MP3 decoding (development only; not stable API)
typedef struct {
    uint32_t frame_count;      // Number of decoded frames
    uint32_t total_samples;    // Total interleaved samples stored
    uint32_t channels;         // Channels detected
    uint32_t sample_rate;      // Sample rate detected
    uint64_t processed_bytes;  // Bytes advanced through file
    uint64_t file_size;        // Input buffer size
} SonixMp3DebugStats;

// Obtain last MP3 debug stats (NULL if no decode yet or different format)
SONIX_EXPORT const SonixMp3DebugStats* sonix_get_last_mp3_debug_stats(void);

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

// Chunked processing functions

/**
 * Initialize chunked decoder for a specific format
 * @param format Audio format (SONIX_FORMAT_*)
 * @param file_path Path to the audio file (for seeking support)
 * @return Pointer to chunked decoder or NULL on error
 */
SONIX_EXPORT SonixChunkedDecoder* sonix_init_chunked_decoder(int format, const char* file_path);

/**
 * Process a file chunk and return decoded audio chunks
 * @param decoder Pointer to chunked decoder
 * @param file_chunk Pointer to file chunk to process
 * @return Pointer to chunk result or NULL on error
 */
SONIX_EXPORT SonixChunkResult* sonix_process_file_chunk(SonixChunkedDecoder* decoder, SonixFileChunk* file_chunk);

/**
 * Seek to a specific time position in the audio file
 * @param decoder Pointer to chunked decoder
 * @param time_ms Time position in milliseconds
 * @return SONIX_OK on success, error code on failure
 */
SONIX_EXPORT int sonix_seek_to_time(SonixChunkedDecoder* decoder, uint32_t time_ms);

/**
 * Get optimal chunk size for a given format and file size
 * @param format Audio format (SONIX_FORMAT_*)
 * @param file_size Size of the audio file in bytes
 * @return Recommended chunk size in bytes
 */
SONIX_EXPORT uint32_t sonix_get_optimal_chunk_size(int format, uint64_t file_size);

/**
 * Cleanup chunked decoder and free resources
 * @param decoder Pointer to chunked decoder
 */
SONIX_EXPORT void sonix_cleanup_chunked_decoder(SonixChunkedDecoder* decoder);

/**
 * Free chunk result allocated by sonix_process_file_chunk
 * @param result Pointer to chunk result to free
 */
SONIX_EXPORT void sonix_free_chunk_result(SonixChunkResult* result);


#ifdef __cplusplus
}
#endif

#endif // SONIX_NATIVE_H