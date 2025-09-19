/*
AAC ADTS Decoder Implementation
==============================

Simple AAC Low Complexity (LC) decoder implementation
Public Domain / CC0 - No licensing restrictions

This implements basic AAC-LC decoding with ADTS parsing.
Focus is on simplicity and compatibility, not performance.
*/

#include "aac_decoder.h"
#include <stdlib.h>
#include <string.h>
#include <math.h>

#ifndef M_PI
#define M_PI 3.14159265358979323846
#endif

// Initialize AAC decoder
int aac_decoder_init(AAC_Decoder* decoder) {
    if (!decoder) return 0;
    
    memset(decoder, 0, sizeof(AAC_Decoder));
    
    // Allocate output buffer for stereo at max frame size
    decoder->output_buffer_size = AAC_FRAME_SIZE * AAC_MAX_CHANNELS * sizeof(float);
    decoder->output_buffer = (float*)malloc(decoder->output_buffer_size);
    
    if (!decoder->output_buffer) {
        return 0;
    }
    
    decoder->has_prev_frame = 0;
    return 1;
}

// Free AAC decoder resources
void aac_decoder_free(AAC_Decoder* decoder) {
    if (!decoder) return;
    
    if (decoder->output_buffer) {
        free(decoder->output_buffer);
        decoder->output_buffer = NULL;
    }
    
    memset(decoder, 0, sizeof(AAC_Decoder));
}

// Parse ADTS header
int aac_parse_adts_header(const uint8_t* data, size_t data_size, ADTS_Info* info) {
    if (!data || !info || data_size < 7) return 0;
    
    // Check sync word (12 bits = 0xFFF)
    if (!aac_sync_word_valid(data)) return 0;
    
    // Parse header fields
    info->profile = ((data[2] & 0xC0) >> 6) + 1;  // Profile + 1
    info->sample_rate_index = (data[2] & 0x3C) >> 2;
    info->sample_rate = aac_get_sample_rate(info->sample_rate_index);
    
    // Channel configuration
    int channel_config = ((data[2] & 0x01) << 2) | ((data[3] & 0xC0) >> 6);
    
    // Convert channel config to actual channel count
    switch (channel_config) {
        case 0: info->channels = 0; break;  // Defined in audio specific config
        case 1: info->channels = 1; break;  // Mono
        case 2: info->channels = 2; break;  // Stereo
        case 3: info->channels = 3; break;  // 3 channels
        case 4: info->channels = 4; break;  // 4 channels  
        case 5: info->channels = 5; break;  // 5 channels
        case 6: info->channels = 6; break;  // 5.1
        case 7: info->channels = 8; break;  // 7.1
        default: info->channels = 2; break; // Default to stereo
    }
    
    // Frame length (13 bits)
    info->frame_length = ((data[3] & 0x03) << 11) |
                        (data[4] << 3) |
                        ((data[5] & 0xE0) >> 5);
    
    // Other flags
    info->has_crc = ((data[1] & 0x01) == 0);
    info->copyright = (data[3] & 0x08) != 0;
    info->original = (data[3] & 0x04) != 0;
    info->emphasis = (data[3] & 0x03);
    
    // Validate parsed values
    if (info->sample_rate == 0 || info->channels == 0 || info->frame_length < 7) {
        return 0;
    }
    
    // Only support AAC-LC for now
    if (info->profile != AAC_PROFILE_LC) {
        return 0;
    }
    
    return 1;
}

// Simple MDCT implementation for AAC (simplified)
static void simple_imdct(float* in, float* out, int n) {
    // Simplified inverse MDCT for demonstration
    // Real implementation would need proper MDCT with windowing
    for (int i = 0; i < n; i++) {
        out[i] = 0.0f;
        for (int k = 0; k < n/2; k++) {
            float cos_val = cosf(M_PI * (2*i + 1 + n/2) * (2*k + 1) / (2*n));
            out[i] += in[k] * cos_val;
        }
        out[i] *= 2.0f / n;
    }
}

