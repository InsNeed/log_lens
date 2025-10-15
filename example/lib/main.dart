import 'package:flutter/material.dart';
import 'package:loglens/loglens.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

SharedPreferences? _sp;
const String _cfgKey = 'my_logger_config_v1';
const String _logKey = 'my_logger_logs_v1';

String _encodeEntry(LogEntry e) => jsonEncode({
      'ts': e.timestamp.millisecondsSinceEpoch,
      'lvl': e.level.name,
      'mod': e.moduleId,
      'lay': e.layerId,
      'file': e.fileName,
      'msg': e.message?.toString(),
      'err': e.error?.toString(),
      'st': e.stackTrace?.toString(),
    });

LogEntry _decodeEntry(String s) {
  final m = jsonDecode(s) as Map<String, dynamic>;
  return LogEntry(
    timestamp: DateTime.fromMillisecondsSinceEpoch(m['ts'] as int),
    level: LogLevel.values.firstWhere((e) => e.name == (m['lvl'] as String)),
    moduleId: m['mod'] as String,
    layerId: m['lay'] as String,
    fileName: m['file'] as String,
    message: m['msg'],
    error: m['err'],
    stackTrace:
        m['st'] != null ? StackTrace.fromString(m['st'] as String) : null,
  );
}

enum LogModules {
  auth,
  pay,
}

enum LogLayers { ui, dataSource }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize logger and register modules/layers
  await LogLens.init(
    defaultModules: LogModules.values,
    defaultLayers: LogLayers.values,
    onLog: (log) => print(log),
    // Storage callbacks example using SharedPreferences (replicates default store)
    // onStoreInit: () async {
    //   // Warm up SharedPreferences instance
    //   _sp = await SharedPreferences.getInstance();
    // },
    // onStoreSaveConfig: (LoggerConfig cfg) async {
    //   await _sp?.setString(_cfgKey, jsonEncode(cfg.toJson()));
    // },
    // onStoreLoadConfig: () async {
    //   final raw = _sp?.getString(_cfgKey);
    //   if (raw == null) return null;
    //   final map = jsonDecode(raw) as Map<String, dynamic>;
    //   return LoggerConfig.fromJson(map);
    // },
    // onStoreAppend: (LogEntry entry) async {
    //   final list = _sp?.getStringList(_logKey) ?? <String>[];
    //   list.add(_encodeEntry(entry));
    //   await _sp?.setStringList(_logKey, list);
    // },
    // onStoreLoadEntries: ({int? limit}) async {
    //   final list = _sp?.getStringList(_logKey) ?? <String>[];
    //   final decoded = list.map(_decodeEntry).toList();
    //   if (limit == null || decoded.length <= limit) return decoded;
    //   return decoded.sublist(decoded.length - limit);
    // },
    // onStoreClear: () async {
    //   await _sp?.remove(_logKey);
    // },
  );
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ConsoleDemo(),
    );
  }
}

class ConsoleDemo extends StatelessWidget {
  const ConsoleDemo({super.key});
  @override
  Widget build(BuildContext context) {
    final controller = FloatingLogConsoleController();
    return Scaffold(
      appBar: AppBar(title: const Text('LogLens Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('''Guide:
  1.Initialize and Register: LogLens.init()
  2.Log: LogLens.i(file, msg, moduleName, layerName)
  3.Config LoggerConfig().setModuleLevel(module, level, enabled)
'''),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => controller.toggle(context),
            child: const Text('Toggle Floating Log Window'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              //login
              LogLens.i('exampleAAAAAAAAAAAAAAAAAAAAAAAA.dart',
                  'User pressed login button', LogModules.auth, LogLayers.ui);

              //failed
              LogLens.e('UserLogin.dart', 'UserLogin Failed', LogModules.auth,
                  LogLayers.dataSource);

              //user pay
              LogLens.i('Payment.dart', 'User pressed pay button, paid \$100',
                  LogModules.pay, LogLayers.ui);
            },
            child: const Text('Write Sample Logs'),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
