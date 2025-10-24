#!/usr/bin/env dart

/// Solid Generator CLI - Transpiles reactive annotations to flutter_solidart code
///
/// Usage: solid [options]
///
/// This CLI directly transpiles files from source/ to lib/ directory,
/// applying all transformations, formatting, and lint fixes in a single command.
library;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;
import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:crypto/crypto.dart';

import 'package:solid_generator/src/solid_builder.dart';

void main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption(
      'source',
      abbr: 's',
      defaultsTo: 'source',
      help: 'Source directory to read from',
    )
    ..addOption(
      'output',
      abbr: 'o',
      defaultsTo: 'lib',
      help: 'Output directory to write to',
    )
    ..addFlag(
      'watch',
      abbr: 'w',
      help: 'Watch for file changes and auto-regenerate',
    )
    ..addFlag(
      'clean',
      abbr: 'c',
      help: 'Deletes the build cache. The next build will be a full build.',
    )
    ..addFlag('verbose', abbr: 'v', help: 'Verbose output')
    ..addFlag('help', abbr: 'h', help: 'Show this help message');

  try {
    final results = parser.parse(arguments);

    if (results['help'] as bool) {
      print('Solid Generator - Direct source/ to lib/ transpilation');
      print('');
      print('Usage: solid [options]');
      print('');
      print(parser.usage);
      print('');
      print('Examples:');
      print('  solid                    # Basic transpilation');
      print('  solid --watch            # Watch mode');
      print('  solid --clean --verbose  # Clean build with verbose output');
      return;
    }

    final sourceDir = results['source'] as String;
    final outputDir = results['output'] as String;
    final watchMode = results['watch'] as bool;
    final cleanBuild = results['clean'] as bool;
    final verbose = results['verbose'] as bool;

    final generator = SolidGeneratorCLI(
      sourceDir: sourceDir,
      outputDir: outputDir,
      verbose: verbose,
    );

    if (cleanBuild) {
      await generator.clean();
    }

    if (watchMode) {
      await generator.watch();
    } else if (!cleanBuild) {
      // Only generate if not just cleaning
      await generator.generate();
    }
  } catch (e) {
    print('Error: $e');
    print('');
    print('Use --help for usage information');
    exit(1);
  }
}

class SolidGeneratorCLI {
  final String sourceDir;
  final String outputDir;
  final bool verbose;

  // For watch mode cancellation and debouncing
  Timer? _debounceTimer;
  bool _isGenerating = false;
  bool _cancelRequested = false;

  // Content tracking for smart regeneration
  final Map<String, String> _fileContentHashes = {};
  final Map<String, DateTime> _fileModificationTimes = {};
  int _generationCount = 0;

  SolidGeneratorCLI({
    required this.sourceDir,
    required this.outputDir,
    required this.verbose,
  });

  /// Wait for file to be stable (completely written) before processing
  /// Returns the stable content or null if file is still being written
  Future<String?> _waitForStableFile(File file) async {
    const maxAttempts = 5;
    const checkInterval = Duration(milliseconds: 100);

    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      try {
        // Read file size and content
        final stat1 = await file.stat();
        final content1 = await file.readAsString();

        // Wait a short time
        await Future.delayed(checkInterval);

        // Read again
        final stat2 = await file.stat();
        final content2 = await file.readAsString();

        // Check if file is stable (same size, modification time, and content)
        if (stat1.size == stat2.size &&
            stat1.modified == stat2.modified &&
            content1 == content2) {
          if (verbose && attempt > 0) {
            print('✅ File stable after ${attempt + 1} attempts');
          }
          return content2;
        }

        if (verbose) {
          print(
            '⏳ File still changing (attempt ${attempt + 1}/$maxAttempts)...',
          );
        }
      } catch (e) {
        if (verbose) {
          print(
            '⚠️  Error reading file (attempt ${attempt + 1}/$maxAttempts): $e',
          );
        }
      }
    }

