import 'package:flutter/material.dart';
import 'package:loglens/loglens.dart';
import 'package:loglens_flutter/loglens_flutter.dart';

enum LogLayers { ui, dataSource }

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await LogLensFlutter.init(
    defaultModules: LoggerDefaultModule.values,
    defaultLayers: LogLayers.values,
    onLog: (log) => print(log.message),
    // debugGuard defaults to true: release builds skip LogLevel.debug only.
  );
  runApp(const LogLensLifecycleFlusher(child: MyApp()));
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
  1. Initialize: LogLensFlutter.init()
  2. Log: LogLens.i(message, module, layer)
  3. Open console — history loads from disk automatically
'''),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => controller.toggle(context),
            child: const Text('Toggle Floating Log Window'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              LogLens.i(
                'User pressed login button',
                LoggerDefaultModule.auth,
                LogLayers.ui,
              );
              LogLens.e(
                'UserLogin Failed',
                LoggerDefaultModule.auth,
                LogLayers.dataSource,
              );
              LogLens.i(
                'User pressed pay button, paid \$100 \nhaherroreoreeeeasdjanjshsvgyqvdgfqcdgqvdsujhbhcfdukvdgfbkvhdfbvdfvda \n haha \n hehehe erroreoreeeeasdjanjshsvgyqvdgfqcdgqvdsujhbhcfdukvdgfbkvhdfbvdfvd',
                LoggerDefaultModule.pay,
                LogLayers.ui,
              );
            },
            child: const Text('Write Sample Logs'),
          ),
          const SizedBox(height: 8),
          FilledButton.tonal(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LogConsolePage()),
              );
            },
            child: const Text('Open Full Console'),
          ),
        ],
      ),
    );
  }
}
