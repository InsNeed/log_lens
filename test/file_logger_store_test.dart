import 'dart:io';

import 'package:loglens/loglens.dart';
import 'package:test/test.dart';

enum _Mod { app }
enum _Layer { ui }

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('loglens_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('FileLoggerStore append + flush + loadEntries round-trip', () async {
    final store = FileLoggerStore(
      basePath: tempDir.path,
      flushDelay: Duration.zero,
    );
    await store.init();

    final entry = LogEntry(
      timestamp: DateTime.utc(2026, 1, 2, 3, 4, 5),
      level: LogLevel.info,
      moduleId: 'app',
      layerId: 'ui',
      fileName: 'test.dart',
      message: 'hello file store',
    );
    await store.append(entry);
    await store.flush();

    final loaded = await store.loadEntries();
    expect(loaded, hasLength(1));
    expect(loaded.first.message, 'hello file store');
    expect(loaded.first.moduleId, 'app');
    expect(loaded.first.level, LogLevel.info);
  });

  test('LogLens.init defaults to file store and loadEntries returns history',
      () async {
    await LogLens.init(
      store: FileLoggerStore(basePath: tempDir.path, flushDelay: Duration.zero),
      debugGuard: false,
      defaultModules: _Mod.values,
      defaultLayers: _Layer.values,
    );

    LogLens.i('persisted message', _Mod.app, _Layer.ui);
    await LogLens.flush();

    final entries = await LogLens.loadEntries();
    expect(entries, isNotEmpty);
    expect(entries.last.message, 'persisted message');
  });

  test('loadStorageInfo returns directory path and entries', () async {
    final store = FileLoggerStore(
      basePath: tempDir.path,
      flushDelay: Duration.zero,
    );
    await LogLens.init(
      store: store,
      debugGuard: false,
      defaultModules: _Mod.values,
      defaultLayers: _Layer.values,
    );

    LogLens.i('storage info message', _Mod.app, _Layer.ui);
    final info = await LogLens.loadStorageInfo();

    expect(info.directoryPath, endsWith('loglens'));
    expect(info.fileCount, greaterThan(0));
    expect(info.totalBytes, greaterThan(0));
    expect(info.entries, isNotEmpty);
    expect(info.entries.last.message, 'storage info message');

    final stats = await store.storageStats();
    expect(stats.fileCount, info.fileCount);
    expect(stats.totalBytes, info.totalBytes);
  });

  test('deleteAllLogs removes log files from disk', () async {
    final store = FileLoggerStore(
      basePath: tempDir.path,
      flushDelay: Duration.zero,
    );
    await LogLens.init(
      store: store,
      debugGuard: false,
      defaultModules: _Mod.values,
      defaultLayers: _Layer.values,
    );

    LogLens.i('to be deleted', _Mod.app, _Layer.ui);
    await LogLens.flush();
    expect(await LogLens.loadEntries(), isNotEmpty);
    expect((await store.storageStats()).totalBytes, greaterThan(0));

    await LogLens.deleteAllLogs();

    expect(await LogLens.loadEntries(), isEmpty);
    // clear recreates one empty rolling file
    final stats = await store.storageStats();
    expect(stats.fileCount, 1);
    expect(stats.totalBytes, 0);
  });

  LogEntry entryAt(int i) => LogEntry(
        timestamp: DateTime.utc(2026, 1, 1).add(Duration(milliseconds: i)),
        level: LogLevel.info,
        moduleId: 'app',
        layerId: 'ui',
        fileName: 'test.dart',
        message: 'message $i ${'x' * 60}',
      );

  test('loadEntries tails a log file larger than 64KB', () async {
    final store = FileLoggerStore(
      basePath: tempDir.path,
      flushDelay: Duration.zero,
    );
    await store.init();
    for (var i = 0; i < 2000; i++) {
      await store.append(entryAt(i));
    }
    await store.flush();
    expect((await store.storageStats()).totalBytes, greaterThan(64 * 1024));

    final loaded = await store.loadEntries(limit: 1000);
    expect(loaded, hasLength(1000));
    expect(loaded.first.message, startsWith('message 1000 '));
    expect(loaded.last.message, startsWith('message 1999 '));
  });

  test('loadEntries skips torn lines', () async {
    final store = FileLoggerStore(
      basePath: tempDir.path,
      flushDelay: Duration.zero,
    );
    await store.init();
    await store.append(entryAt(0));
    await store.flush();
    final logFile = Directory('${tempDir.path}/loglens')
        .listSync()
        .whereType<File>()
        .firstWhere((f) => f.path.endsWith('.log'));
    await logFile.writeAsString('{"ts":1,"lvl":"in\n', mode: FileMode.append);
    await store.append(entryAt(1));
    await store.flush();

    final loaded = await store.loadEntries();
    expect(loaded.map((e) => e.message), [
      startsWith('message 0 '),
      startsWith('message 1 '),
    ]);
  });
}
