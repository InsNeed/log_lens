/// Internal frames from this package and the underlying printer.
const _skippedPackages = {'package:loglens/', 'package:logger/'};

/// Extracts the caller `.dart` file name from [stackTrace], skipping LogLens frames.
String parseCallerFileName([StackTrace? stackTrace]) {
  final trace = stackTrace ?? StackTrace.current;
  for (final line in trace.toString().split('\n')) {
    if (_shouldSkipFrame(line)) continue;

    final packageMatch =
        RegExp(r'package:[^/]+/(.+\.dart)').firstMatch(line);
    if (packageMatch != null) {
      return packageMatch.group(1)!.split('/').last;
    }

    final fileMatch = RegExp(r'([^/\\]+\.dart)').firstMatch(line);
    if (fileMatch != null) {
      return fileMatch.group(1)!;
    }
  }
  return 'unknown';
}

bool _shouldSkipFrame(String line) {
  for (final prefix in _skippedPackages) {
    if (line.contains(prefix)) return true;
  }
  return false;
}
