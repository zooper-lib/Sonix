#include "mp4_container.h"
#include "sonix_native.h"
#include <stdio.h>
#include <string.h>
#include <assert.h>

// Test data - minimal valid MP4 ftyp box
static const uint8_t test_ftyp_box[] = {
    0x00, 0x00, 0x00, 0x20,  // Box size (32 bytes)
    0x66, 0x74, 0x79, 0x70,  // Box type 'ftyp'
    0x69, 0x73, 0x6F, 0x6D,  // Major brand 'isom'
    0x00, 0x00, 0x02, 0x00,  // Minor version
    0x69, 0x73, 0x6F, 0x6D,  // Compatible brand 'isom'
    0x69, 0x73, 0x6F, 0x32,  // Compatible brand 'iso2'
    0x6D, 0x70, 0x34, 0x31,  // Compatible brand 'mp41'
    0x6D, 0x70, 0x34, 0x32   // Compatible brand 'mp42'
};

// Test data - invalid ftyp box (wrong type)
static const uint8_t test_invalid_ftyp[] = {
    0x00, 0x00, 0x00, 0x20,  // Box size (32 bytes)
    0x6D, 0x6F, 0x6F, 0x76,  // Box type 'moov' (wrong type)
    0x69, 0x73, 0x6F, 0x6D,  // Major brand 'isom'
    0x00, 0x00, 0x02, 0x00,  // Minor version
    0x69, 0x73, 0x6F, 0x6D,  // Compatible brand 'isom'
    0x69, 0x73, 0x6F, 0x32,  // Compatible brand 'iso2'
    0x6D, 0x70, 0x34, 0x31,  // Compatible brand 'mp41'
    0x6D, 0x70, 0x34, 0x32   // Compatible brand 'mp42'
};

// Test data - mdhd box (version 0)
static const uint8_t test_mdhd_box[] = {
    0x00, 0x00, 0x00, 0x20,  // Box size (32 bytes)
    0x6D, 0x64, 0x68, 0x64,  // Box type 'mdhd'
    0x00, 0x00, 0x00, 0x00,  // Version 0, flags
    0x00, 0x00, 0x00, 0x00,  // Creation time
    0x00, 0x00, 0x00, 0x00,  // Modification time
    0x00, 0x00, 0xAC, 0x44,  // Timescale (44100 Hz)
    0x00, 0x01, 0x5F, 0x90,  // Duration (90000 units)
    0x55, 0xC4, 0x00, 0x00   // Language and pre-defined
};

// Test data - hdlr box for audio track
static const uint8_t test_hdlr_audio_box[] = {
    0x00, 0x00, 0x00, 0x21,  // Box size (33 bytes)
    0x68, 0x64, 0x6C, 0x72,  // Box type 'hdlr'
    0x00, 0x00, 0x00, 0x00,  // Version 0, flags
    0x00, 0x00, 0x00, 0x00,  // Pre-defined
    0x73, 0x6F, 0x75, 0x6E,  // Handler type 'soun' (audio)
    0x00, 0x00, 0x00, 0x00,  // Reserved
    0x00, 0x00, 0x00, 0x00,  // Reserved
    0x00, 0x00, 0x00, 0x00,  // Reserved
    0x00                     // Name (empty)
};

// Test data - stsd box with mp4a entry
static const uint8_t test_stsd_box[] = {
    0x00, 0x00, 0x00, 0x67,  // Box size (103 bytes)
    0x73, 0x74, 0x73, 0x64,  // Box type 'stsd'
    0x00, 0x00, 0x00, 0x00,  // Version 0, flags
    0x00, 0x00, 0x00, 0x01,  // Entry count (1)
    // Sample entry starts here
    0x00, 0x00, 0x00, 0x57,  // Entry size (87 bytes)
    0x6D, 0x70, 0x34, 0x61,  // Codec type 'mp4a'
    0x00, 0x00, 0x00, 0x00,  // Reserved
    0x00, 0x00, 0x00, 0x01,  // Reserved, data reference index
    0x00, 0x00, 0x00, 0x00,  // Audio-specific reserved
    0x00, 0x00, 0x00, 0x00,  // Audio-specific reserved
    0x00, 0x02, 0x00, 0x10,  // Channels (2), sample size (16)
    0x00, 0x00, 0x00, 0x00,  // Compression ID, packet size
    0xAC, 0x44, 0x00, 0x00,  // Sample rate (44100 Hz, fixed-point)
    // Additional boxes would follow in real data
    0x00, 0x00, 0x00, 0x33,  // esds box size
    0x65, 0x73, 0x64, 0x73,  // esds box type
    // ... esds content (simplified)
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00
};

void test_mp4_parse_box_header() {
    printf("Testing mp4_parse_box_header...\n");
    
    Mp4BoxHeader header;
    int result = mp4_parse_box_header(test_ftyp_box, sizeof(test_ftyp_box), &header);
    
    assert(result == SONIX_OK);
    assert(header.size == 32);
    assert(header.type == 0x66747970); // 'ftyp'
    assert(header.header_size == 8);
    
    // Test with insufficient data
    result = mp4_parse_box_header(test_ftyp_box, 4, &header);
    assert(result == SONIX_ERROR_INVALID_DATA);
    
    printf("✓ mp4_parse_box_header tests passed\n");
}

