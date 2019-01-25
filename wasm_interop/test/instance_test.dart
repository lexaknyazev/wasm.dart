@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

import 'helper_imports_object.dart';
import 'helper_js_type_matchers.dart';

void main() {
  final validBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);
  final validBuffer = validBytes.buffer;

  final invalidBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 0, 0, 0, 0]);
  final invalidBuffer = invalidBytes.buffer;

  /// Module source
  ///
  /// (module
  ///  (import "js" "mem" (memory 1))
  ///  (import "js" "tbl" (table 1 anyfunc))
  ///  (import "env" "val" (global i32))
  ///  (import "env" "foo" (func $foo (param i32) (result i32)))
  ///  (global (export "baz") i32 (i32.const 13))
  ///  (func $bar (export "bar") (result i32)
  ///    get_global 0
  ///    call $foo
  ///  )
  /// )
  final fullModule = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x0A\x02\x60\x01\x7F\x01\x7F\x60\x00'
          '\x01\x7F\x02\x2B\x04\x02\x6A\x73\x03\x6D\x65\x6D\x02\x00\x01\x02\x6A'
          '\x73\x03\x74\x62\x6C\x01\x70\x00\x01\x03\x65\x6E\x76\x03\x76\x61\x6C'
          '\x03\x7F\x00\x03\x65\x6E\x76\x03\x66\x6F\x6F\x00\x00\x03\x02\x01\x01'
          '\x06\x06\x01\x7F\x00\x41\x0D\x0B\x07\x0D\x02\x03\x62\x61\x7A\x03\x01'
          '\x03\x62\x61\x72\x00\x01\x0A\x08\x01\x06\x00\x23\x00\x10\x00\x0B'
          .codeUnits);

  test('Instantiate empty', () async {
    void checkInstance(Instance instance) {
      expect(instance, const TypeMatcher<Instance>());
      expect(instance.functions, isEmpty);
      expect(instance.globals, isEmpty);
      expect(instance.memories, isEmpty);
      expect(instance.tables, isEmpty);
    }

    final module = Module.fromBytes(validBytes);

    {
      final instance = Instance.fromModule(module);
      expect(instance.module, equals(module));
      checkInstance(instance);
    }

    {
      final instance = await Instance.fromModuleAsync(module);
      expect(instance.module, equals(module));
      checkInstance(instance);
    }

    {
      final instance = Instance.fromBytes(validBytes);
      checkInstance(instance);
    }

    {
      final instance = await Instance.fromBytesAsync(validBytes);
      checkInstance(instance);
    }

    {
      final instance = Instance.fromBuffer(validBuffer);
      checkInstance(instance);
    }

    {
      final instance = await Instance.fromBufferAsync(validBuffer);
      checkInstance(instance);
    }
  });

  test('Compile error on instantiation', () {
    expect(() => Instance.fromBytes(invalidBytes), throwsA(isCompileError));

    expect(() => Instance.fromBuffer(invalidBuffer), throwsA(isCompileError));

    expect(
        () => Instance.fromBytesAsync(invalidBytes), throwsA(isCompileError));

    expect(
        () => Instance.fromBufferAsync(invalidBuffer), throwsA(isCompileError));
  });

  test('Instantiate with imports map', () {
    final module = Module.fromBytes(fullModule);
    final importsMap = {
      'js': {'mem': Memory(1), 'tbl': Table(1)},
      'env': {'val': 42, 'foo': (int v) => v * 2}
    };

    final instance = Instance.fromModule(module, importMap: importsMap);
    expect(instance, const TypeMatcher<Instance>());
  });

  test('Instantiate with imports object', () {
    final module = Module.fromBytes(fullModule);
    final instance = Instance.fromModule(module, importObject: importObject);
    expect(instance, const TypeMatcher<Instance>());
  });

  test('Instantiate & run', () {
    final importsMap = {
      'js': {'mem': Memory(1), 'tbl': Table(1)},
      'env': {'val': 42, 'foo': (int v) => v * 2}
    };
    final instance = Instance.fromBytes(fullModule, importMap: importsMap);

    expect(instance.memories, isEmpty);
    expect(instance.tables, isEmpty);

    expect(instance.globals, hasLength(1));
    final baz = instance.globals['baz'];
    if (baz is num) {
      expect(baz, equals(13));
    } else {
      expect(baz, const TypeMatcher<Global>());
      expect((baz as Global).value, equals(13));
    }

    expect(instance.functions, hasLength(1));
    expect(instance.functions['bar'](), equals(84));
  });

  test('Invalid imports', () {
    final importsMap1 = {
      'js': {'mem': Memory(1), 'tbl': Table(1)},
    };

    expect(() => Instance.fromBytes(fullModule, importMap: importsMap1),
        throwsA(const TypeMatcher<Error>()));

    final importsMap2 = {
      'js': {'tbl': Memory(1), 'mem': Table(1)},
      'env': {'val': 42, 'foo': (int v) => v * 2}
    };

    expect(() => Instance.fromBytes(fullModule, importMap: importsMap2),
        throwsA(isLinkError));
  });
}
