import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // Platform-native crypto (CryptoKit/CommonCrypto on Apple targets) is
  // registered automatically by the cryptography_flutter plugin, giving
  // hardware-accelerated AES-GCM with a pure-Dart fallback.
  runApp(const ProviderScope(child: KeepSafeApp()));
}
