import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:keepsafe/data/vault_file_store.dart';

void main() {
  late Directory tmp;
  const store = VaultFileStore();

  setUp(() async {
    tmp = await Directory.systemTemp.createTemp('keepsafe_test_');
  });
  tearDown(() async {
    if (await tmp.exists()) await tmp.delete(recursive: true);
  });

  test('writes then reads identical bytes', () async {
    final path = '${tmp.path}/a.vault';
    final data = Uint8List.fromList(List.generate(1000, (i) => i % 256));
    await store.writeBytesAtomic(path, data);

    expect(await store.exists(path), isTrue);
    expect(await store.readBytes(path), equals(data));
  });

  test('atomic overwrite replaces previous content and leaves no .tmp', () async {
    final path = '${tmp.path}/b.vault';
    await store.writeBytesAtomic(path, Uint8List.fromList([1, 2, 3]));
    await store.writeBytesAtomic(path, Uint8List.fromList([9, 9, 9, 9]));

    expect(await store.readBytes(path), equals(Uint8List.fromList([9, 9, 9, 9])));
    expect(await File('$path.tmp').exists(), isFalse);
  });
}