    // File is still not stable after max attempts
    return null;
  }

  /// Calculate content hash for a file
  String _calculateContentHash(String content) {
    final bytes = utf8.encode(content);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  /// Check if any source files have changed since last generation
  Future<bool> _hasSourceFilesChanged() async {
    final sourceDirectory = Directory(sourceDir);
    if (!await sourceDirectory.exists()) return false;

    final dartFiles = await _findDartFiles(sourceDirectory);

    for (final file in dartFiles) {
      final relativePath = path.relative(file.path, from: sourceDir);
      final stat = await file.stat();

      // Use stable file reading for reliable content comparison
      final content = await _waitForStableFile(file);
      if (content == null) {
        // File is still being written, consider it changed
        return true;
      }

      final contentHash = _calculateContentHash(content);

      // Check if file is new or content has changed
      if (!_fileContentHashes.containsKey(relativePath) ||
          _fileContentHashes[relativePath] != contentHash ||
          !_fileModificationTimes.containsKey(relativePath) ||
          _fileModificationTimes[relativePath] != stat.modified) {
        return true;
      }
    }

    return false;
  }

  /// Update file tracking information
  Future<void> _updateFileTracking() async {
    final sourceDirectory = Directory(sourceDir);
    if (!await sourceDirectory.exists()) return;

    final dartFiles = await _findDartFiles(sourceDirectory);

    _fileContentHashes.clear();
    _fileModificationTimes.clear();

    for (final file in dartFiles) {
      final relativePath = path.relative(file.path, from: sourceDir);
      final stat = await file.stat();

      // Use stable file reading for reliable content tracking
      final content = await _waitForStableFile(file);
      if (content != null) {
        final contentHash = _calculateContentHash(content);
        _fileContentHashes[relativePath] = contentHash;
        _fileModificationTimes[relativePath] = stat.modified;
      }
    }
  }

  /// Determine if a clean rebuild is needed
  Future<bool> _needsCleanRebuild() async {
    // Always clean rebuild on first generation
    if (_generationCount == 0) return true;

    // Check if output directory exists
    final outputDirectory = Directory(outputDir);
    if (!await outputDirectory.exists()) return true;

    // Check if any generated files are missing
    final sourceDirectory = Directory(sourceDir);
    if (await sourceDirectory.exists()) {
      final dartFiles = await _findDartFiles(sourceDirectory);
      for (final file in dartFiles) {
        final relativePath = path.relative(file.path, from: sourceDir);
        final outputPath = path.join(outputDir, relativePath);
        final outputFile = File(outputPath);
        if (!await outputFile.exists()) return true;
      }
    }

    return false;
  }

  Future<void> generate() async {
    // Check if generation should be cancelled
    if (_cancelRequested) {
      _cancelRequested = false;
      if (verbose) print('⏹️  Generation cancelled - newer changes detected');
      return;
    }

    _isGenerating = true;
    _cancelRequested = false;

    // Smart change detection - skip generation if no changes
    if (_generationCount > 0 && !await _hasSourceFilesChanged()) {
      if (verbose) {
        print('✅ No source file changes detected - skipping generation');
      }
      _isGenerating = false;
      return;
    }

    // Check if clean rebuild is needed
    final needsClean = await _needsCleanRebuild();
    if (needsClean && _generationCount > 0) {
      print('🧹 Source files out of sync - performing clean rebuild...');
      await clean();
    }

    print('🚀 Solid Generator - Transpiling reactive code...');
    print('📁 Source: $sourceDir/ → Output: $outputDir/');
    if (needsClean && _generationCount > 0) {
      print('🔄 Clean rebuild triggered');
    }
    print('');

    final stopwatch = Stopwatch()..start();

    try {
      // Ensure output directory exists
      final outputDirectory = Directory(outputDir);
      if (!await outputDirectory.exists()) {
        await outputDirectory.create(recursive: true);
        if (verbose) print('📁 Created output directory: $outputDir/');
      }

      // Find all Dart files in source directory
      final sourceDirectory = Directory(sourceDir);
      if (!await sourceDirectory.exists()) {
        throw Exception('Source directory "$sourceDir" does not exist');
      }

      final dartFiles = await _findDartFiles(sourceDirectory);
      if (dartFiles.isEmpty) {
        print('⚠️  No Dart files found in $sourceDir/');
        return;
      }

      if (verbose) print('📋 Found ${dartFiles.length} Dart files to process');

      // Process each file
      int transformedCount = 0;
      int copiedCount = 0;
      final builder = SolidBuilder();

      for (final file in dartFiles) {
        // Check for cancellation during file processing
        if (_cancelRequested) {
          if (verbose) print('⏹️  Generation cancelled during file processing');
          _isGenerating = false;
          return;
        }

        final relativePath = path.relative(file.path, from: sourceDir);
        final outputPath = path.join(outputDir, relativePath);

        if (verbose) print('🔄 Processing: $relativePath');

        try {
          // Use stable file reading to avoid processing partial content
          final content = await _waitForStableFile(file);
          if (content == null) {
            if (verbose) {
              print('⏭️  File $relativePath still being written - skipping...');
            }
            continue;
          }

          // Parse and check if file needs transformation
          final parseResult = parseString(
            content: content,
            featureSet: FeatureSet.latestLanguageVersion(),
          );

          if (parseResult.errors.isNotEmpty) {
            print('⚠️  Parse errors in $relativePath: ${parseResult.errors}');
            continue;
          }

          // Transform the file using our existing builder logic
          final transformedCode = await builder.transformAstForTesting(
            parseResult.unit,
            file.path,
            content,
          );

          // Check if transformation actually occurred
          final needsTransformation = transformedCode != content;

          if (needsTransformation) {
            await _writeTransformedFile(outputPath, transformedCode);
            transformedCount++;
            if (verbose) print('✨ Transformed: $relativePath');
          } else {
            await _copyFile(file.path, outputPath);
            copiedCount++;
            if (verbose) print('📄 Copied: $relativePath');
          }
        } catch (e) {
          print('❌ Error processing $relativePath: $e');
        }
      }

      // Format all generated files
      print('');
      print('🎨 Formatting generated code...');
      await _formatGeneratedFiles();

      // Apply lint fixes
      print('🔧 Applying lint fixes...');
      await _applyLintFixes();

      // Update file tracking information after successful generation
      await _updateFileTracking();
      _generationCount++;

      stopwatch.stop();
      print('');
      print('✅ Generation complete!');
      print('📊 Transformed: $transformedCount files');
      print('📊 Copied: $copiedCount files');
      print('⏱️  Time: ${stopwatch.elapsed.inMilliseconds}ms');
      if (verbose) print('🔢 Generation #$_generationCount');
      print('');
      print('🎯 Your app is ready to run from $outputDir/main.dart');
    } catch (e) {
      print('❌ Generation failed: $e');
      exit(1);
    } finally {
      _isGenerating = false;
    }
  }

  Future<void> clean() async {
    print('🧹 Cleaning output directory: $outputDir/');

    final outputDirectory = Directory(outputDir);
    if (await outputDirectory.exists()) {
      await outputDirectory.delete(recursive: true);
      if (verbose) print('🗑️  Deleted: $outputDir/');
    }

    await outputDirectory.create(recursive: true);
    if (verbose) print('📁 Recreated: $outputDir/');
    print('');
  }

  Future<void> watch() async {
    print('👀 Watching for changes in $sourceDir/...');
    print('Press Ctrl+C to stop');
    print('');

    // Initial generation
    await generate();

    // Watch for file changes
    final sourceDirectory = Directory(sourceDir);
    await for (final event in sourceDirectory.watch(recursive: true)) {
      if (event.path.endsWith('.dart')) {
        final relativePath = path.relative(event.path, from: sourceDir);
        print('');
        print('🔄 File changed: $relativePath');

        // Cancel any ongoing generation immediately
        if (_isGenerating) {
          _cancelRequested = true;
          if (verbose) print('⏸️  Stopping ongoing generation...');

          // Wait for generation to stop
          while (_isGenerating) {
            await Future.delayed(const Duration(milliseconds: 50));
          }
        }

        // Cancel existing debounce timer
        _debounceTimer?.cancel();

        // Set up new debounce timer (1500ms - allows more time for file writing)
        _debounceTimer = Timer(const Duration(milliseconds: 1500), () async {
          try {
            // Ensure file is stable before processing
            final file = File(event.path);
            if (await file.exists()) {
              // Wait for file to be stable (not being written)
              final stableContent = await _waitForStableFile(file);

              if (stableContent == null) {
                if (verbose) {
                  print(
                    '⏭️  File still being written - skipping generation...',
                  );
                }
                return;
              }

              try {
                final parseResult = parseString(
                  content: stableContent,
                  featureSet: FeatureSet.latestLanguageVersion(),
                );

                if (parseResult.errors.isNotEmpty) {
                  if (verbose) {
                    print(
                      '⏭️  File has parse errors - waiting for valid syntax...',
                    );
                  }
                  return;
                }
              } catch (e) {
                if (verbose) {
                  print(
                    '⏭️  File cannot be parsed yet - waiting for completion...',
                  );
                }
                return;
              }
            }

            print('🔄 Regenerating files...');

            // Clear cached state to detect changes properly
            _fileContentHashes.clear();
            _fileModificationTimes.clear();

            // Let generate() decide if cleaning is needed based on its built-in logic
            await generate();
          } catch (e) {
            print('⚠️  Error during restart: $e');
            // Fall back to generation on error
            await generate();
          }
        });
      }
    }
  }

  Future<List<File>> _findDartFiles(Directory directory) async {
    final files = <File>[];

    await for (final entity in directory.list(recursive: true)) {
      if (entity is File &&
          entity.path.endsWith('.dart') &&
          !entity.path.endsWith('.solid.dart')) {
        files.add(entity);
      }
    }

    return files;
  }

  Future<void> _writeTransformedFile(String outputPath, String content) async {
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await outputFile.writeAsString(content);
  }

  Future<void> _copyFile(String inputPath, String outputPath) async {
    final inputFile = File(inputPath);
    final outputFile = File(outputPath);
    await outputFile.parent.create(recursive: true);
    await inputFile.copy(outputPath);
  }

  Future<void> _formatGeneratedFiles() async {
    try {
      final result = await Process.run('dart', ['format', outputDir]);

      if (result.exitCode == 0) {
        final output = result.stdout.toString().trim();
        if (output.isNotEmpty) {
          print('✅ $output');
        } else {
          print('✅ Code already properly formatted');
        }
      } else {
        print('⚠️  Format warnings: ${result.stderr}');
      }
    } catch (e) {
      print('⚠️  Could not format code: $e');
    }
  }

  Future<void> _applyLintFixes() async {
    try {
      final result = await Process.run('dart', ['fix', '--apply', outputDir]);

      if (result.exitCode == 0) {
        final stdout = result.stdout.toString().trim();
        final stderr = result.stderr.toString().trim();

        if (stdout.isNotEmpty && stdout.contains('fix')) {
          print('✅ Applied fixes: $stdout');
        } else if (stderr.isNotEmpty && stderr.contains('fixed')) {
          print('✅ Applied fixes: $stderr');
        } else {
          print('✅ No fixes needed - code is already compliant');
        }
      } else {
        print('⚠️  Fix warnings: ${result.stderr}');
      }
    } catch (e) {
      print('⚠️  Could not apply fixes: $e');
    }
  }
}
