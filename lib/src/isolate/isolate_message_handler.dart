/// Message handler for serialization and deserialization of isolate messages
///
/// This class provides utilities for converting isolate messages to/from
/// formats that can be safely transmitted across isolate boundaries.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'isolate_messages.dart';
import 'error_serializer.dart';
import '../exceptions/sonix_exceptions.dart';

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

  /// Safely serialize a message with error handling
  ///
  /// Attempts to serialize a message and returns either the serialized data
  /// or an error message if serialization fails.
  static Map<String, dynamic> safeSerialize(IsolateMessage message) {
    try {
      return message.toJson();
    } catch (error, stackTrace) {
      // If serialization fails, create an error message instead
      return ErrorSerializer.createErrorMessage(
        messageId: message.id,
        error: IsolateCommunicationException.sendFailure(message.messageType, cause: error, details: 'Failed to serialize ${message.messageType} message'),
        stackTrace: stackTrace,
      );
    }
  }

  /// Safely deserialize a message with error handling
  ///
  /// Attempts to deserialize a message and returns either the message
  /// or an ErrorMessage if deserialization fails.
  static IsolateMessage safeDeserialize(Map<String, dynamic> json) {
    try {
      return IsolateMessage.fromJson(json);
    } catch (error, stackTrace) {
      // If deserialization fails, create an error message
      final messageType = json['messageType'] as String? ?? 'unknown';
      final messageId = json['id'] as String? ?? 'unknown';

      return ErrorMessage(
        id: '${messageId}_error',
        timestamp: DateTime.now(),
        errorMessage: 'Failed to deserialize $messageType message',
        errorType: 'IsolateCommunicationException',
        stackTrace: stackTrace.toString(),
      );
    }
  }

  /// Create an error message for communication failures
  static ErrorMessage createCommunicationError({
    required String messageId,
    required String messageType,
    required String operation,
    required Object error,
    StackTrace? stackTrace,
    String? isolateId,
    String? requestId,
  }) {
    final communicationError = IsolateCommunicationException(
      messageType,
      operation,
      isolateId: isolateId,
      cause: error,
      details: 'Communication failed during $operation operation',
    );

    final errorData = ErrorSerializer.serializeError(communicationError, stackTrace);

    return ErrorMessage(
      id: messageId,
      timestamp: DateTime.now(),
      errorMessage: communicationError.message,
      errorType: 'IsolateCommunicationException',
      requestId: requestId,
      stackTrace: stackTrace?.toString(),
    );
  }

  /// Validate message integrity and detect corruption
  static bool isMessageCorrupted(Map<String, dynamic> json) {
    // Check for required fields
    if (!json.containsKey('messageType') || !json.containsKey('id') || !json.containsKey('timestamp')) {
      return true;
    }

    // Validate timestamp format
    try {
      DateTime.parse(json['timestamp'] as String);
    } catch (e) {
      return true;
    }

    // Check for null or empty critical fields
    final messageType = json['messageType'];
    final id = json['id'];

    if (messageType == null || messageType.toString().isEmpty || id == null || id.toString().isEmpty) {
      return true;
    }

    return false;
  }

  /// Attempt to repair a corrupted message
  static Map<String, dynamic>? repairMessage(Map<String, dynamic> json) {
    final repaired = Map<String, dynamic>.from(json);
    bool wasRepaired = false;

    // Repair missing or invalid timestamp
    if (!repaired.containsKey('timestamp') || repaired['timestamp'] == null || repaired['timestamp'].toString().isEmpty) {
      repaired['timestamp'] = DateTime.now().toIso8601String();
      wasRepaired = true;
    }

    // Repair missing or invalid ID
    if (!repaired.containsKey('id') || repaired['id'] == null || repaired['id'].toString().isEmpty) {
      repaired['id'] = 'repaired_${DateTime.now().millisecondsSinceEpoch}';
      wasRepaired = true;
    }

    // Repair missing or invalid messageType
    if (!repaired.containsKey('messageType') || repaired['messageType'] == null || repaired['messageType'].toString().isEmpty) {
      repaired['messageType'] = 'ErrorMessage';
      repaired['errorMessage'] = 'Message type was corrupted and repaired';
      repaired['errorType'] = 'MessageCorruption';
      wasRepaired = true;
    }

    return wasRepaired ? repaired : null;
  }
}