void test_mp4_validate_ftyp_box() {
    printf("Testing mp4_validate_ftyp_box...\n");
    
    // Test valid ftyp box
    int result = mp4_validate_ftyp_box(test_ftyp_box, sizeof(test_ftyp_box));
    assert(result == SONIX_OK);
    
    // Test invalid ftyp box (wrong type)
    result = mp4_validate_ftyp_box(test_invalid_ftyp, sizeof(test_invalid_ftyp));
    assert(result == SONIX_ERROR_MP4_CONTAINER_INVALID);
    
    // Test with insufficient data
    result = mp4_validate_ftyp_box(test_ftyp_box, 8);
    assert(result == SONIX_ERROR_INVALID_DATA);
    
    printf("✓ mp4_validate_ftyp_box tests passed\n");
}

void test_mp4_find_box() {
    printf("Testing mp4_find_box...\n");
    
    // Create test data with multiple boxes
    uint8_t test_data[64];
    memcpy(test_data, test_ftyp_box, sizeof(test_ftyp_box));
    memcpy(test_data + sizeof(test_ftyp_box), test_mdhd_box, sizeof(test_mdhd_box));
    
    size_t box_size;
    
    // Find ftyp box
    const uint8_t* found_box = mp4_find_box(test_data, sizeof(test_data), 0x66747970, &box_size);
    assert(found_box != NULL);
    assert(found_box == test_data);
    assert(box_size == 32);
    
    // Find mdhd box
    found_box = mp4_find_box(test_data, sizeof(test_data), 0x6D646864, &box_size);
    assert(found_box != NULL);
    assert(found_box == test_data + sizeof(test_ftyp_box));
    assert(box_size == 32);
    
    // Try to find non-existent box
    found_box = mp4_find_box(test_data, sizeof(test_data), 0x12345678, &box_size);
    assert(found_box == NULL);
    
    printf("✓ mp4_find_box tests passed\n");
}

void test_mp4_parse_mdhd_box() {
    printf("Testing mp4_parse_mdhd_box...\n");
    
    Mp4MediaHeader mdhd;
    int result = mp4_parse_mdhd_box(test_mdhd_box, sizeof(test_mdhd_box), &mdhd);
    
    assert(result == SONIX_OK);
    assert(mdhd.timescale == 44100);
    assert(mdhd.duration == 90000);
    
    // Test with invalid box type
    result = mp4_parse_mdhd_box(test_ftyp_box, sizeof(test_ftyp_box), &mdhd);
    assert(result == SONIX_ERROR_MP4_CONTAINER_INVALID);
    
    printf("✓ mp4_parse_mdhd_box tests passed\n");
}

void test_mp4_parse_hdlr_box() {
    printf("Testing mp4_parse_hdlr_box...\n");
    
    Mp4HandlerReference hdlr;
    int result = mp4_parse_hdlr_box(test_hdlr_audio_box, sizeof(test_hdlr_audio_box), &hdlr);
    
    assert(result == SONIX_OK);
    assert(hdlr.handler_type == 0x736F756E); // 'soun'
    assert(hdlr.is_audio == 1);
    
    printf("✓ mp4_parse_hdlr_box tests passed\n");
}

void test_mp4_parse_stsd_box() {
    printf("Testing mp4_parse_stsd_box...\n");
    
    Mp4SampleDescription stsd;
    int result = mp4_parse_stsd_box(test_stsd_box, sizeof(test_stsd_box), &stsd);
    
    assert(result == SONIX_OK);
    assert(stsd.codec_type == 0x6D703461); // 'mp4a'
    assert(stsd.is_supported == 1);
    assert(stsd.channels == 2);
    assert(stsd.sample_size == 16);
    assert(stsd.sample_rate == 44100);
    
    printf("✓ mp4_parse_stsd_box tests passed\n");
}

void test_error_conditions() {
    printf("Testing error conditions...\n");
    
    Mp4BoxHeader header;
    
    // Test NULL pointers
    int result = mp4_parse_box_header(NULL, 100, &header);
    assert(result == SONIX_ERROR_INVALID_DATA);
    
    result = mp4_parse_box_header(test_ftyp_box, 100, NULL);
    assert(result == SONIX_ERROR_INVALID_DATA);
    
    // Test invalid ftyp validation
    result = mp4_validate_ftyp_box(NULL, 100);
    assert(result == SONIX_ERROR_INVALID_DATA);
    
    // Test find box with NULL parameters
    size_t box_size;
    const uint8_t* found = mp4_find_box(NULL, 100, 0x66747970, &box_size);
    assert(found == NULL);
    
    found = mp4_find_box(test_ftyp_box, 100, 0x66747970, NULL);
    assert(found == NULL);
    
    printf("✓ Error condition tests passed\n");
}

int main() {
    printf("Running MP4 container parsing tests...\n\n");
    
    test_mp4_parse_box_header();
    test_mp4_validate_ftyp_box();
    test_mp4_find_box();
    test_mp4_parse_mdhd_box();
    test_mp4_parse_hdlr_box();
    test_mp4_parse_stsd_box();
    test_error_conditions();
    
    printf("\n✅ All MP4 container parsing tests passed!\n");
    return 0;
}