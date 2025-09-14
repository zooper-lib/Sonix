/// Message handler for serialization and deserialization of isolate messages
///
/// This class provides utilities for converting isolate messages to/from
/// formats that can be safely transmitted across isolate boundaries.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'isolate_messages.dart';

/// Exception thrown when message serialization/deserialization fails
class MessageSerializationException implements Exception {
  final String message;
  final Object? originalError;

  const MessageSerializationException(this.message, [this.originalError]);

  @override
  String toString() => 'MessageSerializationException: $message';
}

/// Handles serialization and deserialization of isolate messages
///
/// Provides methods to convert messages to/from JSON strings and binary formats
/// for efficient transmission across isolate boundaries.
class IsolateMessageHandler {
  /// Serialize a message to JSON string
  ///
  /// Converts an [IsolateMessage] to a JSON string that can be safely
  /// transmitted across isolate boundaries.
  ///
  /// Throws [MessageSerializationException] if serialization fails.
  static String serializeToJson(IsolateMessage message) {
    try {
      final json = message.toJson();
      return jsonEncode(json);
    } catch (e) {
      throw MessageSerializationException('Failed to serialize message to JSON: ${message.runtimeType}', e);
    }
  }

  /// Deserialize a message from JSON string
  ///
  /// Converts a JSON string back to an [IsolateMessage] instance.
  ///
  /// Throws [MessageSerializationException] if deserialization fails.
  static IsolateMessage deserializeFromJson(String jsonString) {
    try {
      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      return IsolateMessage.fromJson(json);
    } catch (e) {
      throw MessageSerializationException('Failed to deserialize message from JSON', e);
    }
  }

  /// Serialize a message to binary format
  ///
  /// Converts an [IsolateMessage] to a binary format (UTF-8 encoded JSON)
  /// for more efficient transmission of large messages.
  ///
  /// Throws [MessageSerializationException] if serialization fails.
  static Uint8List serializeToBinary(IsolateMessage message) {
    try {
      final jsonString = serializeToJson(message);
      return Uint8List.fromList(utf8.encode(jsonString));
    } catch (e) {
      throw MessageSerializationException('Failed to serialize message to binary: ${message.runtimeType}', e);
    }
  }

  /// Deserialize a message from binary format
  ///
  /// Converts binary data (UTF-8 encoded JSON) back to an [IsolateMessage].
  ///
  /// Throws [MessageSerializationException] if deserialization fails.
  static IsolateMessage deserializeFromBinary(Uint8List binaryData) {
    try {
      final jsonString = utf8.decode(binaryData);
      return deserializeFromJson(jsonString);
    } catch (e) {
      throw MessageSerializationException('Failed to deserialize message from binary', e);
    }
  }

  /// Validate that a message can be serialized and deserialized correctly
  ///
  /// Performs a round-trip serialization test to ensure message integrity.
  /// Returns true if the message can be safely transmitted across isolates.
  ///
  /// Throws [MessageSerializationException] if validation fails.
  static bool validateMessage(IsolateMessage message) {
    try {
      // Test JSON serialization round-trip
      final jsonString = serializeToJson(message);
      final deserializedFromJson = deserializeFromJson(jsonString);

      // Test binary serialization round-trip
      final binaryData = serializeToBinary(message);
      final deserializedFromBinary = deserializeFromBinary(binaryData);

      // Verify both deserialized messages have the same type and ID
      if (deserializedFromJson.runtimeType != message.runtimeType ||
          deserializedFromBinary.runtimeType != message.runtimeType ||
          deserializedFromJson.id != message.id ||
          deserializedFromBinary.id != message.id) {
        throw MessageSerializationException('Message validation failed: deserialized message differs from original');
      }

      return true;
    } catch (e) {
      throw MessageSerializationException('Message validation failed for ${message.runtimeType}', e);
    }
  }

  /// Get the estimated size of a serialized message in bytes
  ///
  /// Returns the approximate size of the message when serialized to JSON.
  /// Useful for optimizing message batching and memory management.
  static int getMessageSize(IsolateMessage message) {
    try {
      final jsonString = serializeToJson(message);
      return utf8.encode(jsonString).length;
    } catch (e) {
      // Return 0 if we can't determine size
      return 0;
    }
  }

  /// Batch multiple messages into a single serialized payload
  ///
  /// Combines multiple messages into a single JSON array for more efficient
  /// transmission when sending multiple messages at once.
  ///
  /// Throws [MessageSerializationException] if any message fails to serialize.
  static String serializeBatch(List<IsolateMessage> messages) {
    try {
      final jsonList = messages.map((message) => message.toJson()).toList();
      return jsonEncode(jsonList);
    } catch (e) {
      throw MessageSerializationException('Failed to serialize message batch', e);
    }
  }

  /// Deserialize a batch of messages from a single payload
  ///
  /// Converts a JSON array back to a list of [IsolateMessage] instances.
  ///
  /// Throws [MessageSerializationException] if deserialization fails.
  static List<IsolateMessage> deserializeBatch(String jsonString) {
    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList.cast<Map<String, dynamic>>().map((json) => IsolateMessage.fromJson(json)).toList();
    } catch (e) {
      throw MessageSerializationException('Failed to deserialize message batch', e);
    }
  }
}
