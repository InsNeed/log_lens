import 'package:flutter/material.dart';

import '../../lib/my_logger.dart';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MyLogger.I.init();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: const ConsoleDemo(),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
    );
  }
}

class ConsoleDemo extends StatelessWidget {
  const ConsoleDemo({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('MyLogger Example')),
      body: const LogConsolePage(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          MyLogger.I.i('example', 'hello', 'test', 'dataSource');
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
