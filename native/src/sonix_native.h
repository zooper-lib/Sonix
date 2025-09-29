#ifndef SONIX_NATIVE_H
#define SONIX_NATIVE_H

#include <stdint.h>
#include <stddef.h>

// Export macros for Windows DLL
#ifdef _WIN32
#ifdef SONIX_NATIVE_EXPORTS
#define SONIX_EXPORT __declspec(dllexport)
#else
#define SONIX_EXPORT __declspec(dllimport)
#endif
#else
#define SONIX_EXPORT __attribute__((visibility("default")))
#endif

#ifdef __cplusplus
extern "C"
{
#endif

// Audio format constants
#define SONIX_FORMAT_UNKNOWN 0
#define SONIX_FORMAT_MP3 1
#define SONIX_FORMAT_WAV 2
#define SONIX_FORMAT_FLAC 3
#define SONIX_FORMAT_OGG 4
#define SONIX_FORMAT_OPUS 5
#define SONIX_FORMAT_MP4 6

// Backend type constants
#define SONIX_BACKEND_LEGACY 0
#define SONIX_BACKEND_FFMPEG 1

// Error codes
#define SONIX_OK 0
#define SONIX_ERROR_INVALID_DATA -1
#define SONIX_ERROR_OUT_OF_MEMORY -2
#define SONIX_ERROR_CODEC_NOT_SUPPORTED -3
#define SONIX_ERROR_FFMPEG_NOT_AVAILABLE -4
#define SONIX_ERROR_FFMPEG_INIT_FAILED -5
#define SONIX_ERROR_FFMPEG_DECODE_FAILED -6
#define SONIX_ERROR_INVALID_FORMAT -7
#define SONIX_ERROR_FILE_NOT_FOUND -8
#define SONIX_ERROR_SEEK_FAILED -9

  // Audio data structure
  typedef struct
  {
    float *samples;
    uint32_t sample_count;
    uint32_t sample_rate;
    uint32_t channels;
    uint32_t duration_ms;
  } SonixAudioData;

  // MP3 debug statistics
  typedef struct
  {
    uint32_t total_frames;
    uint32_t valid_frames;
    uint32_t invalid_frames;
    uint32_t total_samples;
    uint32_t sample_rate;
    uint32_t channels;
    uint32_t bitrate;
    uint32_t duration_ms;
  } SonixMp3DebugStats;

  // File chunk structure for chunked processing
  typedef struct
  {
    uint64_t start_byte;
    uint64_t end_byte;
    uint32_t chunk_index;
  } SonixFileChunk;

  // Chunk result structure
  typedef struct
  {
    SonixAudioData *audio_data;
    uint32_t chunk_index;
    uint8_t is_final_chunk;
    uint8_t success;
    char *error_message;
  } SonixChunkResult;

  // Opaque chunked decoder handle
  typedef struct SonixChunkedDecoder SonixChunkedDecoder;

  // Core API functions
  SONIX_EXPORT int32_t sonix_detect_format(const uint8_t *data, size_t size);
  SONIX_EXPORT SonixAudioData *sonix_decode_audio(const uint8_t *data, size_t size, int32_t format);
  SONIX_EXPORT void sonix_free_audio_data(SonixAudioData *audio_data);
  SONIX_EXPORT const char *sonix_get_error_message(void);

  // FFMPEG-specific functions
  SONIX_EXPORT int32_t sonix_get_backend_type(void);
  SONIX_EXPORT int32_t sonix_init_ffmpeg(void);
  SONIX_EXPORT void sonix_cleanup_ffmpeg(void);
  SONIX_EXPORT void sonix_set_ffmpeg_log_level(int32_t level);

  // MP3 debug functions
  SONIX_EXPORT SonixMp3DebugStats *sonix_get_last_mp3_debug_stats(void);

  // Chunked processing functions
  SONIX_EXPORT SonixChunkedDecoder *sonix_init_chunked_decoder(int32_t format, const char *file_path);
  SONIX_EXPORT SonixChunkResult *sonix_process_file_chunk(SonixChunkedDecoder *decoder, SonixFileChunk *file_chunk);
  SONIX_EXPORT int32_t sonix_seek_to_time(SonixChunkedDecoder *decoder, uint32_t time_ms);
  SONIX_EXPORT uint32_t sonix_get_optimal_chunk_size(int32_t format, uint64_t file_size);
  SONIX_EXPORT void sonix_cleanup_chunked_decoder(SonixChunkedDecoder *decoder);
  SONIX_EXPORT void sonix_free_chunk_result(SonixChunkResult *result);

// Debug functions (only available in debug builds)
#ifdef DEBUG
  SONIX_EXPORT void sonix_debug_memory_status(void);
#endif

#ifdef __cplusplus
}
#endif

#endif // SONIX_NATIVE_H