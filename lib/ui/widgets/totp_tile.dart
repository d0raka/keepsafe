import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/totp_service.dart';

/// Live verification-code tile: recomputes the RFC 6238 TOTP every second and
/// shows a circular countdown to the next 30s window.
class TotpTile extends StatefulWidget {
  const TotpTile({super.key, required this.secret, required this.onCopy});

  final String secret;
  final ValueChanged<String> onCopy;

  @override
  State<TotpTile> createState() => _TotpTileState();
}

class _TotpTileState extends State<TotpTile> {
  Timer? _timer;
  String? _code;
  int _remaining = 30;

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  void _tick() {
    final code = TotpService.currentCode(widget.secret);
    final remaining = TotpService.secondsRemaining();
    if (mounted) {
      setState(() {
        _code = code;
        _remaining = remaining;
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onSurface = Theme.of(context).colorScheme.onSurface;
    final accent = Theme.of(context).colorScheme.primary;
    final code = _code;
    if (code == null) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Invalid 2FA secret',
            style: TextStyle(color: onSurface.withValues(alpha: 0.5))),
      );
    }
    final formatted = '${code.substring(0, 3)} ${code.substring(3)}';
    return InkWell(
      onTap: () => widget.onCopy(code),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Verification code',
                    style: TextStyle(
                        fontSize: 13, color: onSurface.withValues(alpha: 0.5))),
                const SizedBox(height: 2),
                Text(formatted,
                    style: TextStyle(
                        fontSize: 24,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w600,
                        color: accent)),
              ],
            ),
            const Spacer(),
            SizedBox(
              width: 26,
              height: 26,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: _remaining / 30.0,
                    strokeWidth: 2.5,
                    backgroundColor: onSurface.withValues(alpha: 0.12),
                    valueColor: AlwaysStoppedAnimation(accent),
                  ),
                  Text('$_remaining',
                      style: TextStyle(
                          fontSize: 10,
                          color: onSurface.withValues(alpha: 0.6))),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.copy, size: 18, color: onSurface.withValues(alpha: 0.4)),
          ],
        ),
      ),
    );
  }
}
