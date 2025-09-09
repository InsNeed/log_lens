library my_logger;

import 'package:flutter/material.dart';
import 'package:my_logger/src/logger.dart';
import 'src/console/log_console.dart';

export 'src/registry.dart';
export 'src/config.dart';
export 'src/logger.dart';
export 'src/console/log_console.dart';
export 'src/persistence/store.dart';

// Internal parts
part 'src/console/_draggable_resizable_overlay.dart';
part 'src/console/floating_log_console.dart';
