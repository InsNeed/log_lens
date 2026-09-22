import 'package:loglens/loglens.dart';
import 'package:test/test.dart';

enum _Mod { app }
enum _Layer { ui }

/// Thin wrapper used to simulate an app-level logger in stack frames.
void _wrapperLog(String message) {
  LogLens.i(message, _Mod.app, _Layer.ui);
}

void main() {
  tearDown(() {
    configureCallerSkipContains(const []);
  });

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

    test('without skip config, app logger wrapper is the caller file', () {
      configureCallerSkipContains(const []);
      final file = parseCallerFileName(StackTrace.fromString('''
#0      LogLens._log (package:loglens/src/logger.dart:190:5)
#1      LogLens.i (package:loglens/src/logger.dart:160:5)
#2      AppLogger.info (package:luminth/core/logging/app_logger.dart:32:5)
#3      FsrsRepositoryImpl.save (package:luminth/features/fsrs/data/repositories/fsrs_repository_impl.dart:150:7)
'''));
      expect(file, 'app_logger.dart');
    });

    test('with skip config, skips app logger and returns business file', () {
      configureCallerSkipContains(const [
        'package:luminth/core/logging/app_logger.dart',
      ]);
      final file = parseCallerFileName(StackTrace.fromString('''
#0      LogLens._log (package:loglens/src/logger.dart:190:5)
#1      LogLens.i (package:loglens/src/logger.dart:160:5)
#2      AppLogger.info (package:luminth/core/logging/app_logger.dart:32:5)
#3      FsrsRepositoryImpl.save (package:luminth/features/fsrs/data/repositories/fsrs_repository_impl.dart:150:7)
'''));
      expect(file, 'fsrs_repository_impl.dart');
    });

    test('returns unknown when only loglens and skipped wrapper frames remain',
        () {
      configureCallerSkipContains(const [
        'package:luminth/core/logging/app_logger.dart',
      ]);
      expect(
        parseCallerFileName(StackTrace.fromString('''
#0      LogLens._log (package:loglens/src/logger.dart:190:5)
#1      LogLens.i (package:loglens/src/logger.dart:160:5)
#2      AppLogger.info (package:luminth/core/logging/app_logger.dart:32:5)
''')),
        'unknown',
      );
    });
  });

  group('LogLens skipCallerContains via init', () {
    test('init skipCallerContains makes LogEntry.fileName skip wrapper',
        () async {
      LogEntry? captured;
      await LogLens.init(
        debugGuard: false,
        defaultModules: _Mod.values,
        defaultLayers: _Layer.values,
        skipCallerContains: const ['caller_test.dart'],
        onLog: (entry) => captured = entry,
      );

      _wrapperLog('hello from wrapper');

      expect(captured, isNotNull);
      expect(captured!.fileName, isNot('caller_test.dart'));
      expect(captured!.message, 'hello from wrapper');
    });

    test('debugGuard flag is stored during init', () async {
      await LogLens.init(debugGuard: true);
      expect(LogLens.debugGuard, isTrue);
    });
  });
}
