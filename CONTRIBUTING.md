# Contributing to Sonix

Thank you for your interest in contributing to Sonix! This document provides guidelines and information for contributors.

## Table of Contents

1. [Code of Conduct](#code-of-conduct)
2. [Getting Started](#getting-started)
3. [Development Setup](#development-setup)
4. [Contributing Guidelines](#contributing-guidelines)
5. [Pull Request Process](#pull-request-process)
6. [Testing](#testing)
7. [Documentation](#documentation)
8. [Performance Considerations](#performance-considerations)

## Code of Conduct

This project adheres to a code of conduct that we expect all contributors to follow. Please be respectful and constructive in all interactions.

### Our Standards

- Use welcoming and inclusive language
- Be respectful of differing viewpoints and experiences
- Gracefully accept constructive criticism
- Focus on what is best for the community
- Show empathy towards other community members

## Getting Started

### Prerequisites

- Flutter SDK 3.0 or later
- Dart SDK 3.0 or later
- Git
- Platform-specific development tools:
  - **Android**: Android Studio, Android SDK
  - **iOS**: Xcode (macOS only)
  - **Desktop**: Platform-specific build tools

### Areas for Contribution

We welcome contributions in the following areas:

1. **Bug Fixes**: Fix existing issues and improve stability
2. **Performance Improvements**: Optimize memory usage and processing speed
3. **New Features**: Add new functionality (discuss first in issues)
4. **Documentation**: Improve docs, examples, and guides
5. **Testing**: Add tests and improve test coverage
6. **Platform Support**: Improve platform-specific implementations

## Development Setup

### 1. Fork and Clone

```bash
# Fork the repository on GitHub, then clone your fork
git clone https://github.com/YOUR_USERNAME/sonix.git
cd sonix

# Add upstream remote
git remote add upstream https://github.com/original-repo/sonix.git
```

### 2. Install Dependencies

```bash
# Install Flutter dependencies
flutter pub get

# Install example dependencies
cd example
flutter pub get
cd ..
```

### 3. Verify Setup

```bash
# Run tests to verify everything works
flutter test

# Run the example app
cd example
flutter run
```

### 4. Development Environment

We recommend using VS Code or Android Studio with the Flutter extension.

#### VS Code Setup

Install these extensions:
- Flutter
- Dart
- GitLens
- Error Lens

#### Recommended VS Code Settings

```json
{
  "dart.lineLength": 120,
  "editor.rulers": [120],
  "editor.formatOnSave": true,
  "dart.previewFlutterUiGuides": true,
  "dart.previewFlutterUiGuidesCustomTracking": true
}
```

## Contributing Guidelines

### Code Style

We follow the official Dart style guide with some project-specific conventions:

#### Formatting

```bash
# Format code before committing
dart format .

# Analyze code for issues
flutter analyze
```

#### Naming Conventions

- **Classes**: PascalCase (`WaveformWidget`)
- **Methods/Variables**: camelCase (`generateWaveform`)
- **Constants**: lowerCamelCase (`defaultResolution`)
- **Files**: snake_case (`waveform_widget.dart`)

#### Documentation

All public APIs must have comprehensive documentation:

```dart
/// Generate waveform data from an audio file.
///
/// This method processes the audio file at [filePath] and generates
/// waveform visualization data with the specified [resolution].
///
/// Example:
/// ```dart
/// final waveformData = await Sonix.generateWaveform(
///   'audio.mp3',
///   resolution: 500,
/// );
/// ```
///
/// Throws [UnsupportedFormatException] if the audio format is not supported.
/// Throws [DecodingException] if audio decoding fails.
static Future<WaveformData> generateWaveform(String filePath, {
  int resolution = 1000,
}) async {
  // Implementation
}
```

### Commit Messages

Use conventional commit format:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `perf`: Performance improvements
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

Examples:
```
feat(waveform): add chunked processing support

Add support for chunked waveform generation to handle large audio files
more efficiently. This reduces memory usage by processing audio in chunks.

Closes #123

fix(memory): resolve memory leak in waveform disposal

The WaveformData.dispose() method was not properly clearing the amplitudes
list, causing memory leaks in long-running applications.

docs(api): update API reference with new examples

Add comprehensive examples for all public methods and improve parameter
descriptions for better developer experience.
```

### Branch Naming

Use descriptive branch names:
- `feature/chunked-processing`
- `fix/memory-leak-disposal`
- `docs/api-reference-update`
- `perf/optimize-rendering`

## Pull Request Process

### 1. Before Creating a PR

- Ensure your code follows the style guidelines
- Add or update tests for your changes
- Update documentation if needed
- Run the full test suite
- Test on multiple platforms if applicable

### 2. Creating the PR

1. **Title**: Use a clear, descriptive title
2. **Description**: Explain what changes you made and why
3. **Testing**: Describe how you tested your changes
4. **Screenshots**: Include screenshots for UI changes
5. **Breaking Changes**: Clearly mark any breaking changes

### 3. PR Template

```markdown
## Description
Brief description of changes made.

## Type of Change
- [ ] Bug fix (non-breaking change which fixes an issue)
- [ ] New feature (non-breaking change which adds functionality)
- [ ] Breaking change (fix or feature that would cause existing functionality to not work as expected)
- [ ] Documentation update

## Testing
- [ ] Unit tests pass
- [ ] Integration tests pass
- [ ] Manual testing completed
- [ ] Tested on multiple platforms

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] No breaking changes (or clearly documented)

## Screenshots (if applicable)
Add screenshots here for UI changes.

## Additional Notes
Any additional information or context.
```

### 4. Review Process

1. **Automated Checks**: All CI checks must pass
2. **Code Review**: At least one maintainer review required
3. **Testing**: Changes must be tested on relevant platforms
4. **Documentation**: Documentation must be updated for API changes

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/waveform_generation_test.dart

# Run tests with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

### Test Categories

1. **Unit Tests**: Test individual functions and classes
2. **Widget Tests**: Test UI components
3. **Integration Tests**: Test complete workflows
4. **Performance Tests**: Test memory usage and speed

### Writing Tests

#### Unit Test Example

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('WaveformData', () {
    test('should create from amplitudes', () {
      // Arrange
      final amplitudes = [0.1, 0.5, 0.8, 0.3];
      
      // Act
      final waveformData = WaveformData.fromAmplitudes(amplitudes);
      
      // Assert
      expect(waveformData.amplitudes, equals(amplitudes));
      expect(waveformData.amplitudes.length, equals(4));
    });
    
    test('should serialize to JSON', () {
      // Arrange
      final waveformData = WaveformData.fromAmplitudes([0.1, 0.5]);
      
      // Act
      final json = waveformData.toJson();
      
      // Assert
      expect(json['amplitudes'], equals([0.1, 0.5]));
      expect(json, containsKey('duration'));
      expect(json, containsKey('sampleRate'));
    });
  });
}
```

#### Widget Test Example

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('WaveformWidget', () {
    testWidgets('should display waveform', (WidgetTester tester) async {
      // Arrange
      final waveformData = WaveformData.fromAmplitudes([0.1, 0.5, 0.8]);
      
      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: WaveformWidget(waveformData: waveformData),
          ),
        ),
      );
      
      // Assert
      expect(find.byType(WaveformWidget), findsOneWidget);
    });
  });
}
```

### Performance Testing

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sonix/sonix.dart';

void main() {
  group('Performance Tests', () {
    test('should generate waveform within time limit', () async {
      // Arrange
      const filePath = 'test/assets/sample_audio.mp3';
      final stopwatch = Stopwatch()..start();
      
      // Act
      final waveformData = await Sonix.generateWaveform(filePath);
      stopwatch.stop();
      
      // Assert
      expect(stopwatch.elapsedMilliseconds, lessThan(5000)); // 5 seconds max
      expect(waveformData.amplitudes.isNotEmpty, isTrue);
    });
  });
}
```

## Documentation

### Types of Documentation

1. **API Documentation**: Inline code documentation
2. **User Guides**: README, getting started guides
3. **Developer Guides**: Contributing, architecture docs
4. **Examples**: Sample code and applications

### Documentation Standards

- Use clear, concise language
- Include code examples for all public APIs
- Provide context and use cases
- Keep documentation up-to-date with code changes

### Generating Documentation

```bash
# Generate API documentation
dart doc

# Serve documentation locally
dart doc --serve
```

## Performance Considerations

### Memory Management

- Always dispose of resources properly
- Use chunked processing for large files
- Implement proper caching strategies
- Monitor memory usage in tests

### Processing Optimization

- Choose appropriate algorithms for use cases
- Optimize for different platforms
- Consider memory vs. speed trade-offs
- Profile performance regularly

### UI Performance

- Minimize widget rebuilds
- Use efficient rendering techniques
- Optimize animations
- Test on low-end devices

## Release Process

### Version Numbering

We follow [Semantic Versioning](https://semver.org/):
- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes (backward compatible)

### Release Checklist

1. Update version in `pubspec.yaml`
2. Update `CHANGELOG.md`
3. Run full test suite
4. Test on all supported platforms
5. Update documentation
6. Create release PR
7. Tag release after merge
8. Publish to pub.dev

## Getting Help

### Communication Channels

- **Issues**: For bug reports and feature requests
- **Discussions**: For questions and general discussion
- **Email**: For security issues or private matters

### Issue Templates

When creating issues, use the appropriate template:
- Bug Report
- Feature Request
- Documentation Improvement
- Performance Issue

### Response Times

We aim to respond to:
- Security issues: Within 24 hours
- Bug reports: Within 3 days
- Feature requests: Within 1 week
- Documentation issues: Within 1 week

## Recognition

Contributors will be recognized in:
- `CONTRIBUTORS.md` file
- Release notes for significant contributions
- Package documentation for major features

Thank you for contributing to Sonix! Your efforts help make audio waveform visualization better for everyone.