/// Internal frames from this package and the underlying printer.
const _skippedPackages = {'package:loglens/', 'package:logger/'};

/// Extra stack-frame substrings to skip when resolving the caller file.
///
/// Configured via [configureCallerSkipContains] (usually from [LogLens.init]).
Set<String> _extraSkipContains = {};

/// Replaces the extra caller-skip substrings used by [parseCallerFileName].
///
/// Empty / blank patterns are ignored. Pass an empty iterable to clear.
void configureCallerSkipContains(Iterable<String> patterns) {
  _extraSkipContains = {
    for (final p in patterns)
      if (p.trim().isNotEmpty) p,
  };
}

/// Extracts the caller `.dart` file name from [stackTrace], skipping LogLens
/// frames and any patterns from [configureCallerSkipContains].
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
  for (final pattern in _extraSkipContains) {
    if (line.contains(pattern)) return true;
  }
  return false;
}
