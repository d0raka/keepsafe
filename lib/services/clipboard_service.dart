import 'dart:async';

import 'package:flutter/services.dart';

/// Copies sensitive values to the clipboard and auto-clears them after a delay,
/// so a copied password doesn't linger indefinitely.
///
/// The clear is conditional: it only wipes the clipboard if it still holds the
/// exact value we copied, so we never erase something the user copied later.
final class ClipboardService {
  ClipboardService({this.clearAfter = const Duration(seconds: 30)});

  final Duration clearAfter;
  Timer? _timer;

  Future<void> copySensitive(String value) async {
    await Clipboard.setData(ClipboardData(text: value));
    _timer?.cancel();
    _timer = Timer(clearAfter, () async {
      final current = await Clipboard.getData(Clipboard.kTextPlain);
      if (current?.text == value) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    });
  }

  void dispose() => _timer?.cancel();
}
