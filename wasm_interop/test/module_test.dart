@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

import 'helper_js_type_matchers.dart';

void main() {
  group('Validate', () {
    final validBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
    final invalidBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 0, 0, 0, 0]);

    test('Valid module from bytes',
        () => expect(Module.validateBytes(validBytes), isTrue));

    test('Valid module from buffer',
        () => expect(Module.validateBuffer(validBytes.buffer), isTrue));

    test('Invalid module from bytes',
        () => expect(Module.validateBytes(invalidBytes), isFalse));

    test('Invalid module from buffer',
        () => expect(Module.validateBuffer(invalidBytes.buffer), isFalse));

    test('Invalid source throws CompileError', () {
      expect(() => Module.fromBytes(invalidBytes), throwsA(isCompileError));

      expect(() => Module.fromBuffer(invalidBytes.buffer),
          throwsA(isCompileError));

      expect(
          () => Module.fromBytesAsync(invalidBytes), throwsA(isCompileError));

      expect(() => Module.fromBufferAsync(invalidBytes.buffer),
          throwsA(isCompileError));
    });
  });

  group('Exports', () {
    /// (module
    ///   (func (export "f"))
    ///   (table (export "t") 1 funcref)
    ///   (memory (export "m") 1)
    ///   (global (export "g") i32 (i32.const 0))
    /// )
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x03\x02\x01'
                '\x00\x04\x04\x01\x70\x00\x01\x05\x03\x01\x00\x01\x06\x06\x01'
                '\x7F\x00\x41\x00\x0B\x07\x11\x04\x01\x66\x00\x00\x01\x74\x01'
                '\x00\x01\x6D\x02\x00\x01\x67\x03\x00\x0A\x04\x01\x02\x00\x0B'
            .codeUnits);

    void testExports(Module module) {
      const names = {
        ImportExportKind.function: 'f',
        ImportExportKind.global: 'g',
        ImportExportKind.memory: 'm',
        ImportExportKind.table: 't'
      };

      final exports = module.exports;
      expect(exports, hasLength(4));

      names.forEach((kind, name) {
        final d = exports.where((d) => d.kind == kind);
        expect(d, hasLength(1));
        expect(d.first.name, name);
      });
    }

    test('From bytes', () => testExports(Module.fromBytes(moduleBytes)));

    test('From buffer',
        () => testExports(Module.fromBuffer(moduleBytes.buffer)));
  });

  group('Imports', () {
    /// (module
    ///   (import "env" "f" (func))
    ///   (import "env" "m" (memory 1))
    ///   (import "env" "t" (table 1 funcref))
    ///   (import "env" "g" (global i32))
    /// )
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x25\x04'
                '\x03\x65\x6E\x76\x01\x66\x00\x00\x03\x65\x6E\x76\x01\x6D\x02'
                '\x00\x01\x03\x65\x6E\x76\x01\x74\x01\x70\x00\x01\x03\x65\x6E'
                '\x76\x01\x67\x03\x7F\x00'
            .codeUnits);

    void testImports(Module module) {
      const names = {
        ImportExportKind.function: 'f',
        ImportExportKind.global: 'g',
        ImportExportKind.memory: 'm',
        ImportExportKind.table: 't'
      };

      final imports = module.imports;
      expect(imports, hasLength(4));

      names.forEach((kind, name) {
        final d = imports.where((d) => d.kind == kind);
        expect(d, hasLength(1));
        expect(d.first.module, 'env');
        expect(d.first.name, name);
      });
    }

    test('From bytes', () => testImports(Module.fromBytes(moduleBytes)));

    test('From buffer',
        () => testImports(Module.fromBuffer(moduleBytes.buffer)));
  });

  group('Custom Sections', () {
    // An empty module with two custom sections called 'dart' of 3 and 5 bytes.
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x08\x04\x64\x61\x72\x74\x00\x01'
                '\x02\x00\x0A\x04\x64\x61\x72\x74\x05\x04\x03\x02\x01'
            .codeUnits);

    void testCustomSections(Module module) {
      final sections = module.customSections('dart');

      expect(sections, hasLength(2));
      expect(sections[0].asUint8List(), orderedEquals(<int>[0, 1, 2]));
      expect(sections[1].asUint8List(), orderedEquals(<int>[5, 4, 3, 2, 1]));
    }

    test('From bytes', () => testCustomSections(Module.fromBytes(moduleBytes)));

    test('From buffer',
        () => testCustomSections(Module.fromBuffer(moduleBytes.buffer)));
  });

  group('Size limit', () {
    // An empty module with a single custom section called 'skip' of 4097 bytes.
    final moduleBytes = Uint8List.fromList(<int>[
      ...'\x00\x61\x73\x6D\x01\x00\x00\x00\x00\x81\x20\x04\x73\x6B\x69\x70'
          .codeUnits,
      ...Iterable.generate(4092, (_) => 0)
    ]);

    test(
        'Sync compilation from bytes fails',
        () => expect(
            () => Module.fromBytes(moduleBytes), throwsA(isA<ArgumentError>())),
        testOn: 'chrome');

    test(
        'Sync compilation from buffer fails',
        () => expect(() => Module.fromBuffer(moduleBytes.buffer),
            throwsA(isA<ArgumentError>())),
        testOn: 'chrome');

    test('Async compilation from bytes succeeds', () async {
      final module = await Module.fromBytesAsync(moduleBytes);
      expect(module, isA<Module>());
      expect(module.customSections('skip'), hasLength(1));
      expect(module.customSections('skip')[0].lengthInBytes, 4092);
    });

    test('Async compilation from buffer succeeds', () async {
      final module = await Module.fromBufferAsync(moduleBytes.buffer);
      expect(module, isA<Module>());
      expect(module.customSections('skip'), hasLength(1));
      expect(module.customSections('skip')[0].lengthInBytes, 4092);
    });
  });
}
