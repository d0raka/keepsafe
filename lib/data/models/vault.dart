import 'dart:convert';
import 'dart:typed_data';

import '../../core/constants.dart';
import 'vault_item.dart';

/// The decrypted vault document — the plaintext that gets sealed into a
/// `.vault` file. This object only ever exists in memory while unlocked.
final class Vault {
  const Vault({
    required this.schemaVersion,
    required this.createdAt,
    required this.updatedAt,
    required this.items,
  });

  final int schemaVersion;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VaultItem> items;

  /// A fresh, empty vault stamped at [now].
  factory Vault.empty({required DateTime now}) => Vault(
        schemaVersion: VaultFormat.schemaVersion,
        createdAt: now,
        updatedAt: now,
        items: const <VaultItem>[],
      );

  Vault copyWith({List<VaultItem>? items, DateTime? updatedAt}) => Vault(
        schemaVersion: schemaVersion,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        items: items ?? this.items,
      );

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory Vault.fromJson(Map<String, Object?> json) => Vault(
        schemaVersion: (json['schemaVersion'] as int?) ?? VaultFormat.schemaVersion,
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
        items: ((json['items'] as List?) ?? const [])
            .map((e) => VaultItem.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
      );

  /// Serialise to the plaintext bytes that the crypto layer will encrypt.
  Uint8List toPlaintextBytes() =>
      Uint8List.fromList(utf8.encode(jsonEncode(toJson())));

  /// Reconstruct from decrypted plaintext bytes.
  static Vault fromPlaintextBytes(Uint8List bytes) {
    final decoded = jsonDecode(utf8.decode(bytes));
    return Vault.fromJson((decoded as Map).cast<String, Object?>());
  }
}
