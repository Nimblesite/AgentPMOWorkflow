/// ANSI color codes for terminal output.
class Ansi {
  static const reset = '\x1B[0m';
  static const bold = '\x1B[1m';
  static const dim = '\x1B[2m';

  static const red = '\x1B[31m';
  static const green = '\x1B[32m';
  static const yellow = '\x1B[33m';
  static const blue = '\x1B[34m';
  static const cyan = '\x1B[36m';
  static const white = '\x1B[37m';
  static const gray = '\x1B[90m';

  static String colorize(String text, String color) => '$color$text$reset';

  static String statusColor(String status) {
    return switch (status) {
      'Running' => colorize(status, blue),
      'Loaded' => colorize(status, green),
      'Not Loaded' => colorize(status, dim),
      'Error' => colorize(status, red),
      _ => status,
    };
  }

  static String exitColor(int? code) {
    if (code == null) return colorize('-', dim);
    if (code == 0) return colorize('$code', green);
    return colorize('$code', red);
  }

  static String pidDisplay(int? pid) {
    if (pid == null || pid <= 0) return colorize('-', dim);
    return '$pid';
  }
}
