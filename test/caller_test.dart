import 'package:loglens/loglens.dart';
import 'package:test/test.dart';

void main() {
  group('parseCallerFileName', () {
    test('skips loglens frames and returns caller file', () {
      final file = parseCallerFileName(StackTrace.fromString('''
#0      LogLens._log (package:loglens/src/logger.dart:180:5)
#1      LogLens.i (package:loglens/src/logger.dart:155:5)
#2      main (package:example/main.dart:42:10)
#3      _runMain (dart:ui/hooks.dart:301:23)
'''));
      expect(file, 'main.dart');
    });

    test('returns unknown when no caller frame is found', () {
      expect(
        parseCallerFileName(StackTrace.fromString('''
#0      LogLens._log (package:loglens/src/logger.dart:180:5)
#1      LogLens.i (package:loglens/src/logger.dart:155:5)
''')),
        'unknown',
      );
    });
  });

  group('LogLens debugGuard', () {
    setUp(() async {
      await LogLens.init(debugGuard: true);
    });

    test('debugGuard flag is stored during init', () {
      expect(LogLens.debugGuard, isTrue);
    });
  });
}
