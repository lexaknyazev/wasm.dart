@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

import 'helper_js_type_matchers.dart';

void main() {
  group('Validate', () {
    final validBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
    final validBuffer = validBytes.buffer;

    final invalidBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 0, 0, 0, 0]);
    final invalidBuffer = invalidBytes.buffer;

    test('Valid module from buffer', () {
      expect(Module.validateBuffer(validBuffer), isTrue);
    });

    test('Valid module from bytes', () {
      expect(Module.validateBytes(validBytes), isTrue);
    });

    test('Invalid module from buffer', () {
      expect(Module.validateBuffer(invalidBuffer), isFalse);
    });

    test('Invalid module from bytes', () {
      expect(Module.validateBytes(invalidBytes), isFalse);
    });
  });

  final moduleWith4Exports = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7F\x03\x02\x01\x00\x04\x04\x01\x70\x00\x34\x05\x03\x01\x00\x01\x06\x06\x01\x7F\x00\x41\x0D\x0B\x07\x1B\x04\x03\x74\x62\x6C\x01\x00\x04\x66\x75\x6E\x63\x00\x00\x03\x6D\x65\x6D\x02\x00\x04\x67\x6C\x6F\x62\x03\x00\x0A\x06\x01\x04\x00\x41\x2A\x0B\x00\x0A\x04\x6E\x61\x6D\x65\x02\x03\x01\x00\x00\x00\x05\x04\x64\x61\x72\x74'
          .codeUnits);

  final moduleWith4Imports = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x08\x02\x60\x01\x7F\x00\x60\x00\x00\x02\x2D\x04\x03\x66\x6F\x6F\x03\x62\x61\x72\x00\x00\x03\x66\x6F\x6F\x03\x6D\x65\x6D\x02\x00\x01\x03\x66\x6F\x6F\x03\x74\x62\x6C\x01\x70\x00\x01\x03\x66\x6F\x6F\x03\x67\x6C\x62\x03\x7F\x00\x03\x02\x01\x01\x07\x07\x01\x03\x62\x61\x7A\x00\x01\x0A\x08\x01\x06\x00\x23\x00\x10\x00\x0B'
          .codeUnits);

  void testExports(Module module) {
    final exports = module.exports.toList(growable: false);
    expect(exports, hasLength(4));

    expect(exports.singleWhere((d) => d.kind == ImportExportKind.table).name,
        'tbl');

    expect(exports.singleWhere((d) => d.kind == ImportExportKind.memory).name,
        'mem');

    expect(exports.singleWhere((d) => d.kind == ImportExportKind.function).name,
        'func');

    expect(exports.singleWhere((d) => d.kind == ImportExportKind.global).name,
        'glob');
  }

  void testCustomSection(Module module) {
    final nameSections = module.customSections('name');

    expect(nameSections, hasLength(1));
    expect(nameSections.first, const TypeMatcher<ByteBuffer>());
    expect(
        nameSections.first.asUint8List(), orderedEquals(<int>[2, 3, 1, 0, 0]));

    final dartSections = module.customSections('dart');

    expect(dartSections, hasLength(1));
    expect(dartSections.first, const TypeMatcher<ByteBuffer>());
    expect(dartSections.first.asUint8List(), isEmpty);
  }

  test('Compile from Uint8List', () {
    final module = Module.fromBytes(moduleWith4Exports);
    expect(module, const TypeMatcher<Module>());

    expect(module.imports, isEmpty);
    testExports(module);
    testCustomSection(module);
  });

  test('Compile from ByteBuffer', () {
    final module = Module.fromBuffer(moduleWith4Exports.buffer);
    expect(module, const TypeMatcher<Module>());

    expect(module.imports, isEmpty);
    testExports(module);
    testCustomSection(module);
  });

  final bigModule = Uint8List.fromList(<int>[]
    ..addAll('\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x81\x20\x04\x73\x6B\x69\x70'
        .codeUnits)
    ..addAll(Iterable.generate(4092, (_) => 0)));

  test('Sync compilation of big module fails', () {
    expect(() => Module.fromBytes(bigModule),
        throwsA(const TypeMatcher<ArgumentError>()));

    expect(() => Module.fromBuffer(bigModule.buffer),
        throwsA(const TypeMatcher<ArgumentError>()));
  }, testOn: '!node');

  test('Async compilation of big module succeeds', () async {
    final module = await Module.fromBytesAsync(bigModule);
    expect(module, const TypeMatcher<Module>());
    expect(module.customSections('skip'), hasLength(1));
    expect(module.customSections('skip')[0].lengthInBytes, 4092);

    // just in case
    expect(await Module.fromBufferAsync(bigModule.buffer),
        const TypeMatcher<Module>());
  });

  test('Imports', () {
    final module = Module.fromBytes(moduleWith4Imports);
    final imports = module.imports.toList(growable: false);
    expect(imports, hasLength(4));

    expect(imports.singleWhere((d) => d.kind == ImportExportKind.table).name,
        'tbl');

    expect(imports.singleWhere((d) => d.kind == ImportExportKind.memory).name,
        'mem');

    expect(imports.singleWhere((d) => d.kind == ImportExportKind.function).name,
        'bar');

    expect(imports.singleWhere((d) => d.kind == ImportExportKind.global).name,
        'glb');
  });

  test('Invalid source compilation', () {
    final bytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 0, 0, 0, 0]);
    final buffer = bytes.buffer;

    expect(() => Module.fromBytes(bytes), throwsA(isCompileError));

    expect(() => Module.fromBuffer(buffer), throwsA(isCompileError));

    expect(() => Module.fromBytesAsync(bytes), throwsA(isCompileError));

    expect(() => Module.fromBufferAsync(buffer), throwsA(isCompileError));
  });
}
