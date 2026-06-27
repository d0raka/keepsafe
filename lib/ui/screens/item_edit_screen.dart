import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/vault_item.dart';
import '../../state/app_controller.dart';
import '../item_visuals.dart';
import '../widgets/generator_sheet.dart';

/// Opens the item editor, adapting to the platform: a centered modal sheet on
/// wide (desktop) windows, a full-screen push on narrow (mobile) ones.
Future<void> openItemEditor(BuildContext context, {VaultItem? existing}) {
  final wide = MediaQuery.of(context).size.width >= 900;
  if (wide) {
    return showDialog(
      context: context,
      builder: (_) => Dialog(
        clipBehavior: Clip.antiAlias,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560, maxHeight: 720),
          child: ItemEditScreen(existing: existing),
        ),
      ),
    );
  }
  return Navigator.of(context).push(
    MaterialPageRoute(builder: (_) => ItemEditScreen(existing: existing)),
  );
}

/// Add a new item ([existing] == null) or edit an existing one.
class ItemEditScreen extends ConsumerStatefulWidget {
  const ItemEditScreen({super.key, this.existing});

  final VaultItem? existing;

  @override
  ConsumerState<ItemEditScreen> createState() => _ItemEditScreenState();
}

class _ItemEditScreenState extends ConsumerState<ItemEditScreen> {
  late final _title = TextEditingController(text: widget.existing?.title ?? '');
  late final _username =
      TextEditingController(text: widget.existing?.username ?? '');
  late final _password =
      TextEditingController(text: widget.existing?.password ?? '');
  late final _url = TextEditingController(text: widget.existing?.url ?? '');
  late final _notes = TextEditingController(text: widget.existing?.notes ?? '');
  late final _totp =
      TextEditingController(text: widget.existing?.totpSecret ?? '');
  late final _tags =
      TextEditingController(text: (widget.existing?.tags ?? const []).join(', '));
  late VaultItemType _type = widget.existing?.type ?? VaultItemType.login;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  bool get _isEdit => widget.existing != null;

  @override
  void dispose() {
    for (final c in [_title, _username, _password, _url, _notes, _totp, _tags]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      setState(() => _error = 'Title is required.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final ctrl = ref.read(appControllerProvider.notifier);
    final totp = _totp.text.trim().isEmpty ? null : _totp.text.trim();
    final tags = _parseTags();
    final String? err;
    if (_isEdit) {
      err = await ctrl.updateItem(widget.existing!.copyWith(
        title: _title.text.trim(),
        type: _type,
        username: _username.text,
        password: _password.text,
        url: _url.text,
        notes: _notes.text,
        totpSecret: totp,
        tags: tags,
      ));
    } else {
      err = await ctrl.addItem(
        title: _title.text.trim(),
        type: _type,
        username: _username.text,
        password: _password.text,
        url: _url.text,
        notes: _notes.text,
        totpSecret: totp,
        tags: tags,
      );
    }
    if (!mounted) return;
    if (err == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  Future<void> _generate() async {
    final pw = await showGeneratorSheet(context);
    if (pw != null && mounted) {
      setState(() {
        _password.text = pw;
        _obscure = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        leadingWidth: 88,
        title: Text(_isEdit ? 'Edit' : 'New Item'),
        actions: [
          TextButton(
            onPressed: _busy ? null : _save,
            child: const Text('Save', style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          DropdownButtonFormField<VaultItemType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: VaultItemType.values
                .map((t) => DropdownMenuItem(
                      value: t,
                      child: Row(
                        children: [
                          Icon(ItemVisuals.icon(t),
                              size: 18, color: ItemVisuals.color(t)),
                          const SizedBox(width: 8),
                          Text(ItemVisuals.label(t)),
                        ],
                      ),
                    ))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 12),
          _field(_title, 'Title', autofocus: !_isEdit),
          const SizedBox(height: 12),
          _field(_username, 'Username / email'),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscure,
            decoration: InputDecoration(
              labelText: 'Password',
              suffixIcon: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: _obscure ? 'Show' : 'Hide',
                    icon: Icon(
                        _obscure ? Icons.visibility : Icons.visibility_off,
                        size: 20),
                    onPressed: () => setState(() => _obscure = !_obscure),
                  ),
                  IconButton(
                    tooltip: 'Generate',
                    icon: const Icon(Icons.auto_awesome, size: 20),
                    onPressed: _generate,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _field(_url, 'Website'),
          const SizedBox(height: 12),
          _field(_totp, '2FA secret (Base32, optional)'),
          const SizedBox(height: 12),
          _field(_tags, 'Tags (comma-separated)'),
          const SizedBox(height: 12),
          _field(_notes, 'Notes', maxLines: 4),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }

  List<String> _parseTags() => _tags.text
      .split(',')
      .map((t) => t.trim())
      .where((t) => t.isNotEmpty)
      .toSet()
      .toList();

  Widget _field(TextEditingController c, String label,
      {int maxLines = 1, bool autofocus = false}) {
    return TextField(
      controller: c,
      maxLines: maxLines,
      autofocus: autofocus,
      decoration: InputDecoration(labelText: label),
    );
  }
}
