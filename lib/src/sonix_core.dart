// Core data models and interfaces for Sonix audio waveform package

// Data models
export 'models/audio_data.dart';
export 'models/waveform_data.dart';

// Audio decoder interfaces
export 'decoders/audio_decoder.dart';
export 'decoders/audio_decoder_factory.dart';

// Format-specific decoders (placeholder implementations)
export 'decoders/mp3_decoder.dart';
export 'decoders/wav_decoder.dart';
export 'decoders/flac_decoder.dart';
export 'decoders/vorbis_decoder.dart';
export 'decoders/opus_decoder.dart';

// Native bindings
export 'native/native_audio_bindings.dart';

// Exceptions
export 'exceptions/sonix_exceptions.dart';

// Waveform processing
export 'processing/waveform_algorithms.dart';
export 'processing/waveform_generator.dart';

// Utilities
export 'utils/streaming_memory_manager.dart';
