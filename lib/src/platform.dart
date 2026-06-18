/// Mirrors Flutter's compile-time mode flags for pure Dart consumers.
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');

/// True when running a non-product (debug) build.
const bool kDebugMode = !kReleaseMode;
