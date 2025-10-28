import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/features.dart';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:build/build.dart';

import 'reactive_state_transformer.dart';
import 'result.dart';

/// Builder that transforms reactive annotations in Dart files.
/// Reads from source/ directory and outputs to lib/ directory.
class SolidBuilder extends Builder {
  SolidBuilder();

  @override
  Map<String, List<String>> get buildExtensions => const {
    '.dart': ['.solid.dart'],
  };

  @override
  FutureOr<void> build(BuildStep buildStep) async {
    final inputId = buildStep.inputId;
    // Skip if not a source file we should process
    if (!_shouldProcess(inputId)) {
      return;
    }

    try {
      // Read the input file content (still needed for formatting preservation)
      final content = await buildStep.readAsString(inputId);

      CompilationUnit compilationUnit;

      try {
        // PERFORMANCE OPTIMIZATION: Use build_runner's optimized AST parsing via resolver
        // Benefits over manual parseString():
        // 1. Cached parsing - build_runner reuses already-parsed ASTs
        // 2. Resolved type information - no need to manually resolve imports
        // 3. Incremental compilation - only re-parse changed files
        // 4. Better error handling with resolved context
        // 5. Faster subsequent builds due to build system caching
        final resolver = buildStep.resolver;
        compilationUnit = await resolver.compilationUnitFor(inputId);
        // Using optimized resolver path
      } catch (resolverError) {
        // FALLBACK: Use manual parsing if resolver is not available (e.g., in test environments)
        final parseResult = parseString(
          content: content,
          featureSet: FeatureSet.latestLanguageVersion(),
        );

        if (parseResult.errors.isNotEmpty) {
          log.warning('Parse errors in ${inputId.path}: ${parseResult.errors}');
          return;
        }

        compilationUnit = parseResult.unit;
        // Using fallback parseString path
      }

      // Transform the AST using either the optimized or fallback compilation unit
      final transformedCode = await _transformAst(
        compilationUnit,
        inputId.path,
        content,
      );

      // Format the generated code
      final formattedCode = await _formatDartCode(transformedCode);

      // Always write output (either transformed or copied)
      final outputId = _getOutputAssetId(inputId);
      await buildStep.writeAsString(outputId, formattedCode);

      log.info('Generated ${outputId.path} from ${inputId.path}');
    } catch (e, stackTrace) {
      log.severe('Error processing ${inputId.path}: $e', e, stackTrace);
    }
  }

  /// Determines if a file should be processed by this builder.
  bool _shouldProcess(AssetId inputId) {
    final path = inputId.path;

    // Only process .dart files
    if (!path.endsWith('.dart')) {
      return false;
    }

    // Process files from source/ directory (user input files)
    return path.startsWith('source/');
  }

  /// Transpiles the AST by replacing reactive annotations with actual code.
  Future<String> _transformAst(
    CompilationUnit unit,
    String filePath,
    String originalContent,
  ) async {
    return transformAstForTesting(unit, filePath, originalContent);
  }

  /// Enhanced version that can leverage resolver for type information
  /// This provides access to resolved types for even more advanced optimizations
  ///
  /// The resolver provides:
  /// - resolver.typeProvider: Access to common types (String, int, etc.)
  /// - resolver.libraryFor(element): Get library information
  /// - element.staticType: Resolved types for AST nodes
  /// - Dependency graph information for better optimization decisions
  ///
  /// Performance benefits over manual parsing:
  /// - Cached AST parsing (build_runner reuses parsed trees)
  /// - Resolved type information (no need to manually resolve imports/types)
  /// - Better error handling and incremental compilation support
  /// - Faster subsequent builds due to build_runner's caching
  Future<String> transformAstWithResolver(
    CompilationUnit unit,
    String filePath,
    String originalContent,
    Resolver resolver,
  ) async {
    // For now, delegate to the existing method
    // In the future, we can leverage:
    // - resolver.typeProvider for type checking
    // - resolver.libraryFor() for dependency analysis
    // - Static type information for more intelligent transformations
    // - Better error messages with resolved context
    return transformAstForTesting(unit, filePath, originalContent);
  }

