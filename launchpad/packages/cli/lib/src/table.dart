import 'dart:math';

/// Simple table renderer for terminal output.
class Table {
  final List<String> headers;
  final List<List<String>> rows;

  Table({required this.headers, required this.rows});

  String render() {
    if (rows.isEmpty) return 'No jobs found.';

    // Calculate column widths (accounting for ANSI codes)
    final widths = List<int>.filled(headers.length, 0);
    for (var i = 0; i < headers.length; i++) {
      widths[i] = headers[i].length;
    }
    for (final row in rows) {
      for (var i = 0; i < row.length && i < widths.length; i++) {
        widths[i] = max(widths[i], _visibleLength(row[i]));
      }
    }

    final buf = StringBuffer();

    // Header
    for (var i = 0; i < headers.length; i++) {
      buf.write(headers[i].padRight(widths[i] + 2));
    }
    buf.writeln();

    // Separator
    for (var i = 0; i < headers.length; i++) {
      buf.write('${'─' * widths[i]}  ');
    }
    buf.writeln();

    // Rows
    for (final row in rows) {
      for (var i = 0; i < headers.length; i++) {
        final cell = i < row.length ? row[i] : '';
        final padding = widths[i] - _visibleLength(cell);
        buf.write('$cell${' ' * max(0, padding + 2)}');
      }
      buf.writeln();
    }

    return buf.toString();
  }

  /// Get visible length of a string (excluding ANSI escape codes).
  int _visibleLength(String s) {
    return s.replaceAll(RegExp(r'\x1B\[[0-9;]*m'), '').length;
  }
}
