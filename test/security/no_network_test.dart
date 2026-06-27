import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// KeepSafe is strictly offline. This guard fails the build if any networking
/// primitive appears in `lib/`. It complements the OS-level guarantee (no
/// network entitlements) with a source-level check so a dependency or a careless
/// edit can never silently introduce a connection.
void main() {
  // Networking symbols/imports that must never appear in application code.
  // (`dart:io` itself is allowed — we use it for File I/O — so we match the
  // specific networking classes/packages rather than the whole library.)
  const forbidden = <String>[
    'HttpClient',
    'HttpServer',
    'package:http/',
    'package:dio/',
    'package:web_socket_channel/',
    'WebSocket',
    'RawSocket',
    'ServerSocket',
    'Socket.connect',
    'InternetAddress',
    'RawDatagramSocket',
  ];

  test('lib/ contains no networking code', () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'run from project root');

    final offenders = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      for (final needle in forbidden) {
        if (source.contains(needle)) {
          offenders.add('${entity.path}: "$needle"');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Networking is forbidden in an offline vault:\n'
          '${offenders.join('\n')}',
    );
  });
}
