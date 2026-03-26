import 'dart:io';

import 'package:xml/xml.dart';

class PlistService {
  /// Parse a plist file to a Map using plutil (binary-safe).
  Future<Map<String, dynamic>> parse(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Plist file not found', path);
    }

    // Use plutil to convert to xml1 and read
    final result = await Process.run('plutil', ['-convert', 'xml1', '-o', '-', path]);
    if (result.exitCode != 0) {
      throw FormatException('Failed to parse plist: ${result.stderr}');
    }

    return _parseXmlPlist(result.stdout as String);
  }

  /// Read raw plist content as a string.
  Future<String> read(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Plist file not found', path);
    }

    // Convert to xml1 for consistent readable output
    final result = await Process.run('plutil', ['-convert', 'xml1', '-o', '-', path]);
    if (result.exitCode != 0) {
      return await file.readAsString();
    }
    return result.stdout as String;
  }

  /// Write plist content to a file.
  Future<void> write(String path, String content) async {
    final file = File(path);
    await file.writeAsString(content);

    // Validate the written file
    final result = await Process.run('plutil', ['-lint', path]);
    if (result.exitCode != 0) {
      throw FormatException('Written plist is invalid: ${result.stderr}');
    }
  }

  /// Validate plist content, returning a list of errors (empty = valid).
  Future<List<String>> validate(String content) async {
    final errors = <String>[];

    // Write to temp file for plutil validation
    final tempDir = await Directory.systemTemp.createTemp('launchpad_');
    final tempFile = File('${tempDir.path}/validate.plist');
    try {
      await tempFile.writeAsString(content);
      final result = await Process.run('plutil', ['-lint', tempFile.path]);
      if (result.exitCode != 0) {
        errors.add((result.stderr as String).trim());
      }

      // Check for required Label key
      try {
        final parsed = _parseXmlPlist(content);
        if (!parsed.containsKey('Label')) {
          errors.add('Missing required key: Label');
        }
        if (parsed['Label'] is! String ||
            (parsed['Label'] as String).isEmpty) {
          errors.add('Label must be a non-empty string');
        }
      } catch (e) {
        errors.add('XML parsing error: $e');
      }
    } finally {
      await tempDir.delete(recursive: true);
    }

    return errors;
  }

  /// Generate a blank plist template with the given label.
  String createTemplate(String label) {
    return '''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
\t<key>Label</key>
\t<string>$label</string>
\t<key>ProgramArguments</key>
\t<array>
\t\t<string>/usr/bin/true</string>
\t</array>
\t<key>RunAtLoad</key>
\t<false/>
\t<key>StandardOutPath</key>
\t<string>/tmp/$label.stdout.log</string>
\t<key>StandardErrorPath</key>
\t<string>/tmp/$label.stderr.log</string>
</dict>
</plist>
''';
  }

  /// Parse XML plist string into a Dart Map.
  Map<String, dynamic> _parseXmlPlist(String xmlString) {
    final document = XmlDocument.parse(xmlString);
    final plist = document.rootElement;
    final dict = plist.childElements.first;
    return _parseDict(dict);
  }

  Map<String, dynamic> _parseDict(XmlElement dict) {
    final map = <String, dynamic>{};
    final children = dict.childElements.toList();
    for (var i = 0; i < children.length; i += 2) {
      if (i + 1 >= children.length) break;
      final key = children[i].innerText;
      final value = _parseValue(children[i + 1]);
      map[key] = value;
    }
    return map;
  }

  dynamic _parseValue(XmlElement element) {
    return switch (element.name.local) {
      'string' => element.innerText,
      'integer' => int.tryParse(element.innerText) ?? 0,
      'real' => double.tryParse(element.innerText) ?? 0.0,
      'true' => true,
      'false' => false,
      'dict' => _parseDict(element),
      'array' => element.childElements.map(_parseValue).toList(),
      'data' => element.innerText.trim(),
      'date' => element.innerText.trim(),
      _ => element.innerText,
    };
  }
}
