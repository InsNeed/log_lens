import 'package:flutter/material.dart';
import 'package:loglens/loglens.dart';

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
              LogLens.i('example.dart', 'User pressed login button',
                  LogModules.auth, LogLayers.ui);

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
          const Text('Or open the full console page:'),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LogConsolePage()),
            ),
            child: const Text('Open Console Page'),
          ),
        ],
      ),
      floatingActionButton: FloatingLogConsoleButton(controller: controller),
    );
  }
}
