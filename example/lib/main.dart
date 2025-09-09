import 'package:flutter/material.dart';

import 'package:my_logger/my_logger.dart';

enum LogModules {
  auth,
  pay,
}

enum LogLayers { ui, dataSource }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  /// Initialize logger and register modules/layers
  await MyLogger.init(
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
      appBar: AppBar(title: const Text('MyLogger Example')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text('''Guide:
1. Initialize: MyLogger.init()
2. Register module: MyLogger.registerModule("moduleId")
3. Register layer: MyLogger.registerLayer("layerId")
4. Log: MyLogger.i(file, msg, moduleName, layerName)
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
              MyLogger.i('example.dart', 'User pressed login button',
                  LogModules.auth, LogLayers.ui);

              //failed
              MyLogger.e('UserLogin.dart', 'UserLogin Failed', LogModules.auth,
                  LogLayers.dataSource);
              //user pay
              MyLogger.i('Payment.dart', 'User pressed pay button, paid \$100',
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