// Simple AAC spectral processing (very basic)
static void process_spectral_data(AAC_Decoder* decoder, const uint8_t* data, size_t size, int channel) {
    // This is a placeholder implementation
    // Real AAC decoding requires:
    // - Huffman decoding of spectral coefficients
    // - Inverse quantization
    // - TNS (Temporal Noise Shaping) processing
    // - Intensity stereo and M/S stereo processing
    // - Scale factor decoding
    
    // For demo purposes, generate simple tone or silence
    for (int i = 0; i < AAC_FRAME_SIZE / 2; i++) {
        decoder->spectrum[i] = 0.0f;  // Silence for now
    }
}

// Decode AAC frame data (basic implementation)
int aac_decode_frame_data(AAC_Decoder* decoder, const uint8_t* frame_data, size_t frame_size, AAC_Frame* frame) {
    if (!decoder || !frame_data || !frame || frame_size < 2) return 0;
    
    // Very basic frame parsing - real AAC requires complex bitstream parsing
    // This is a minimal implementation for demonstration
    
    // Process each channel
    for (int ch = 0; ch < decoder->channels && ch < AAC_MAX_CHANNELS; ch++) {
        // Process spectral data (placeholder)
        process_spectral_data(decoder, frame_data, frame_size, ch);
        
        // Apply inverse MDCT
        simple_imdct(decoder->spectrum, decoder->window_buffer[ch], AAC_FRAME_SIZE);
        
        // Copy to previous spectrum for next frame overlap
        memcpy(decoder->prev_spectrum[ch], decoder->spectrum, sizeof(float) * AAC_FRAME_SIZE);
    }
    
    // Interleave channels for output
    int samples_per_channel = AAC_FRAME_SIZE;
    float* output = decoder->output_buffer;
    
    for (int i = 0; i < samples_per_channel; i++) {
        for (int ch = 0; ch < decoder->channels; ch++) {
            if (ch < AAC_MAX_CHANNELS) {
                output[i * decoder->channels + ch] = decoder->window_buffer[ch][i];
            } else {
                output[i * decoder->channels + ch] = 0.0f;
            }
        }
    }
    
    // Set frame info
    frame->samples = output;
    frame->num_samples = samples_per_channel;
    frame->channels = decoder->channels;
    frame->sample_rate = decoder->sample_rate;
    frame->valid = 1;
    
    decoder->has_prev_frame = 1;
    return samples_per_channel;
}

// Decode ADTS frame
int aac_decode_adts_frame(AAC_Decoder* decoder, const uint8_t* data, size_t data_size, AAC_Frame* frame) {
    if (!decoder || !data || !frame || data_size < 7) return 0;
    
    ADTS_Info adts_info;
    if (!aac_parse_adts_header(data, data_size, &adts_info)) {
        return 0;
    }
    
    // Check if we have enough data for the complete frame
    if (data_size < adts_info.frame_length) {
        return 0;
    }
    
    // Update decoder configuration if changed
    if (decoder->sample_rate != adts_info.sample_rate ||
        decoder->channels != adts_info.channels ||
        decoder->profile != adts_info.profile) {
        
        decoder->sample_rate = adts_info.sample_rate;
        decoder->channels = adts_info.channels;
        decoder->profile = adts_info.profile;
        decoder->has_prev_frame = 0;  // Reset state on config change
    }
    
    // Skip ADTS header (7 bytes, or 9 if CRC present)
    int header_size = adts_info.has_crc ? 9 : 7;
    const uint8_t* frame_data = data + header_size;
    size_t frame_data_size = adts_info.frame_length - header_size;
    
    // Decode the actual AAC frame
    return aac_decode_frame_data(decoder, frame_data, frame_data_size, frame);
}

// Find next ADTS sync word in buffer
int aac_find_adts_sync(const uint8_t* data, size_t data_size) {
    for (size_t i = 0; i < data_size - 1; i++) {
        if (aac_sync_word_valid(data + i)) {
            return (int)i;
        }
    }
    return -1;
}

// Estimate decoded memory usage for AAC
size_t aac_estimate_decoded_memory(int sample_rate, int channels, int duration_ms) {
    if (sample_rate <= 0 || channels <= 0 || duration_ms <= 0) {
        return 0;
    }
    
    // AAC frame size is always 1024 samples per channel
    int samples_per_second = sample_rate;
    int total_samples = (samples_per_second * duration_ms) / 1000;
    
    return total_samples * channels * sizeof(float);
}