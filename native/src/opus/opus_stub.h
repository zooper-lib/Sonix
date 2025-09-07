/*
 * Opus codec stub - placeholder for future Opus support
 * For now, Opus decoding will return "not implemented" error
 */

#ifndef OPUS_STUB_H
#define OPUS_STUB_H

#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

#define OPUS_OK                0
#define OPUS_BAD_ARG          -1
#define OPUS_BUFFER_TOO_SMALL -2
#define OPUS_INTERNAL_ERROR   -3
#define OPUS_INVALID_PACKET   -4
#define OPUS_UNIMPLEMENTED    -5
#define OPUS_INVALID_STATE    -6
#define OPUS_ALLOC_FAIL       -7

// Stub implementation - always returns unimplemented
static inline int opus_decode_stub(void) {
    return OPUS_UNIMPLEMENTED;
}

#ifdef __cplusplus
}
#endif

#endif /* OPUS_STUB_H */