import 'dart:io';
import 'dart:typed_data';

/// Reads and writes raw `.vault` bytes to disk **atomically**.
///
/// Writes go to a temporary sibling file that is flushed to disk and then
/// `rename`d over the target. `rename` within the same directory is atomic on
/// macOS/iOS (APFS) and POSIX filesystems, so a crash mid-write can never leave
/// a half-written, unreadable vault — the old file survives until the new one
/// is complete.
final class VaultFileStore {
  const VaultFileStore();

  Future<bool> exists(String path) => File(path).exists();

  Future<Uint8List> readBytes(String path) => File(path).readAsBytes();

  Future<void> writeBytesAtomic(String path, Uint8List bytes) async {
    final target = File(path);
    final dir = target.parent;
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }

    final tmp = File('$path.tmp');
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush(); // force bytes to the OS before swap
    } finally {
      await raf.close();
    }
    await tmp.rename(path);
  }

  Future<void> delete(String path) async {
    final f = File(path);
    if (await f.exists()) {
      await f.delete();
    }
  }
}
