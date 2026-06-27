import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';

/// Manual `.vault` import/export — the offline "sync" story. The user picks the
/// destination/source themselves (iCloud Drive, Syncthing folder, USB, …).
final class ImportExportService {
  const ImportExportService();

  static const XTypeGroup _vaultGroup = XTypeGroup(
    label: 'KeepSafe Vault',
    extensions: <String>['vault'],
    // macOS UTI fallback so the picker accepts the file type.
    uniformTypeIdentifiers: <String>['public.data'],
  );

  /// Prompts for a save location and writes [bytes]. Returns the path written,
  /// or null if the user cancelled.
  Future<String?> exportBytes(
    Uint8List bytes, {
    String suggestedName = 'keepsafe-export.vault',
  }) async {
    final location = await getSaveLocation(
      acceptedTypeGroups: const [_vaultGroup],
      suggestedName: suggestedName,
    );
    if (location == null) return null;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return location.path;
  }

  /// Prompts the user to pick a `.vault` file and returns its bytes, or null.
  Future<Uint8List?> pickImportBytes() async {
    final file = await openFile(acceptedTypeGroups: const [_vaultGroup]);
    if (file == null) return null;
    return file.readAsBytes();
  }
}