  /// Public method for testing the transformation logic
  Future<String> transformAstForTesting(
    CompilationUnit unit,
    String filePath,
    String originalContent,
  ) async {
    // Start with the original content (preserving formatting)
    String transpiledContent = originalContent;
    bool hasReactiveCode = false;
    final importsToAdd = <String>{};

    // Initialize transformers
    final stateTransformer = SolidStateTransformer();
    final computedTransformer = SolidComputedTransformer();
    final effectTransformer = SolidEffectTransformer();
    final queryTransformer = SolidQueryTransformer();
    final environmentTransformer = EnvironmentTransformer();

    // Extract signal field names before transformation for access pattern updates
    final signalFieldNames = _extractSignalFieldNames(unit, stateTransformer);

    // Separate environment fields from direct signal fields
    final environmentFieldNames = _extractEnvironmentFieldNames(unit);

    // Track classes that need StatefulWidget conversion
    final classesToConvert = <ClassDeclaration>[];

    // First pass: Identify classes that need StatefulWidget conversion
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        bool classHasReactiveCode = false;

        for (final member in declaration.members) {
          if (member is FieldDeclaration) {
            // Check @SolidState fields
            if (stateTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              hasReactiveCode = true;
              break;
            }
            // Check @Environment fields
            if (environmentTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              hasReactiveCode = true;
              break;
            }
          } else if (member is MethodDeclaration) {
            // Check for reactive getters, effects, or queries
            if (computedTransformer.canTransform(member) ||
                effectTransformer.canTransform(member) ||
                queryTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              hasReactiveCode = true;
              break;
            }
          }
        }

        // Mark class for StatefulWidget conversion if it has reactive transformations
        if (classHasReactiveCode && _isStatelessWidget(declaration)) {
          classesToConvert.add(declaration);
        }
      }
    }

    // Second pass: Apply AST-based SignalBuilder wrapping BEFORE StatefulWidget conversion
    // This ensures we detect reactive access in the original StatelessWidget structure
    final allReactiveFieldNames = signalFieldNames.union(environmentFieldNames);
    if (allReactiveFieldNames.isNotEmpty) {
      transpiledContent = _wrapSignalAccessWithBuilder(
        transpiledContent,
        allReactiveFieldNames,
      );
    }

    // Third pass: Convert StatelessWidget to StatefulWidget AFTER SignalBuilder wrapping
    final classesToConvertReversed = classesToConvert.toList()
      ..sort((a, b) {
        // Sort by position in file (descending) to process from end to beginning
        final aOffset = transpiledContent.indexOf(
          'class ${a.name.lexeme} extends StatelessWidget',
        );
        final bOffset = transpiledContent.indexOf(
          'class ${b.name.lexeme} extends StatelessWidget',
        );
        return bOffset.compareTo(aOffset);
      });

    for (final classDeclaration in classesToConvertReversed) {
      transpiledContent = _convertToStatefulWidget(
        transpiledContent,
        classDeclaration,
        originalContent,
      );
    }

    // Fourth pass: Apply transformations to classes that have reactive code but are not StatelessWidget
    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        // Skip classes that were already processed in StatefulWidget conversion
        if (classesToConvert.contains(declaration)) {
          continue;
        }

        // Check if this class has reactive code
        bool classHasReactiveCode = false;
        for (final member in declaration.members) {
          if (member is FieldDeclaration) {
            if (stateTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              break;
            }
            if (environmentTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              break;
            }
          } else if (member is MethodDeclaration) {
            if (computedTransformer.canTransform(member) ||
                effectTransformer.canTransform(member) ||
                queryTransformer.canTransform(member)) {
              classHasReactiveCode = true;
              break;
            }
          }
        }

        // Apply transformations to this class
        if (classHasReactiveCode) {
          transpiledContent = _applyTransformationsToClass(
            transpiledContent,
            declaration,
            stateTransformer,
            computedTransformer,
            effectTransformer,
            queryTransformer,
            environmentTransformer,
          );
        }
      }
    }

    // Fourth pass: Transform main function if it contains runApp
    final beforeMainTransform = transpiledContent;
    transpiledContent = _transformMainFunction(transpiledContent, unit);
    final mainFunctionWasTransformed = beforeMainTransform != transpiledContent;

    // Check if SolidartConfig is used in the content (either newly added or already present)
    final usesSolidartConfig = transpiledContent.contains('SolidartConfig.');

    // Fifth pass: Add imports for flutter_solidart since reactive transformations were done
    // Add import if there's reactive code, a main function with runApp, main function was transformed, or SolidartConfig is used
    if (hasReactiveCode || _hasMainFunctionWithRunApp(unit) || mainFunctionWasTransformed || usesSolidartConfig) {
      importsToAdd.add(
        "import 'package:flutter_solidart/flutter_solidart.dart';",
      );
    }

    // Sixth pass: Apply signal access transformations AFTER all reactive transformations are done
    if (signalFieldNames.isNotEmpty) {
      // Extract signal field names from ALL classes with reactive code
      final allStatefulWidgetSignalNames = <String>{};

      // 1. Add signal field names from StatefulWidget converted classes
      for (final classDeclaration in classesToConvert) {
        for (final member in classDeclaration.members) {
          if (member is FieldDeclaration &&
              stateTransformer.canTransform(member)) {
            for (final variable in member.fields.variables) {
              allStatefulWidgetSignalNames.add(variable.name.lexeme);
            }
          } else if (member is MethodDeclaration) {
            // Check for @SolidState getters that become Computed signals
            if (computedTransformer.canTransform(member)) {
              allStatefulWidgetSignalNames.add(member.name.lexeme);
            }
            // Check for @SolidEffect methods that become Effect fields
            if (effectTransformer.canTransform(member)) {
              allStatefulWidgetSignalNames.add(member.name.lexeme);
            }
            // Check for @SolidQuery methods that become Resource fields
            if (queryTransformer.canTransform(member)) {
              allStatefulWidgetSignalNames.add(member.name.lexeme);
            }
          }
        }
      }

      // 2. Add signal field names from existing StatefulWidget classes
      for (final declaration in unit.declarations) {
        if (declaration is ClassDeclaration &&
            !classesToConvert.contains(declaration)) {
          // Check if this class has reactive code
          bool classHasReactiveCode = false;
          for (final member in declaration.members) {
            if (member is FieldDeclaration) {
              if (stateTransformer.canTransform(member) ||
                  environmentTransformer.canTransform(member)) {
                classHasReactiveCode = true;
                break;
              }
            } else if (member is MethodDeclaration) {
              if (computedTransformer.canTransform(member) ||
                  effectTransformer.canTransform(member) ||
                  queryTransformer.canTransform(member)) {
                classHasReactiveCode = true;
                break;
              }
            }
          }

          // If this class has reactive code, extract its signal field names
          if (classHasReactiveCode) {
            for (final member in declaration.members) {
              if (member is FieldDeclaration &&
                  stateTransformer.canTransform(member)) {
                for (final variable in member.fields.variables) {
                  allStatefulWidgetSignalNames.add(variable.name.lexeme);
                }
              } else if (member is MethodDeclaration) {
                // Check for @SolidState getters that become Computed signals
                if (computedTransformer.canTransform(member)) {
                  allStatefulWidgetSignalNames.add(member.name.lexeme);
                }
                // Check for @SolidEffect methods that become Effect fields
                if (effectTransformer.canTransform(member)) {
                  allStatefulWidgetSignalNames.add(member.name.lexeme);
                }
                // Check for @SolidQuery methods that become Resource fields
                if (queryTransformer.canTransform(member)) {
                  allStatefulWidgetSignalNames.add(member.name.lexeme);
                }
              }
            }
          }
        }
      }

      // Apply signal access transformation for ALL StatefulWidget classes with reactive code
      if (allStatefulWidgetSignalNames.isNotEmpty ||
          environmentFieldNames.isNotEmpty) {
        transpiledContent = _transformSignalAccess(
          transpiledContent,
          allStatefulWidgetSignalNames,
          environmentFieldNames,
        );
      }
    }

    // If no reactive code was found and no imports need to be added, return original content (copy as-is)
    if (!hasReactiveCode && importsToAdd.isEmpty) {
      return transpiledContent;
    }

    // Signal access transformations were already applied earlier

    // Process imports: remove solid_annotations and add flutter_solidart
    final lines = transpiledContent.split('\n');
    final importLines = <String>[];
    final contentLines = <String>[];

    bool foundFirstNonImport = false;
    for (final line in lines) {
      if (!foundFirstNonImport &&
          (line.startsWith('import ') || line.trim().isEmpty)) {
        importLines.add(line);
      } else {
        if (!foundFirstNonImport) {
          foundFirstNonImport = true;
          // Add our imports before the first non-import line
          for (final import in importsToAdd) {
            importLines.add(import);
          }
          importLines.add(''); // Empty line after imports
        }
        contentLines.add(line);
      }
    }

    transpiledContent = [...importLines, ...contentLines].join('\n');

    return transpiledContent;
  }

  /// Gets the output asset ID for a given input.
  /// Creates .solid.dart files in the same directory as input
  AssetId _getOutputAssetId(AssetId inputId) {
    final inputPath = inputId.path;
    final pathWithoutExtension = inputPath.substring(
      0,
      inputPath.length - '.dart'.length,
    );
    return AssetId(inputId.package, '$pathWithoutExtension.solid.dart');
  }

  /// Extracts the names of fields that were transformed to Signals, Computed, Effects, or Resources
  Set<String> _extractSignalFieldNames(
    CompilationUnit unit,
    SolidStateTransformer transformer,
  ) {
    final signalFieldNames = <String>{};

    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is FieldDeclaration && transformer.canTransform(member)) {
            // Extract field name from the declaration
            for (final variable in member.fields.variables) {
              signalFieldNames.add(variable.name.lexeme);
            }
          } else if (member is FieldDeclaration) {
            // Check for @Environment fields - they may access reactive values in the UI
            final environmentTransformer = EnvironmentTransformer();
            if (environmentTransformer.canTransform(member)) {
              for (final variable in member.fields.variables) {
                signalFieldNames.add(variable.name.lexeme);
              }
            }
          } else if (member is MethodDeclaration) {
            // Check for @SolidState getters that become Computed signals
            final computedTransformer = SolidComputedTransformer();
            if (computedTransformer.canTransform(member)) {
              signalFieldNames.add(member.name.lexeme);
            }
            // Check for @SolidEffect methods that become Effect fields
            final effectTransformer = SolidEffectTransformer();
            if (effectTransformer.canTransform(member)) {
              signalFieldNames.add(member.name.lexeme);
            }
            // Check for @SolidQuery methods that become Resource fields
            final queryTransformer = SolidQueryTransformer();
            if (queryTransformer.canTransform(member)) {
              signalFieldNames.add(member.name.lexeme);
            }
          }
        }
      }
    }

    return signalFieldNames;
  }

  /// Extract only environment field names (not direct signals)
  Set<String> _extractEnvironmentFieldNames(CompilationUnit unit) {
    final environmentFieldNames = <String>{};

    for (final declaration in unit.declarations) {
      if (declaration is ClassDeclaration) {
        for (final member in declaration.members) {
          if (member is FieldDeclaration) {
            // Check for @Environment fields only
            final environmentTransformer = EnvironmentTransformer();
            if (environmentTransformer.canTransform(member)) {
              for (final variable in member.fields.variables) {
                environmentFieldNames.add(variable.name.lexeme);
              }
            }
          }
        }
      }
    }

    return environmentFieldNames;
  }

  /// Checks if a class extends StatelessWidget
  bool _isStatelessWidget(ClassDeclaration classDeclaration) {
    final extendsClause = classDeclaration.extendsClause;
    if (extendsClause == null) return false;

    final superclass = extendsClause.superclass;
    return superclass.name.lexeme == 'StatelessWidget';
  }

  /// Applies reactive transformations to a class without StatefulWidget conversion
  String _applyTransformationsToClass(
    String content,
    ClassDeclaration classDeclaration,
    SolidStateTransformer stateTransformer,
    SolidComputedTransformer computedTransformer,
    SolidEffectTransformer effectTransformer,
    SolidQueryTransformer queryTransformer,
    EnvironmentTransformer environmentTransformer,
  ) {
    String transpiledContent = content;
    final effectFieldNames =
        <String>[]; // Track Effect field names for initState()

    // Process each member and apply transformations
    for (final member in classDeclaration.members) {
      if (member is FieldDeclaration) {
        // Transform @SolidState fields to Signal declarations
        if (stateTransformer.canTransform(member)) {
          final result = stateTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            final signalDeclaration = success.value;

            // Find the field variable name to create a more flexible replacement
            final fieldVariable = member.fields.variables.first;
            final fieldName = fieldVariable.name.lexeme;

            // Create regex pattern to match the field declaration with flexible whitespace
            // Handle both fields with initializers and without initializers, and optional types
            final pattern = RegExp(
              r'(\s*)@SolidState\([^)]*\)\s*\n\s*\w+\??\s+' +
                  RegExp.escape(fieldName) +
                  r'(?:\s*=\s*[^;]*)?;',
              multiLine: true,
            );

            final match = pattern.firstMatch(transpiledContent);
            if (match != null) {
              final indentation = match.group(1) ?? '';
              final replacement = '$indentation$signalDeclaration';
              transpiledContent = transpiledContent.replaceFirst(
                pattern,
                replacement,
              );
            }
          }
        }
        // Transform @Environment fields to context.read<T>() declarations
        else if (environmentTransformer.canTransform(member)) {
          final result = environmentTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            final environmentDeclaration = success.value;

            // Find the field variable name to create a more flexible replacement
            final fieldVariable = member.fields.variables.first;
            final fieldName = fieldVariable.name.lexeme;

            // Create regex pattern to match the field declaration with flexible whitespace
            final pattern = RegExp(
              r'(\s*)@Environment\([^)]*\)\s*\n\s*late\s+\w+\??\s+' +
                  RegExp.escape(fieldName) +
                  r';',
              multiLine: true,
            );

            final match = pattern.firstMatch(transpiledContent);
            if (match != null) {
              final indentation = match.group(1) ?? '';
              final replacement = '$indentation$environmentDeclaration';
              transpiledContent = transpiledContent.replaceFirst(
                pattern,
                replacement,
              );
            }
          }
        }
      } else if (member is MethodDeclaration) {
        String? transformation;

        // Check for reactive getters (Computed)
        if (computedTransformer.canTransform(member)) {
          final result = computedTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
          }
        }
        // Check for reactive effects
        else if (effectTransformer.canTransform(member)) {
          final result = effectTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
            // Track Effect field name for initState() initialization
            effectFieldNames.add(member.name.lexeme);
          }
        }
        // Check for queries (Resources)
        else if (queryTransformer.canTransform(member)) {
          final result = queryTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
          }
        }

        // Apply the transformation if one was generated
        if (transformation != null) {
          final methodName = member.name.lexeme;

          // Create a more robust pattern that handles both methods and getters
          // For methods: annotation + return type + methodName + (
          // For getters: annotation + return type + get + methodName + =>
          final methodStartPattern = RegExp(
            r'(\s*)@(?:SolidState|SolidEffect|SolidQuery)\([^)]*\).*?\n.*?(?:get\s+)?' +
                RegExp.escape(methodName) +
                r'(?:\s*\(|(?=\s*=>))',
            multiLine: true,
            dotAll: true,
          );

          final startMatch = methodStartPattern.firstMatch(transpiledContent);
          if (startMatch != null) {
            // Find the full method by counting braces
            final startIndex = startMatch.start;
            var braceCount = 0;
            var endIndex = startIndex;
            var foundOpenBrace = false;

            for (int i = startMatch.end; i < transpiledContent.length; i++) {
              final char = transpiledContent[i];
              if (char == '{') {
                foundOpenBrace = true;
                braceCount++;
              } else if (char == '}') {
                braceCount--;
                if (foundOpenBrace && braceCount == 0) {
                  endIndex = i + 1;
                  break;
                }
              } else if (char == ';' && !foundOpenBrace) {
                // Getter with => syntax
                endIndex = i + 1;
                break;
              }
            }

            if (endIndex > startIndex) {
              final indentation = startMatch.group(1) ?? '';
              final replacement = '$indentation$transformation';
              transpiledContent = transpiledContent.replaceRange(
                startIndex,
                endIndex,
                replacement,
              );
            }
          }
        }
      }
    }

    // Handle Effect initialization for existing StatefulWidget classes
    if (effectFieldNames.isNotEmpty) {
      transpiledContent = _handleEffectInitializationForExistingClass(
        transpiledContent,
        classDeclaration,
        effectFieldNames,
      );
    }

    // Add dispose method to handle reactive cleanup
    transpiledContent = _addDisposeMethodToClass(
      transpiledContent,
      classDeclaration,
    );

    return transpiledContent;
  }

  /// Handles Effect initialization for existing StatefulWidget classes
  String _handleEffectInitializationForExistingClass(
    String content,
    ClassDeclaration classDeclaration,
    List<String> effectFieldNames,
  ) {
    final className = classDeclaration.name.lexeme;

    // Check if there's already an initState method in the class
    MethodDeclaration? existingInitState;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'initState') {
        existingInitState = member;
        break;
      }
    }

    if (existingInitState != null) {
      // Modify existing initState() method to add Effect references
      final modifiedInitState = _modifyExistingInitState(
        content,
        existingInitState,
        effectFieldNames,
        className,
      );
      if (modifiedInitState != null) {
        // Replace the existing initState method in the content
        return _replaceExistingInitStateInContent(
          content,
          existingInitState,
          modifiedInitState,
          className,
        );
      }
    } else {
      // Create a new initState() method for the existing StatefulWidget class
      return _addNewInitStateToExistingClass(
        content,
        className,
        effectFieldNames,
      );
    }

    return content;
  }

  /// Replaces an existing initState method in the content with the modified version
  String _replaceExistingInitStateInContent(
    String content,
    MethodDeclaration existingInitState,
    String modifiedInitState,
    String className,
  ) {
    try {
      final lines = content.split('\n');
      bool inTargetClass = false;
      bool foundInitState = false;
      int braceDepth = 0;
      int startLine = -1;
      int endLine = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className extends')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the initState method
          if ((line.trim().startsWith('@override') &&
                  i + 1 < lines.length &&
                  lines[i + 1].trim().startsWith('initState(')) ||
              line.trim().startsWith('initState(')) {
            if (line.trim().startsWith('@override')) {
              startLine = i;
              foundInitState = true;
            } else if (line.trim().startsWith('initState(')) {
              startLine = foundInitState ? startLine : i;
              foundInitState = true;
              // Track braces
              final openBraces = line.split('{').length - 1;
              braceDepth += openBraces;
            }
            continue;
          }

          if (foundInitState && braceDepth > 0) {
            // Track braces to know when the method ends
            final openBraces = line.split('{').length - 1;
            final closeBraces = line.split('}').length - 1;
            braceDepth += openBraces;
            braceDepth -= closeBraces;

            // If we've closed all method braces, we're done
            if (braceDepth == 0) {
              endLine = i;
              break;
            }
          }
        }
      }

      if (startLine != -1 && endLine != -1) {
        // Replace the initState method
        final beforeInitState = lines.sublist(0, startLine);
        final afterInitState = endLine + 1 < lines.length
            ? lines.sublist(endLine + 1)
            : <String>[];

        return [
          ...beforeInitState,
          modifiedInitState,
          ...afterInitState,
        ].join('\n');
      }
    } catch (e) {
      // If parsing fails, return original content
    }

    return content;
  }

  /// Adds a new initState() method to an existing StatefulWidget class
  String _addNewInitStateToExistingClass(
    String content,
    String className,
    List<String> effectFieldNames,
  ) {
    try {
      final lines = content.split('\n');
      bool inTargetClass = false;
      int insertionPoint = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className') ||
            line.contains('class _${className}State')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the build method to insert initState before it
          if (line.trim().startsWith('@override') &&
              i + 1 < lines.length &&
              lines[i + 1].trim().startsWith('Widget build(')) {
            insertionPoint = i;
            break;
          } else if (line.trim().startsWith('Widget build(')) {
            insertionPoint = i;
            break;
          }
        }
      }

      if (insertionPoint != -1) {
        // Insert the new initState method
        final beforeBuild = lines.sublist(0, insertionPoint);
        final afterBuild = lines.sublist(insertionPoint);

        final newInitState = [
          '  @override',
          '  initState() {',
          '    super.initState();',
          ...effectFieldNames.map((name) => '    $name;'),
          '  }',
          '',
        ];

        return [...beforeBuild, ...newInitState, ...afterBuild].join('\n');
      }
    } catch (e) {
      // If parsing fails, return original content
    }

    return content;
  }

  /// Converts a StatelessWidget class to StatefulWidget using AST information
  String _convertToStatefulWidget(
    String content,
    ClassDeclaration classDeclaration, [
    String? originalSourceContent,
  ]) {
    final className = classDeclaration.name.lexeme;
    final stateName = '_${className}State'; // Make state class private

    // Extract constructor from the AST
    String constructor = '$className();'; // Default constructor
    for (final member in classDeclaration.members) {
      if (member is ConstructorDeclaration) {
        constructor = member.toSource();
        break;
      }
    }

    // Extract build method from the AST - get properly formatted version from original source
    String? buildMethod;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration &&
          member.name.lexeme == 'build' &&
          member.returnType?.toSource() == 'Widget') {
        // Get the build method from the current content (which may contain SignalBuilder wrapping)
        buildMethod = _extractFormattedBuildMethod(
          content, // Use the current content, not the original
          className,
        );
        break;
      }
    }

    if (buildMethod == null) return content; // No build method found

    // Apply reactive field transformation to the build method

    // Extract field names, distinguishing between Signal fields and Resource/Effect methods
    final signalFieldNames = <String>{}; // @SolidState fields that need .value
    final resourceMethodNames = <String>{}; // @SolidQuery/@SolidEffect methods that don't need .value

    for (final member in classDeclaration.members) {
      if (member is FieldDeclaration) {
        // Check for @SolidState annotation on fields
        final annotations = member.metadata;
        final hasSolidState = annotations.any(
          (annotation) => annotation.name.name == 'SolidState',
        );
        if (hasSolidState) {
          for (final variable in member.fields.variables) {
            signalFieldNames.add(variable.name.lexeme);
          }
        }
      } else if (member is MethodDeclaration) {
        // Check for reactive annotations on methods/getters
        final annotations = member.metadata;
        final hasSolidQuery = annotations.any(
          (annotation) => annotation.name.name == 'SolidQuery',
        );
        final hasSolidEffect = annotations.any(
          (annotation) => annotation.name.name == 'SolidEffect',
        );

        if (hasSolidQuery || hasSolidEffect) {
          // Resource/Effect methods don't need .value transformation
          resourceMethodNames.add(member.name.lexeme);
        }
      }
    }

    // Transform reactive field access in the build method
    // Only apply .value transformation to Signal fields, not Resource/Effect methods
    if (signalFieldNames.isNotEmpty) {
      for (final fieldName in signalFieldNames) {
        // Transform string interpolation: $fieldName to ${fieldName.value}
        final interpolationPattern = RegExp(
          r'\$' + RegExp.escape(fieldName) + r'(?!\.value)(?!\w)',
        );
        buildMethod = buildMethod!.replaceAll(
          interpolationPattern,
          '\${$fieldName.value}',
        );

        // Transform direct access: fieldName to fieldName.value
        final directAccessPattern = RegExp(
          r'\b' + RegExp.escape(fieldName) + r'\b(?!\.value)(?!\()',
        );
        buildMethod = buildMethod.replaceAll(
          directAccessPattern,
          '$fieldName.value',
        );
      }
    }

    // Check if there's already an initState method in the original class
    MethodDeclaration? existingInitState;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'initState') {
        existingInitState = member;
        break;
      }
    }

    // Generate reactive fields by analyzing the original AST
    final reactiveFields = <String>[];
    final effectFieldNames =
        <String>[]; // Track Effect field names for initState()

    // Initialize transformers to generate reactive field declarations
    final stateTransformer = SolidStateTransformer();
    final computedTransformer = SolidComputedTransformer();
    final effectTransformer = SolidEffectTransformer();
    final queryTransformer = SolidQueryTransformer();
    final environmentTransformer = EnvironmentTransformer();

    for (final member in classDeclaration.members) {
      if (member is FieldDeclaration) {
        // Transform @SolidState fields to Signal declarations
        if (stateTransformer.canTransform(member)) {
          final result = stateTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            reactiveFields.add('  ${success.value}');
          }
        }
        // Transform @Environment fields to context.read<T>() declarations
        else if (environmentTransformer.canTransform(member)) {
          final result = environmentTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            reactiveFields.add('  ${success.value}');
          }
        }
      } else if (member is MethodDeclaration) {
        String? transformation;

        // Check for reactive getters (Computed)
        if (computedTransformer.canTransform(member)) {
          final result = computedTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
          }
        }
        // Check for reactive effects
        else if (effectTransformer.canTransform(member)) {
          final result = effectTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
            // Track Effect field name for initState() initialization
            effectFieldNames.add(member.name.lexeme);
          }
        }
        // Check for queries (Resources)
        else if (queryTransformer.canTransform(member)) {
          final result = queryTransformer.transform(member);
          if (result.isSuccess) {
            final success = result as Success<String, dynamic>;
            transformation = success.value;
          }
        }

        if (transformation != null) {
          reactiveFields.add('  $transformation');
        }
      }
    }

    // Build the new StatefulWidget and State classes with proper formatting
    final buffer = StringBuffer();
    buffer.writeln('class $className extends StatefulWidget {');
    buffer.writeln('  $constructor');
    buffer.writeln('');
    buffer.writeln('  @override');
    buffer.writeln('  State<$className> createState() => $stateName();');
    buffer.writeln('}');
    buffer.writeln('');
    buffer.writeln('class $stateName extends State<$className> {');

    // Add reactive fields with proper indentation
    for (final field in reactiveFields) {
      buffer.writeln(field);
    }

    // Add or modify initState() method if there are Effects that need initialization
    if (effectFieldNames.isNotEmpty) {
      if (existingInitState != null) {
        // Modify existing initState() method to add Effect references
        final modifiedInitState = _modifyExistingInitState(
          content,
          existingInitState,
          effectFieldNames,
          className,
        );
        if (modifiedInitState != null) {
          buffer.writeln('');
          buffer.write(modifiedInitState);
        }
      } else {
        // Create a new initState() method
        buffer.writeln('');
        buffer.writeln('  @override');
        buffer.writeln('  initState() {');
        buffer.writeln('    super.initState();');
        for (final effectName in effectFieldNames) {
          buffer.writeln(
            '    $effectName;',
          ); // Reference the Effect to force initialization
        }
        buffer.writeln('  }');
      }
    }

    // Add or modify dispose method for reactive cleanup
    if (reactiveFields.isNotEmpty) {
      // Extract field names from reactive field declarations
      final reactiveFieldNames = <String>[];
      for (final field in reactiveFields) {
        final match = RegExp(r'final\s+(\w+)\s*=').firstMatch(field.trim());
        if (match != null) {
          reactiveFieldNames.add(match.group(1)!);
        } else {
          final lateMatch = RegExp(
            r'late\s+final\s+(\w+)\s*=',
          ).firstMatch(field.trim());
          if (lateMatch != null) {
            reactiveFieldNames.add(lateMatch.group(1)!);
          }
        }
      }

      // Create a new dispose() method (existing dispose will be handled by the separate dispose logic)
      final disposeMethod = _generateDisposeMethodForStatefulWidget(
        reactiveFields,
      );
      if (disposeMethod.isNotEmpty) {
        buffer.writeln('');
        buffer.write(disposeMethod);
      }
    }

    // Add properly formatted build method
    buffer.writeln('');
    buffer.write(buildMethod);
    buffer.writeln(''); // Empty line after build method
    buffer.writeln('}'); // Close the State class

    final newClasses = buffer.toString();

    // Find and replace the entire original class with the new structure
    final result = _replaceEntireClass(content, className, newClasses);
    return result;
  }

  /// Replaces the entire original class with new class structure
  String _replaceEntireClass(
    String content,
    String className,
    String newClassesContent,
  ) {
    final lines = content.split('\n');
    int classStartLine = -1;
    int classEndLine = -1;

    // Find the start of the class
    for (int i = 0; i < lines.length; i++) {
      if (lines[i].contains('class $className extends StatelessWidget')) {
        classStartLine = i;
        break;
      }
    }

    if (classStartLine == -1) return content; // Class not found

    // Find the end of the class by tracking braces carefully
    int classBraceDepth = 0;
    bool foundFirstBrace = false;

    for (int i = classStartLine; i < lines.length; i++) {
      final line = lines[i];

      // Count braces
      for (int j = 0; j < line.length; j++) {
        if (line[j] == '{') {
          classBraceDepth++;
          foundFirstBrace = true;
        } else if (line[j] == '}') {
          classBraceDepth--;
        }
      }

      // If we found the opening brace and now we're back to 0, this is the end
      if (foundFirstBrace && classBraceDepth == 0) {
        classEndLine = i;
        break;
      }
    }

    if (classEndLine == -1) return content; // End not found

    // Replace the class content
    final beforeClass = lines.sublist(0, classStartLine);
    final afterClass = classEndLine + 1 < lines.length
        ? lines.sublist(classEndLine + 1)
        : <String>[];

    final result = [
      ...beforeClass,
      newClassesContent
          .trimRight(), // Remove trailing newline to avoid double spacing
      ...afterClass,
    ].join('\n');

    return result;
  }

  /// Modifies an existing initState() method to add Effect references
  /// while preserving the user's existing logic
  String? _modifyExistingInitState(
    String content,
    MethodDeclaration existingInitState,
    List<String> effectFieldNames,
    String className,
  ) {
    try {
      // Extract the existing initState method from the content
      final lines = content.split('\n');
      bool inTargetClass = false;
      bool foundInitState = false;
      int braceDepth = 0;
      final initStateLines = <String>[];
      int baseIndentation = 0;
      bool foundSuperCall = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className extends')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the initState method
          if (line.trim().startsWith('@override') &&
              i + 1 < lines.length &&
              lines[i + 1].trim().startsWith('initState(')) {
            foundInitState = true;
            initStateLines.add('  @override');
            continue;
          }

          if (line.trim().startsWith('initState(')) {
            foundInitState = true;
            if (initStateLines.isEmpty) {
              initStateLines.add('  @override'); // Add @override if not present
            }
            baseIndentation = line.length - line.trimLeft().length;
            initStateLines.add('  initState() {');

            // Track braces
            final openBraces = line.split('{').length - 1;
            braceDepth += openBraces;
            continue;
          }

          if (foundInitState && braceDepth > 0) {
            // Process the initState method body
            if (line.trim().isEmpty) {
              initStateLines.add('');
            } else {
              // Calculate relative indentation
              final currentIndent = line.length - line.trimLeft().length;
              final relativeIndent = math.max(
                0,
                currentIndent - baseIndentation,
              );
              final formattedLine = '    ${' ' * relativeIndent}${line.trim()}';
              initStateLines.add(formattedLine);

              // Check if this is the super.initState() call
              if (line.trim().startsWith('super.initState()')) {
                foundSuperCall = true;
                // Add Effect references after super.initState()
                for (final effectName in effectFieldNames) {
                  initStateLines.add('    $effectName;');
                }
              }
            }

            // Track braces to know when the method ends
            final openBraces = line.split('{').length - 1;
            final closeBraces = line.split('}').length - 1;
            braceDepth += openBraces;
            braceDepth -= closeBraces;

            // If we've closed all method braces, we're done
            if (braceDepth == 0) {
              break;
            }
          }
        }
      }

      // If we didn't find a super.initState() call, add it and the Effect references at the beginning
      if (foundInitState && !foundSuperCall) {
        // Insert super.initState() and Effect references after the opening brace
        final modifiedLines = <String>[];
        bool addedSuperCall = false;

        for (int i = 0; i < initStateLines.length; i++) {
          final line = initStateLines[i];
          modifiedLines.add(line);

          // Add super.initState() and Effect references after the opening brace
          if (line.trim() == 'initState() {' && !addedSuperCall) {
            modifiedLines.add('    super.initState();');
            for (final effectName in effectFieldNames) {
              modifiedLines.add('    $effectName;');
            }
            addedSuperCall = true;
          }
        }

        return modifiedLines.join('\n');
      }

      return initStateLines.isNotEmpty ? initStateLines.join('\n') : null;
    } catch (e) {
      // If parsing fails, return null to fall back to creating a new initState
      return null;
    }
  }

  /// Extracts the properly formatted build method from the original source content
  String? _extractFormattedBuildMethod(String content, String className) {
    final lines = content.split('\n');
    bool inTargetClass = false;
    bool foundBuildMethod = false;
    int braceDepth = 0;
    final buildMethodLines = <String>[];
    int baseIndentation = 0;

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (line.contains('class $className extends StatelessWidget')) {
        inTargetClass = true;
        continue;
      }

      if (inTargetClass) {
        // Exit if we reach another class
        if (line.trim().startsWith('class ') && !line.contains(className)) {
          break;
        }

        // Look for the build method
        if (line.trim().startsWith('@override') &&
            i + 1 < lines.length &&
            lines[i + 1].trim().startsWith('Widget build(')) {
          foundBuildMethod = true;
          buildMethodLines.add('  @override');
          continue;
        }

        if (line.trim().startsWith('Widget build(')) {
          foundBuildMethod = true;
          if (buildMethodLines.isEmpty) {
            buildMethodLines.add('  @override'); // Add @override if not present
          }
          baseIndentation = line.length - line.trimLeft().length;
          buildMethodLines.add('  Widget build(BuildContext context) {');

          // Track braces
          final openBraces = line.split('{').length - 1;
          braceDepth += openBraces;
          continue;
        }

        if (foundBuildMethod && braceDepth > 0) {
          // Process the build method body
          if (line.trim().isEmpty) {
            buildMethodLines.add('');
          } else {
            // Calculate relative indentation
            final currentIndent = line.length - line.trimLeft().length;
            final relativeIndent = math.max(0, currentIndent - baseIndentation);
            buildMethodLines.add('    ${' ' * relativeIndent}${line.trim()}');
          }

          // Track braces to know when the method ends
          final openBraces = line.split('{').length - 1;
          final closeBraces = line.split('}').length - 1;
          braceDepth += openBraces;
          braceDepth -= closeBraces;

          // If we've closed all method braces, we're done
          if (braceDepth == 0) {
            break;
          }
        }
      }
    }

    return buildMethodLines.isNotEmpty ? buildMethodLines.join('\n') : null;
  }

  /// Wraps UI components that access Signals with SignalBuilder for fine-grained reactivity
  /// Using pattern matching with special handling for Resource method calls
  String _wrapSignalAccessWithBuilder(
    String content,
    Set<String> signalFieldNames,
  ) {
    // Use the working pattern-based approach with Resource method call support
    return _wrapCustomWidgetsWithReactiveAccess(content, signalFieldNames);
  }

  /// Wraps ANY widget that accesses reactive values with SignalBuilder using unified approach
  String _wrapCustomWidgetsWithReactiveAccess(
    String content,
    Set<String> signalFieldNames,
  ) {
    // Skip SignalBuilder wrapping if content already contains SignalBuilder in the build method
    if (content.contains('SignalBuilder(') &&
        content.contains('builder: (context, child)')) {
      return content; // Already transformed, skip further SignalBuilder wrapping
    }

    // First, handle multi-line Resource method calls
    String transformedContent = _wrapResourceMethodCalls(
      content,
      signalFieldNames,
    );

    // Then handle single-line widget calls
    final lines = transformedContent.split('\n');
    final resultLines = <String>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];

      // Look for lines that contain widget constructor calls
      // Pattern: WidgetName( or _WidgetName( (widget constructors)
      // This should match actual constructor calls, not method calls
      final widgetCallPattern = RegExp(r'(\s*)(?:return\s+)?([A-Z]\w*)\s*\(');
      final match = widgetCallPattern.firstMatch(line);

      if (match != null) {
        // Skip annotation lines (starting with @)
        if (line.trim().startsWith('@')) {
          resultLines.add(line);
          continue;
        }

        // Skip constructor definitions (containing super.key, required, const)
        if (line.contains('super.key') ||
            line.contains('required ') ||
            line.contains('const ')) {
          resultLines.add(line);
          continue;
        }

        final indentation = match.group(1) ?? '';
        final widgetName = match.group(2) ?? '';

        // Skip if this is clearly a method call (has a dot before the matched name)
        if (line.contains('.$widgetName(')) {
          resultLines.add(line);
          continue;
        }

        // Skip non-widget classes
        if (['Navigator', 'Future', 'Stream', 'Duration', 'Timer', 'Named', 'AllMapped', 'UpperCase', 'RegExp', 'At', 'Data', 'Counter'].contains(widgetName)) {
          resultLines.add(line);
          continue;
        }

        // Skip parameter assignments (lines containing : before =>)
        if (line.contains(':') && line.contains('=>')) {
          resultLines.add(line);
          continue;
        }

        // Check if the line contains reactive field references AND is a widget constructor
        bool containsReactiveAccess = false;

        // First check if this is actually a widget constructor line
        bool isWidgetConstructor = true; // Assume it's a widget if we got this far


        // Only check for reactive access if this is actually a widget constructor
        if (isWidgetConstructor) {
          for (final fieldName in signalFieldNames) {
            if (line.contains('\$$fieldName') ||
                line.contains('\${$fieldName') ||
                line.contains('$fieldName.') ||
                line.contains('$fieldName,') ||
                line.contains('$fieldName)')) {
              containsReactiveAccess = true;
              break;
            }
          }
        }

        // Handle parameter assignments containing reactive widgets
        // Examples: body: Text(...), child: Widget(...), etc.
        if (line.contains(':') && containsReactiveAccess) {
          final trimmedLine = line.trim();
          final colonIndex = trimmedLine.indexOf(':');

          if (colonIndex > 0) {
            final beforeColon = trimmedLine.substring(
              0,
              colonIndex + 1,
            ); // e.g., "body:"
            final afterColon = trimmedLine
                .substring(colonIndex + 1)
                .trim(); // e.g., "Text(...)"

            // Check if after colon starts with a widget constructor
            final widgetPattern = RegExp(r'^[A-Z]\w*\s*\(');
            if (widgetPattern.hasMatch(afterColon)) {
              // Extract widget constructor with balanced parentheses
              String widgetPart = '';
              String remainingPart = '';

              // Find the start of the widget constructor
              final startMatch = RegExp(
                r'^([A-Z]\w*\s*\()',
              ).firstMatch(afterColon);
              if (startMatch != null) {
                int startIndex = startMatch.end;
                int parenCount = 1; // We already have one opening paren

                // Find the matching closing parenthesis
                for (
                  int i = startIndex;
                  i < afterColon.length && parenCount > 0;
                  i++
                ) {
                  final char = afterColon[i];
                  if (char == '(') {
                    parenCount++;
                  } else if (char == ')') {
                    parenCount--;
                  }

                  if (parenCount == 0) {
                    // Found the matching closing paren
                    widgetPart = afterColon.substring(0, i + 1);
                    remainingPart = afterColon.substring(i + 1);
                    break;
                  }
                }

                if (widgetPart.isNotEmpty) {
                  // Wrap just the widget constructor
                  resultLines.add('$indentation$beforeColon SignalBuilder(');
                  resultLines.add('$indentation  builder: (context, child) {');
                  resultLines.add('$indentation    return $widgetPart;');
                  resultLines.add('$indentation  },');
                  resultLines.add('$indentation)$remainingPart');
                  continue;
                }
              }
            }
          }
        }

        if (containsReactiveAccess) {
          // Clean up the line for proper return statement formatting
          String cleanedLine = line.trim();
          bool wasReturnStatement = false;

          // Check if this was a return statement
          if (cleanedLine.startsWith('return ')) {
            wasReturnStatement = true;
            cleanedLine = cleanedLine.substring(7); // Remove 'return '
          }

          // Remove trailing semicolon and comma
          if (cleanedLine.endsWith(';')) {
            cleanedLine = cleanedLine.substring(0, cleanedLine.length - 1);
          }
          if (cleanedLine.endsWith(',')) {
            cleanedLine = cleanedLine.substring(0, cleanedLine.length - 1);
          }

          // Create SignalBuilder wrapper for ANY widget accessing reactive values
          String transformedLine = cleanedLine;

          if (wasReturnStatement) {
            resultLines.add('${indentation}return SignalBuilder(');
            resultLines.add('$indentation  builder: (context, child) {');
            resultLines.add('$indentation    return $transformedLine;');
            resultLines.add('$indentation  },');
            resultLines.add('$indentation);');
          } else {
            resultLines.add('${indentation}SignalBuilder(');
            resultLines.add('$indentation  builder: (context, child) {');
            resultLines.add('$indentation    return $transformedLine;');
            resultLines.add('$indentation  },');
            resultLines.add('$indentation),');
          }
        } else {
          resultLines.add(line);
        }
      } else {
        resultLines.add(line);
      }
    }

    return resultLines.join('\n');
  }

  /// Wraps Resource method calls with SignalBuilder
  String _wrapResourceMethodCalls(
    String content,
    Set<String> signalFieldNames,
  ) {
    String transformedContent = content;

    for (final fieldName in signalFieldNames) {
      // Pattern to match Resource method calls that should be wrapped
      // Example: return fetchData().on(...) or fetchData().when(...) or fetchData().maybeWhen(...)
      final resourceCallPattern = RegExp(
        r'(\s*)((?:return\s+)?' +
            fieldName +
            r'\(\)\.(on|when|maybeWhen)\(((?:[^()]|\((?:[^()]|\([^()]*\))*\))*)\);?)',
        multiLine: true,
        dotAll: true,
      );

      transformedContent = transformedContent.replaceAllMapped(
        resourceCallPattern,
        (match) {
          final indentation = match.group(1) ?? '';
          final fullMatch = match.group(0) ?? '';
          final resourceCallWithOn = match.group(2) ?? '';
          final methodName = match.group(3) ?? ''; // on, when, or maybeWhen
          final methodCallContent = match.group(4) ?? '';

          // Check if this Resource call is already inside a SignalBuilder by looking at surrounding context
          final beforeMatch = content.substring(0, match.start);
          final lines = beforeMatch.split('\n');
          final recentLines = lines.length > 10
              ? lines.sublist(lines.length - 10).join('\n')
              : beforeMatch;
          final isAlreadyWrapped =
              recentLines.contains('SignalBuilder(') &&
              recentLines.contains('builder: (context, child)');

          // Only wrap if not already wrapped
          if (!isAlreadyWrapped) {
            // Check if this is a return statement
            final isReturnStatement = resourceCallWithOn.trim().startsWith(
              'return',
            );

            if (isReturnStatement) {
              // Handle return statement case
              final resourceCall =
                  '$fieldName().$methodName($methodCallContent)';
              return '${indentation}return SignalBuilder(\n'
                  '$indentation  builder: (context, child) {\n'
                  '$indentation    return $resourceCall;\n'
                  '$indentation  },\n'
                  '$indentation);';
            } else {
              // Handle widget tree case (inside Column children, etc.)
              final resourceCall =
                  '$fieldName().$methodName($methodCallContent)';
              final hasCommaOrSemicolon =
                  fullMatch.endsWith(',') || fullMatch.endsWith(';');
              final punctuation = hasCommaOrSemicolon
                  ? fullMatch.substring(fullMatch.length - 1)
                  : '';

              return '${indentation}SignalBuilder(\n'
                  '$indentation  builder: (context, child) {\n'
                  '$indentation    return $resourceCall;\n'
                  '$indentation  },\n'
                  '$indentation)$punctuation';
            }
          } else {
            return fullMatch; // Return original if already wrapped
          }
        },
      );
    }

    return transformedContent;
  }

  /// Transforms signal variable access patterns
  /// Direct signals: counter++ → counter.value++
  /// Object signals: myData.value++ → myData.value.value++ (value is reactive field in myData)
  String _transformSignalAccess(
    String content,
    Set<String> signalFieldNames,
    Set<String> environmentFieldNames,
  ) {
    String transformedContent = content;

    // First, handle direct signal access (signals declared directly in the class)
    for (final fieldName in signalFieldNames) {
      // Skip environment field names - they're handled separately
      if (environmentFieldNames.contains(fieldName)) {
        continue;
      }

      // Skip transforming 'value' as it causes conflicts with property access
      if (fieldName == 'value') {
        continue;
      }

      // Transform increment/decrement operators for direct signals
      transformedContent = transformedContent.replaceAll(
        '$fieldName++',
        '$fieldName.value++',
      );
      transformedContent = transformedContent.replaceAll(
        '++$fieldName',
        '++$fieldName.value',
      );
      transformedContent = transformedContent.replaceAll(
        '$fieldName--',
        '$fieldName.value--',
      );
      transformedContent = transformedContent.replaceAll(
        '--$fieldName',
        '--$fieldName.value',
      );

      // Transform assignment operators (but not in declarations)
      final assignmentPattern = RegExp(
        r'(?<!final\s)(?<!final\s+\w+\s*=\s*)\b' +
            fieldName +
            r'\s*([\+\-\*\/\~\%]=)',
      );
      transformedContent = transformedContent.replaceAllMapped(
        assignmentPattern,
        (match) {
          return '$fieldName.value ${match.group(1)}';
        },
      );

      // Transform direct assignment (but not in declarations)
      final directAssignmentPattern = RegExp(
        r'(?<!final\s)(?<!final\s+)\b' +
            fieldName +
            r'\s*=\s*(?!Signal)(?!Computed)',
      );
      transformedContent = transformedContent.replaceAllMapped(
        directAssignmentPattern,
        (match) {
          // Double check this isn't in a declaration line
          final start = match.start;
          final beforeMatch = transformedContent.substring(0, start);
          final currentLine = beforeMatch.split('\n').last;

          if (currentLine.trim().startsWith('final ')) {
            return match.group(0)!; // Don't transform declarations
          }

          return '$fieldName.value =';
        },
      );

      // Transform string interpolation for direct signals
      transformedContent = _transformStringInterpolationSafely(
        transformedContent,
        fieldName,
      );
    }

    // Handle environment fields that access reactive properties
    // Pattern: environmentField.reactiveProperty → environmentField.reactiveProperty.value
    for (final envFieldName in environmentFieldNames) {
      // Transform all reactive property access through environment fields
      // Use more comprehensive pattern matching to catch all cases

      // 1. Handle increment/decrement operators (avoid double transformation)
      final envIncrementPattern = RegExp(
        r'\b' + RegExp.escape(envFieldName) + r'\.value(?!\.value)\+\+',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envIncrementPattern,
        (match) => '$envFieldName.value.value++',
      );

      final envPreIncrementPattern = RegExp(
        r'\+\+' + RegExp.escape(envFieldName) + r'\.value(?!\.value)',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envPreIncrementPattern,
        (match) => '++$envFieldName.value.value',
      );

      final envDecrementPattern = RegExp(
        r'\b' + RegExp.escape(envFieldName) + r'\.value(?!\.value)\-\-',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envDecrementPattern,
        (match) => '$envFieldName.value.value--',
      );

      final envPreDecrementPattern = RegExp(
        r'\-\-' + RegExp.escape(envFieldName) + r'\.value(?!\.value)',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envPreDecrementPattern,
        (match) => '--$envFieldName.value.value',
      );

      // 2. Handle method calls and property access (like .toString(), .length, etc.)
      // Only match actual method calls with parentheses or property access, not increment/decrement
      final envMethodCallPattern = RegExp(
        r'\b' +
            RegExp.escape(envFieldName) +
            r'\.value\.(\w+)(\(|\b(?!\+\+|--|\.value))',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envMethodCallPattern,
        (match) =>
            '$envFieldName.value.value.${match.group(1)}${match.group(2)}',
      );

      // 3. Handle comparison operations (avoid double transformation)
      final envValueComparisonPattern = RegExp(
        r'\b' +
            RegExp.escape(envFieldName) +
            r'\.value(?!\.value)\s*([=!<>]+)\s*',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envValueComparisonPattern,
        (match) => '$envFieldName.value.value ${match.group(1)} ',
      );

      // 4. Handle assignment operations (avoid double transformation)
      final envValueAssignmentPattern = RegExp(
        r'\b' + RegExp.escape(envFieldName) + r'\.value(?!\.value)\s*=\s*',
      );
      transformedContent = transformedContent.replaceAllMapped(
        envValueAssignmentPattern,
        (match) => '$envFieldName.value.value = ',
      );
    }

    return transformedContent;
  }

  /// Transforms string interpolation safely, applying transformations inside SignalBuilder blocks
  String _transformStringInterpolationSafely(String content, String fieldName) {
    // Split content into segments: outside and inside SignalBuilder blocks
    final parts = <String>[];
    final shouldTransform = <bool>[];

    int currentIndex = 0;

    // Find all SignalBuilder blocks
    while (currentIndex < content.length) {
      final signalBuilderStart = content.indexOf(
        'SignalBuilder(',
        currentIndex,
      );

      if (signalBuilderStart == -1) {
        // No more SignalBuilder blocks, add remaining content (don't transform outside SignalBuilder)
        parts.add(content.substring(currentIndex));
        shouldTransform.add(false);
        break;
      }

      // Add content before SignalBuilder (don't transform outside SignalBuilder)
      if (signalBuilderStart > currentIndex) {
        parts.add(content.substring(currentIndex, signalBuilderStart));
        shouldTransform.add(false);
      }

      // Find the end of this SignalBuilder block by counting braces
      int braceCount = 0;
      int searchStart = signalBuilderStart;
      int signalBuilderEnd = signalBuilderStart;

      for (int i = searchStart; i < content.length; i++) {
        if (content[i] == '(') {
          braceCount++;
        } else if (content[i] == ')') {
          braceCount--;
          if (braceCount == 0) {
            signalBuilderEnd = i + 1;
            break;
          }
        }
      }

      // Add the SignalBuilder block (transform inside SignalBuilder)
      parts.add(content.substring(signalBuilderStart, signalBuilderEnd));
      shouldTransform.add(true);

      currentIndex = signalBuilderEnd;
    }

    // Now transform only the parts that are inside SignalBuilder blocks
    final result = StringBuffer();
    for (int i = 0; i < parts.length; i++) {
      final part = parts[i];
      if (shouldTransform[i]) {
        // Transform string interpolation in this part
        final interpolationPattern = RegExp(
          r'\$' + fieldName + r'(?!\.value)(?!\w)',
        );
        final transformedPart = part.replaceAllMapped(
          interpolationPattern,
          (match) => '\${$fieldName.value}',
        );
        result.write(transformedPart);
      } else {
        // Don't transform content outside SignalBuilder
        result.write(part);
      }
    }

    return result.toString();
  }

  /// Formats Dart code using dart format
  Future<String> _formatDartCode(String code) async {
    try {
      // Write code to a temporary file
      final tempDir = Directory.systemTemp.createTempSync('solid_generator_');
      final tempFile = File('${tempDir.path}/temp.dart');
      await tempFile.writeAsString(code);

      // Run dart format on the temporary file
      final result = await Process.run('dart', [
        'format',
        tempFile.path,
      ], workingDirectory: tempDir.path);

      if (result.exitCode == 0) {
        // Read the formatted content
        final formattedCode = await tempFile.readAsString();

        // Clean up
        await tempDir.delete(recursive: true);

        return formattedCode;
      } else {
        log.warning('dart format failed: ${result.stderr}');
        // Clean up
        await tempDir.delete(recursive: true);
        return code; // Return original code if formatting fails
      }
    } catch (e) {
      log.warning('Error formatting code: $e');
      return code; // Return original code if formatting fails
    }
  }

  /// Checks if the compilation unit has a main function that calls runApp
  bool _hasMainFunctionWithRunApp(CompilationUnit unit) {
    for (final declaration in unit.declarations) {
      if (declaration is FunctionDeclaration &&
          declaration.name.lexeme == 'main') {
        final functionBody = declaration.functionExpression.body;
        final bodySource = functionBody.toSource();
        if (bodySource.contains('runApp(')) {
          return true;
        }
      }
    }
    return false;
  }

  /// Transforms main function to add SolidartConfig.autoDispose = false; if it contains runApp
  String _transformMainFunction(String content, CompilationUnit unit) {
    // Check if there's a main function with runApp
    if (!_hasMainFunctionWithRunApp(unit)) {
      return content;
    }

    // Check if SolidartConfig.autoDispose is already present to avoid duplication
    if (content.contains('SolidartConfig.autoDispose = false;')) {
      return content;
    }

    // Use regex to find and replace the main function more precisely
    // Support both "void main" and "Future<void> main" with optional "async"
    final mainFunctionPattern = RegExp(
      r'((?:Future<void>|void)\s+main\s*\(\s*\)\s*(?:async\s*)?\{)(\s*)',
      multiLine: true,
    );

    return content.replaceAllMapped(mainFunctionPattern, (match) {
      final opening = match.group(
        1,
      )!; // "void main() {" or "Future<void> main() {"
      final whitespace = match.group(2) ?? '';

      // Determine the indentation for the function body
      final indentation = whitespace.isNotEmpty ? whitespace : '\n  ';

      return '$opening$indentation  SolidartConfig.autoDispose = false;';
    });
  }

  /// Adds dispose method to a class for reactive cleanup
  String _addDisposeMethodToClass(
    String content,
    ClassDeclaration classDeclaration,
  ) {
    // Extract reactive field names that need disposal
    final reactiveFieldNames = _extractReactiveFieldNamesFromClass(
      classDeclaration,
    );

    if (reactiveFieldNames.isEmpty) {
      return content; // No reactive fields, no disposal needed
    }

    // Check if this is a StatefulWidget state class
    final className = classDeclaration.name.lexeme;
    final isStatefulWidget = _isStatefulWidgetStateClass(content, className);

    if (isStatefulWidget) {
      // Handle StatefulWidget state class dispose method
      return _handleDisposeMethodForStatefulWidgetState(
        content,
        classDeclaration,
        reactiveFieldNames,
      );
    } else {
      // Handle regular class dispose method
      return _handleDisposeMethodForRegularClass(
        content,
        classDeclaration,
        reactiveFieldNames,
      );
    }
  }

  /// Generates dispose method for StatefulWidget state classes
  String _generateDisposeMethodForStatefulWidget(List<String> reactiveFields) {
    if (reactiveFields.isEmpty) {
      return '';
    }

    // Extract field names from reactive field declarations
    // Exclude environment fields (those that use context.read) from disposal
    final fieldNames = <String>[];
    for (final field in reactiveFields) {
      // Skip environment fields - they use context.read and should not be disposed
      if (field.contains('context.read<')) {
        continue;
      }

      final match = RegExp(r'final\s+(\w+)\s*=').firstMatch(field.trim());
      if (match != null) {
        fieldNames.add(match.group(1)!);
      } else {
        final lateMatch = RegExp(
          r'late\s+final\s+(\w+)\s*=',
        ).firstMatch(field.trim());
        if (lateMatch != null) {
          fieldNames.add(lateMatch.group(1)!);
        }
      }
    }

    if (fieldNames.isEmpty) {
      return '';
    }

    final buffer = StringBuffer();
    buffer.writeln('  @override');
    buffer.writeln('  void dispose() {');

    for (final fieldName in fieldNames) {
      buffer.writeln('    $fieldName.dispose();');
    }

    buffer.writeln('    super.dispose();');
    buffer.writeln('  }');

    return buffer.toString();
  }

  /// Handles dispose method for StatefulWidget state classes
  String _handleDisposeMethodForStatefulWidgetState(
    String content,
    ClassDeclaration classDeclaration,
    List<String> reactiveFieldNames,
  ) {
    final className = classDeclaration.name.lexeme;

    // Check if there's already a dispose method in the class
    MethodDeclaration? existingDispose;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        existingDispose = member;
        break;
      }
    }

    if (existingDispose != null) {
      // Modify existing dispose() method to add reactive cleanup
      final modifiedDispose = _modifyExistingDisposeMethod(
        content,
        existingDispose,
        reactiveFieldNames,
        className,
        isStatefulWidget: true,
      );
      if (modifiedDispose != null) {
        // Replace the existing dispose method in the content
        return _replaceExistingDisposeMethodInContent(
          content,
          existingDispose,
          modifiedDispose,
          className,
        );
      }
    } else {
      // Create a new dispose() method for the StatefulWidget state class
      return _addNewDisposeMethodToStatefulWidgetState(
        content,
        className,
        reactiveFieldNames,
      );
    }

    return content;
  }

  /// Handles dispose method for regular classes
  String _handleDisposeMethodForRegularClass(
    String content,
    ClassDeclaration classDeclaration,
    List<String> reactiveFieldNames,
  ) {
    final className = classDeclaration.name.lexeme;

    // Check if there's already a dispose method in the class
    MethodDeclaration? existingDispose;
    for (final member in classDeclaration.members) {
      if (member is MethodDeclaration && member.name.lexeme == 'dispose') {
        existingDispose = member;
        break;
      }
    }

    if (existingDispose != null) {
      // Modify existing dispose() method to add reactive cleanup
      final modifiedDispose = _modifyExistingDisposeMethod(
        content,
        existingDispose,
        reactiveFieldNames,
        className,
        isStatefulWidget: false,
      );
      if (modifiedDispose != null) {
        // Replace the existing dispose method in the content
        return _replaceExistingDisposeMethodInContent(
          content,
          existingDispose,
          modifiedDispose,
          className,
        );
      }
    } else {
      // Create a new dispose() method for the regular class
      return _addNewDisposeMethodToRegularClass(
        content,
        className,
        reactiveFieldNames,
      );
    }

    return content;
  }

  /// Extracts reactive field names from a class declaration
  List<String> _extractReactiveFieldNamesFromClass(
    ClassDeclaration classDeclaration,
  ) {
    final reactiveFieldNames = <String>[];

    // Initialize transformers to check which fields are reactive
    final stateTransformer = SolidStateTransformer();
    final computedTransformer = SolidComputedTransformer();
    final effectTransformer = SolidEffectTransformer();
    final queryTransformer = SolidQueryTransformer();

    for (final member in classDeclaration.members) {
      if (member is FieldDeclaration) {
        // Check @SolidState fields only - @Environment fields should not be disposed
        if (stateTransformer.canTransform(member)) {
          for (final variable in member.fields.variables) {
            reactiveFieldNames.add(variable.name.lexeme);
          }
        }
      } else if (member is MethodDeclaration) {
        // Check for reactive getters, effects, and queries
        if (computedTransformer.canTransform(member) ||
            effectTransformer.canTransform(member) ||
            queryTransformer.canTransform(member)) {
          reactiveFieldNames.add(member.name.lexeme);
        }
      }
    }

    return reactiveFieldNames;
  }

  /// Checks if a class is a StatefulWidget state class
  bool _isStatefulWidgetStateClass(String content, String className) {
    return content.contains('class $className extends State<');
  }

  /// Modifies an existing dispose() method to add reactive cleanup
  String? _modifyExistingDisposeMethod(
    String content,
    MethodDeclaration existingDispose,
    List<String> reactiveFieldNames,
    String className, {
    required bool isStatefulWidget,
  }) {
    try {
      // Extract the existing dispose method from the content
      final lines = content.split('\n');
      bool inTargetClass = false;
      bool foundDispose = false;
      int braceDepth = 0;
      final disposeLines = <String>[];
      int baseIndentation = 0;
      bool foundSuperCall = false;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className extends') ||
            line.contains('class $className ')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the dispose method
          if (line.trim().startsWith('@override') &&
              i + 1 < lines.length &&
              lines[i + 1].trim().startsWith('void dispose(')) {
            foundDispose = true;
            disposeLines.add('  @override');
            continue;
          }

          if (line.trim().startsWith('void dispose(')) {
            foundDispose = true;
            if (disposeLines.isEmpty && isStatefulWidget) {
              disposeLines.add(
                '  @override',
              ); // Add @override only for StatefulWidget
            }
            baseIndentation = line.length - line.trimLeft().length;
            disposeLines.add('  void dispose() {');

            // Track braces
            final openBraces = line.split('{').length - 1;
            braceDepth += openBraces;
            continue;
          }

          if (foundDispose && braceDepth > 0) {
            // Process the dispose method body
            if (line.trim().isEmpty) {
              disposeLines.add('');
            } else {
              // Calculate relative indentation
              final currentIndent = line.length - line.trimLeft().length;
              final relativeIndent = math.max(
                0,
                currentIndent - baseIndentation,
              );
              final formattedLine = '    ${' ' * relativeIndent}${line.trim()}';

              // Check if this is the super.dispose() call
              if (line.trim().startsWith('super.dispose()')) {
                foundSuperCall = true;
                // Add reactive cleanup before super.dispose()
                for (final fieldName in reactiveFieldNames) {
                  disposeLines.add('    $fieldName.dispose();');
                }
                disposeLines.add(formattedLine);
              } else {
                disposeLines.add(formattedLine);
              }
            }

            // Track braces to know when the method ends
            final openBraces = line.split('{').length - 1;
            final closeBraces = line.split('}').length - 1;
            braceDepth += openBraces;
            braceDepth -= closeBraces;

            // If we've closed all method braces, we're done
            if (braceDepth == 0) {
              break;
            }
          }
        }
      }

      // If we didn't find a super.dispose() call for StatefulWidget, add reactive cleanup and super.dispose()
      if (foundDispose && isStatefulWidget && !foundSuperCall) {
        // Insert reactive cleanup and super.dispose() before the closing brace
        final modifiedLines = <String>[];

        for (int i = 0; i < disposeLines.length; i++) {
          final line = disposeLines[i];

          // If this is the last line (closing brace), add cleanup before it
          if (i == disposeLines.length - 1 && line.trim() == '}') {
            for (final fieldName in reactiveFieldNames) {
              modifiedLines.add('    $fieldName.dispose();');
            }
            modifiedLines.add('    super.dispose();');
            modifiedLines.add(line);
          } else {
            modifiedLines.add(line);
          }
        }

        return modifiedLines.join('\n');
      } else if (foundDispose && !isStatefulWidget && !foundSuperCall) {
        // For regular classes, just add reactive cleanup before the closing brace
        final modifiedLines = <String>[];

        for (int i = 0; i < disposeLines.length; i++) {
          final line = disposeLines[i];

          // If this is the last line (closing brace), add cleanup before it
          if (i == disposeLines.length - 1 && line.trim() == '}') {
            for (final fieldName in reactiveFieldNames) {
              modifiedLines.add('    $fieldName.dispose();');
            }
            modifiedLines.add(line);
          } else {
            modifiedLines.add(line);
          }
        }

        return modifiedLines.join('\n');
      }

      return disposeLines.isNotEmpty ? disposeLines.join('\n') : null;
    } catch (e) {
      // If parsing fails, return null to fall back to creating a new dispose
      return null;
    }
  }

  /// Replaces an existing dispose method in the content with the modified version
  String _replaceExistingDisposeMethodInContent(
    String content,
    MethodDeclaration existingDispose,
    String modifiedDispose,
    String className,
  ) {
    try {
      final lines = content.split('\n');
      bool inTargetClass = false;
      bool foundDispose = false;
      int braceDepth = 0;
      int startLine = -1;
      int endLine = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className extends') ||
            line.contains('class $className ')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the dispose method
          if ((line.trim().startsWith('@override') &&
                  i + 1 < lines.length &&
                  lines[i + 1].trim().startsWith('void dispose(')) ||
              line.trim().startsWith('void dispose(')) {
            if (line.trim().startsWith('@override')) {
              startLine = i;
              foundDispose = true;
            } else if (line.trim().startsWith('void dispose(')) {
              startLine = foundDispose ? startLine : i;
              foundDispose = true;
              // Track braces
              final openBraces = line.split('{').length - 1;
              braceDepth += openBraces;
            }
            continue;
          }

          if (foundDispose && braceDepth > 0) {
            // Track braces to know when the method ends
            final openBraces = line.split('{').length - 1;
            final closeBraces = line.split('}').length - 1;
            braceDepth += openBraces;
            braceDepth -= closeBraces;

            // If we've closed all method braces, we're done
            if (braceDepth == 0) {
              endLine = i;
              break;
            }
          }
        }
      }

      if (startLine != -1 && endLine != -1) {
        // Replace the dispose method
        final beforeDispose = lines.sublist(0, startLine);
        final afterDispose = endLine + 1 < lines.length
            ? lines.sublist(endLine + 1)
            : <String>[];

        return [...beforeDispose, modifiedDispose, ...afterDispose].join('\n');
      }
    } catch (e) {
      // If parsing fails, return original content
    }

    return content;
  }

  /// Adds a new dispose() method to a StatefulWidget state class
  String _addNewDisposeMethodToStatefulWidgetState(
    String content,
    String className,
    List<String> reactiveFieldNames,
  ) {
    try {
      final lines = content.split('\n');
      bool inTargetClass = false;
      int insertionPoint = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className') ||
            line.contains('class _${className}State')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Look for the build method to insert dispose before it
          if (line.trim().startsWith('@override') &&
              i + 1 < lines.length &&
              lines[i + 1].trim().startsWith('Widget build(')) {
            insertionPoint = i;
            break;
          } else if (line.trim().startsWith('Widget build(')) {
            insertionPoint = i;
            break;
          }
        }
      }

      if (insertionPoint != -1) {
        // Insert the new dispose method
        final beforeBuild = lines.sublist(0, insertionPoint);
        final afterBuild = lines.sublist(insertionPoint);

        final newDispose = [
          '  @override',
          '  void dispose() {',
          ...reactiveFieldNames.map((name) => '    $name.dispose();'),
          '    super.dispose();',
          '  }',
          '',
        ];

        return [...beforeBuild, ...newDispose, ...afterBuild].join('\n');
      }
    } catch (e) {
      // If parsing fails, return original content
    }

    return content;
  }

  /// Adds a new dispose() method to a regular class
  String _addNewDisposeMethodToRegularClass(
    String content,
    String className,
    List<String> reactiveFieldNames,
  ) {
    try {
      final lines = content.split('\n');
      bool inTargetClass = false;
      int insertionPoint = -1;

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];

        if (line.contains('class $className')) {
          inTargetClass = true;
          continue;
        }

        if (inTargetClass) {
          // Exit if we reach another class
          if (line.trim().startsWith('class ') && !line.contains(className)) {
            break;
          }

          // Insert before the closing brace of the class
          if (line.trim() == '}' && i > 0) {
            insertionPoint = i;
            break;
          }
        }
      }

      if (insertionPoint != -1) {
        // Insert the new dispose method
        final beforeClosing = lines.sublist(0, insertionPoint);
        final afterClosing = lines.sublist(insertionPoint);

        final newDispose = [
          '',
          '  void dispose() {',
          ...reactiveFieldNames.map((name) => '    $name.dispose();'),
          '  }',
        ];

        return [...beforeClosing, ...newDispose, ...afterClosing].join('\n');
      }
    } catch (e) {
      // If parsing fails, return original content
    }

    return content;
  }
}

/// Information about a widget constructor call that accesses reactive values
class WidgetCallInfo {
  final int offset;
  final int length;
  final String widgetName;
  final List<String> reactiveDependencies;

  WidgetCallInfo({
    required this.offset,
    required this.length,
    required this.widgetName,
    required this.reactiveDependencies,
  });
}
