/// A single secret entry in the vault.
///
/// Serialisation is hand-written (no codegen) so the exact bytes that get
/// encrypted are easy to audit. Keep this in sync with [toJson]/[fromJson].
enum VaultItemType {
  login,
  secureNote,
  card,
  identity;

  static VaultItemType fromId(String? id) => VaultItemType.values.firstWhere(
        (t) => t.name == id,
        orElse: () => VaultItemType.login,
      );
}

/// A previous password, kept when the password changes.
final class PasswordHistoryEntry {
  const PasswordHistoryEntry({required this.password, required this.changedAt});

  final String password;
  final DateTime changedAt;

  Map<String, Object?> toJson() => {
        'password': password,
        'changedAt': changedAt.toUtc().toIso8601String(),
      };

  factory PasswordHistoryEntry.fromJson(Map<String, Object?> json) =>
      PasswordHistoryEntry(
        password: (json['password'] as String?) ?? '',
        changedAt: DateTime.parse(json['changedAt'] as String),
      );
}

final class VaultItem {
  const VaultItem({
    required this.id,
    required this.type,
    required this.title,
    this.username = '',
    this.password = '',
    this.url = '',
    this.notes = '',
    this.totpSecret,
    this.tags = const <String>[],
    this.favorite = false,
    this.passwordHistory = const <PasswordHistoryEntry>[],
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final VaultItemType type;
  final String title;
  final String username;
  final String password;
  final String url;
  final String notes;
  final String? totpSecret;
  final List<String> tags;
  final bool favorite;
  final List<PasswordHistoryEntry> passwordHistory;
  final DateTime createdAt;
  final DateTime updatedAt;

  VaultItem copyWith({
    String? title,
    VaultItemType? type,
    String? username,
    String? password,
    String? url,
    String? notes,
    String? totpSecret,
    List<String>? tags,
    bool? favorite,
    List<PasswordHistoryEntry>? passwordHistory,
    DateTime? updatedAt,
  }) {
    return VaultItem(
      id: id,
      type: type ?? this.type,
      title: title ?? this.title,
      username: username ?? this.username,
      password: password ?? this.password,
      url: url ?? this.url,
      notes: notes ?? this.notes,
      totpSecret: totpSecret ?? this.totpSecret,
      tags: tags ?? this.tags,
      favorite: favorite ?? this.favorite,
      passwordHistory: passwordHistory ?? this.passwordHistory,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'type': type.name,
        'title': title,
        'username': username,
        'password': password,
        'url': url,
        'notes': notes,
        'totpSecret': totpSecret,
        'tags': tags,
        'favorite': favorite,
        'passwordHistory': passwordHistory.map((e) => e.toJson()).toList(),
        'createdAt': createdAt.toUtc().toIso8601String(),
        'updatedAt': updatedAt.toUtc().toIso8601String(),
      };

  factory VaultItem.fromJson(Map<String, Object?> json) => VaultItem(
        id: json['id'] as String,
        type: VaultItemType.fromId(json['type'] as String?),
        title: (json['title'] as String?) ?? '',
        username: (json['username'] as String?) ?? '',
        password: (json['password'] as String?) ?? '',
        url: (json['url'] as String?) ?? '',
        notes: (json['notes'] as String?) ?? '',
        totpSecret: json['totpSecret'] as String?,
        tags: ((json['tags'] as List?) ?? const [])
            .map((e) => e.toString())
            .toList(growable: false),
        favorite: (json['favorite'] as bool?) ?? false,
        passwordHistory: ((json['passwordHistory'] as List?) ?? const [])
            .map((e) =>
                PasswordHistoryEntry.fromJson((e as Map).cast<String, Object?>()))
            .toList(),
        createdAt: DateTime.parse(json['createdAt'] as String),
        updatedAt: DateTime.parse(json['updatedAt'] as String),
      );
}
