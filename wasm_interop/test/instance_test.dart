//ignore_for_file: avoid_dynamic_calls

@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

import 'helper_imports_object.dart';

void main() {
  group('Empty', () {
    final validBytes = Uint8List.fromList([0, 0x61, 0x73, 0x6d, 1, 0, 0, 0]);

    void checkInstance(Instance instance, [Module? module]) {
      if (module != null) {
        expect(instance.module, module);
      }
      expect(instance.functions, isEmpty);
      expect(instance.globals, isEmpty);
      expect(instance.memories, isEmpty);
      expect(instance.tables, isEmpty);
    }

    test('From bytes async',
        () async => checkInstance(await Instance.fromBytesAsync(validBytes)));

    test(
        'From buffer async',
        () async =>
            checkInstance(await Instance.fromBufferAsync(validBytes.buffer)));

    final module = Module.fromBytes(validBytes);

    test('From module sync',
        () => checkInstance(Instance.fromModule(module), module));

    test(
        'From module async',
        () async =>
            checkInstance(await Instance.fromModuleAsync(module), module));

    test('Invalid source throws CompileError', () {
      final invalidBytes =
          Uint8List.fromList([0, 0x61, 0x73, 0x6d, 0, 0, 0, 0]);

      expect(() => Instance.fromBytesAsync(invalidBytes),
          throwsA(isA<CompileError>()));

      expect(() => Instance.fromBufferAsync(invalidBytes.buffer),
          throwsA(isA<CompileError>()));
    });

    test('RuntimeError on instantiation', () {
      /// (module
      ///  (start $~start)
      ///  (func $~start
      ///   unreachable
      ///  )
      /// )
      final moduleBytes = Uint8List.fromList('\x00\x61\x73\x6D\x01\x00\x00\x00'
              '\x01\x04\x01\x60\x00\x00\x03\x02\x01\x00\x08\x01\x00\x0A\x05\x01'
              '\x03\x00\x00\x0B'
          .codeUnits);

      final module = Module.fromBytes(moduleBytes);

      expect(() => Instance.fromModule(module), throwsA(isA<RuntimeError>()));

      expect(
          () => Instance.fromModuleAsync(module), throwsA(isA<RuntimeError>()));

      expect(() => Instance.fromBytesAsync(moduleBytes),
          throwsA(isA<RuntimeError>()));

      expect(() => Instance.fromBufferAsync(moduleBytes.buffer),
          throwsA(isA<RuntimeError>()));
    });
  });

  group('Imports', () {
    /// (module
    ///  (import "js" "m" (memory 1))
    ///  (import "js" "t" (table 1 anyfunc))
    ///  (import "env" "g" (global i32))
    ///  (import "env" "g64" (global i64))
    ///  (import "env" "f" (func))
    /// )
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x2E\x05'
                '\x02\x6A\x73\x01\x6D\x02\x00\x01\x02\x6A\x73\x01\x74\x01\x70'
                '\x00\x01\x03\x65\x6E\x76\x01\x67\x03\x7F\x00\x03\x65\x6E\x76'
                '\x03\x67\x36\x34\x03\x7E\x00\x03\x65\x6E\x76\x01\x66\x00\x00'
            .codeUnits);

    final module = Module.fromBytes(moduleBytes);

    test('Instantiate with map', () {
      final importMap = {
        'js': {'m': Memory(initial: 1), 't': Table.funcref(initial: 1)},
        'env': {'g': 1, 'g64': BigInt.one, 'f': () => 2}
      };

      expect(
          Instance.fromModule(module, importMap: importMap), isA<Instance>());

      expect(Instance.fromModuleAsync(module, importMap: importMap),
          completion(isA<Instance>()));

      expect(Instance.fromBytesAsync(moduleBytes, importMap: importMap),
          completion(isA<Instance>()));

      expect(Instance.fromBufferAsync(moduleBytes.buffer, importMap: importMap),
          completion(isA<Instance>()));
    });

    test('Instantiate with object', () {
      expect(Instance.fromModule(module, importObject: importObject),
          isA<Instance>());

      expect(Instance.fromModuleAsync(module, importObject: importObject),
          completion(isA<Instance>()));

      expect(Instance.fromBytesAsync(moduleBytes, importObject: importObject),
          completion(isA<Instance>()));

      expect(
          Instance.fromBufferAsync(moduleBytes.buffer,
              importObject: importObject),
          completion(isA<Instance>()));
    });

    test('Missing', () {
      final importMap = {
        'js': {'m': Memory(initial: 1), 't': Table.funcref(initial: 1)}
      };

      expect(() => Instance.fromModule(module, importMap: importMap),
          throwsA(anything));

      expect(() => Instance.fromModuleAsync(module, importMap: importMap),
          throwsA(anything));

      expect(() => Instance.fromBytesAsync(moduleBytes, importMap: importMap),
          throwsA(anything));

      expect(
          () => Instance.fromBufferAsync(moduleBytes.buffer,
              importMap: importMap),
          throwsA(anything));
    });

    test('Invalid', () {
      final importMap = {
        'js': {'t': Memory(initial: 1), 'm': Table.funcref(initial: 1)},
        'env': {'g': 1, 'f': () => 2}
      };

      expect(() => Instance.fromModule(module, importMap: importMap),
          throwsA(isA<LinkError>()));

      expect(() => Instance.fromModuleAsync(module, importMap: importMap),
          throwsA(isA<LinkError>()));

      expect(() => Instance.fromBytesAsync(moduleBytes, importMap: importMap),
          throwsA(isA<LinkError>()));

      expect(
          () => Instance.fromBufferAsync(moduleBytes.buffer,
              importMap: importMap),
          throwsA(isA<LinkError>()));
    });
  });

  group('Run', () {
    test('Memory access', () {
      /// (module
      ///  (import "env" "m" (memory $m 1))
      ///  (func (export "f")
      ///   i32.const 4
      ///   i32.const 4
      ///   i32.load
      ///   i32.const 1
      ///   i32.add
      ///   i32.store
      ///  )
      ///  (export "m" (memory 0))
      /// )
      final moduleBytes = Uint8List.fromList(
          '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x0A\x01'
                  '\x03\x65\x6E\x76\x01\x6D\x02\x00\x01\x03\x02\x01\x00\x07\x09'
                  '\x02\x01\x66\x00\x00\x01\x6D\x02\x00\x0A\x11\x01\x0F\x00\x41'
                  '\x04\x41\x04\x28\x02\x00\x41\x01\x6A\x36\x02\x00\x0B'
              .codeUnits);

      final memory = Memory(initial: 1);
      final memoryView = memory.buffer.asUint32List();
      memoryView[1] = 42;

      final instance =
          Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
        'env': {'m': memory}
      });

      final exportedMemory = instance.memories['m']!;
      expect(exportedMemory, memory);

      final exportedMemoryView = exportedMemory.buffer.asUint32List();
      expect(exportedMemoryView[1], 42);
      instance.functions['f']!();
      expect(exportedMemoryView[1], 43);
    });

    test('Globals', () {
      /// (module
      ///  (global (import "env" "v_i32") i32)
      ///  (global (import "env" "v_i64") i64)
      ///  (global (import "env" "v_f32") f32)
      ///  (global (import "env" "v_f64") f64)
      ///  (func (export "g_i32") (result i32)
      ///   global.get 0
      ///   i32.const 1
      ///   i32.add
      ///  )
      ///  (func (export "g_i64") (result i64)
      ///   global.get 1
      ///   i64.const 1
      ///   i64.add
      ///  )
      ///  (func (export "g_f32") (result f32)
      ///   global.get 2
      ///   f32.const 1.0
      ///   f32.add
      ///  )
      ///  (func (export "g_f64") (result f64)
      ///   global.get 3
      ///   f64.const 1.0
      ///   f64.add
      ///  )
      ///  (export "v_i32" (global 0))
      ///  (export "v_i64" (global 1))
      ///  (export "v_f32" (global 2))
      ///  (export "v_f64" (global 3))
      /// )
      final moduleBytes = Uint8List.fromList(
          '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x11\x04\x60\x00\x01\x7F\x60\x00'
                  '\x01\x7E\x60\x00\x01\x7D\x60\x00\x01\x7C\x02\x35\x04\x03\x65'
                  '\x6E\x76\x05\x76\x5F\x69\x33\x32\x03\x7F\x00\x03\x65\x6E\x76'
                  '\x05\x76\x5F\x69\x36\x34\x03\x7E\x00\x03\x65\x6E\x76\x05\x76'
                  '\x5F\x66\x33\x32\x03\x7D\x00\x03\x65\x6E\x76\x05\x76\x5F\x66'
                  '\x36\x34\x03\x7C\x00\x03\x05\x04\x00\x01\x02\x03\x07\x41\x08'
                  '\x05\x67\x5F\x69\x33\x32\x00\x00\x05\x67\x5F\x69\x36\x34\x00'
                  '\x01\x05\x67\x5F\x66\x33\x32\x00\x02\x05\x67\x5F\x66\x36\x34'
                  '\x00\x03\x05\x76\x5F\x69\x33\x32\x03\x00\x05\x76\x5F\x69\x36'
                  '\x34\x03\x01\x05\x76\x5F\x66\x33\x32\x03\x02\x05\x76\x5F\x66'
                  '\x36\x34\x03\x03\x0A\x2B\x04\x07\x00\x23\x00\x41\x01\x6A\x0B'
                  '\x07\x00\x23\x01\x42\x01\x7C\x0B\x0A\x00\x23\x02\x43\x00\x00'
                  '\x80\x3F\x92\x0B\x0E\x00\x23\x03\x44\x00\x00\x00\x00\x00\x00'
                  '\xF0\x3F\xA0\x0B'
              .codeUnits);

      void checkValues(Instance instance) {
        final functions = instance.functions;
        expect(functions['g_i32']!(), 26);
        expect(
            JsBigInt.toBigInt(functions['g_i64']!() as Object), BigInt.from(3));
        expect(functions['g_f32']!(), 1.5);
        expect(functions['g_f64']!(), 1.2);

        final globals = instance.globals;
        expect(globals['v_i32']!.value, 25);
        expect(globals['v_i64']!.value, BigInt.two);
        expect(globals['v_f32']!.value, 0.5);
        expect(globals['v_f64']!.value, 0.2);
      }

      checkValues(
          Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
        'env': {'v_i32': 25, 'v_i64': BigInt.two, 'v_f32': 0.5, 'v_f64': 0.2}
      }));

      checkValues(
          Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
        'env': {
          'v_i32': Global.i32(value: 25),
          'v_i64': Global.i64(value: BigInt.two),
          'v_f32': Global.f32(value: 0.5),
          'v_f64': Global.f64(value: 0.2)
        }
      }));
    });

    test('Globals - externref', () {
      /// (module
      ///  (global (import "env" "v_ref") externref)
      ///  (global (export "v_ref") (mut externref) ref.null extern)
      ///  (func (export "copy")
      ///   global.get 0
      ///   global.set 1
      ///  )
      /// )
      final moduleBytes = Uint8List.fromList(
          '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x04\x01\x60\x00\x00\x02\x0E\x01'
                  '\x03\x65\x6E\x76\x05\x76\x5F\x72\x65\x66\x03\x6F\x00\x03\x02'
                  '\x01\x00\x06\x06\x01\x6F\x01\xD0\x6F\x0B\x07\x10\x02\x05\x76'
                  '\x5F\x72\x65\x66\x03\x01\x04\x63\x6F\x70\x79\x00\x00\x0A\x08'
                  '\x01\x06\x00\x23\x00\x24\x01\x0B'
              .codeUnits);

      assert(() {
        expect(
            () => Instance.fromModule(Module.fromBytes(moduleBytes),
                    importMap: const {
                      'env': {'v_ref': 'dart'}
                    }),
            throwsA(isA<AssertionError>()));
        return true;
      }());

      final instance =
          Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
        'env': {'v_ref': Global.externref(value: 'dart')}
      });

      final globals = instance.globals;
      expect(globals['v_ref']!.value, isNull);
      instance.functions['copy']!();
      expect(globals['v_ref']!.value, 'dart');
    }, testOn: 'firefox');
  });

  test('Functions', () {
    /// (module
    ///  (import "env" "mul2_i32" (func $env/mul2_i32 (param i32) (result i32)))
    ///  (import "env" "mul2_i64" (func $env/mul2_i64 (param i64) (result i64)))
    ///  (import "env" "mul2_f32" (func $env/mul2_f32 (param f32) (result f32)))
    ///  (import "env" "mul2_f64" (func $env/mul2_f64 (param f64) (result f64)))
    ///  (export "sum" (func $env/sum))
    ///  (func $env/sum (param $0 i32) (param $1 i64) (param $2 f32) (result f64)
    ///   local.get $0
    ///   call $env/mul2_i32
    ///   f64.convert_i32_s
    ///   local.get $1
    ///   call $env/mul2_i64
    ///   f64.convert_i64_s
    ///   f64.add
    ///   local.get $2
    ///   call $env/mul2_f32
    ///   f64.promote_f32
    ///   f64.add
    ///   call $env/mul2_f64
    ///  )
    /// )
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x1C\x05\x60\x01\x7F\x01\x7F\x60'
                '\x01\x7E\x01\x7E\x60\x01\x7D\x01\x7D\x60\x01\x7C\x01\x7C\x60'
                '\x03\x7F\x7E\x7D\x01\x7C\x02\x3D\x04\x03\x65\x6E\x76\x08\x6D'
                '\x75\x6C\x32\x5F\x69\x33\x32\x00\x00\x03\x65\x6E\x76\x08\x6D'
                '\x75\x6C\x32\x5F\x69\x36\x34\x00\x01\x03\x65\x6E\x76\x08\x6D'
                '\x75\x6C\x32\x5F\x66\x33\x32\x00\x02\x03\x65\x6E\x76\x08\x6D'
                '\x75\x6C\x32\x5F\x66\x36\x34\x00\x03\x03\x02\x01\x04\x07\x07'
                '\x01\x03\x73\x75\x6D\x00\x04\x0A\x17\x01\x15\x00\x20\x00\x10'
                '\x00\xB7\x20\x01\x10\x01\xB9\xA0\x20\x02\x10\x02\xBB\xA0\x10'
                '\x03\x0B'
            .codeUnits);

    final instance =
        Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
      'env': {
        'mul2_i32': (int v) => v * 2,
        'mul2_i64': (Object v) => (JsBigInt.toBigInt(v) * BigInt.two).toJs(),
        'mul2_f32': (double v) => v * 2,
        'mul2_f64': (double v) => v * 2
      }
    });

    expect(instance.functions['sum']!(12, BigInt.two.toJs(), 0.5), 58);
  });

  test('Functions - externref', () {
    /// (module
    ///  (import "env" "len" (func $env/len (param externref) (result i32)))
    ///  (func (export "select") (param $0 externref) (param $1 externref)
    ///   (result externref)
    ///   local.get $0
    ///   local.get $1
    ///   local.get $0
    ///   call $env/len
    ///   local.get $1
    ///   call $env/len
    ///   i32.ge_s
    ///   select (result externref)
    ///  )
    /// )
    final moduleBytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x0C\x02\x60\x01\x6F\x01\x7F\x60'
                '\x02\x6F\x6F\x01\x6F\x02\x0B\x01\x03\x65\x6E\x76\x03\x6C\x65'
                '\x6E\x00\x00\x03\x02\x01\x01\x07\x0A\x01\x06\x73\x65\x6C\x65'
                '\x63\x74\x00\x01\x0A\x14\x01\x12\x00\x20\x00\x20\x01\x20\x00'
                '\x10\x00\x20\x01\x10\x00\x4E\x1C\x01\x6F\x0B'
            .codeUnits);

    final instance =
        Instance.fromModule(Module.fromBytes(moduleBytes), importMap: {
      'env': {'len': (String s) => s.length}
    });

    expect(instance.functions['select']!('string', 'longString'), 'longString');
  }, testOn: 'firefox');

  test('Tables', () {
    /// (module
    ///  (func (export "dec") (param $0 i32) (result i32)
    ///   local.get $0
    ///   i32.const 1
    ///   i32.sub
    ///  )
    /// )
    final module1Bytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x03'
                '\x02\x01\x00\x07\x07\x01\x03\x64\x65\x63\x00\x00\x0A\x09\x01'
                '\x07\x00\x20\x00\x41\x01\x6B\x0B'
            .codeUnits);
    final exportedFunction =
        Instance.fromModule(Module.fromBytes(module1Bytes)).functions['dec']!;

    expect(exportedFunction(3), 2);

    /// (module
    ///  (table (export "tbl") 1 funcref)
    ///  (elem (i32.const 0) $f0)
    ///  (func $f0 (param $0 i32) (result i32)
    ///   local.get $0
    ///   i32.const 1
    ///   i32.add
    ///  )
    /// )
    final module2Bytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x03'
                '\x02\x01\x00\x04\x04\x01\x70\x00\x01\x07\x07\x01\x03\x74\x62'
                '\x6C\x01\x00\x09\x07\x01\x00\x41\x00\x0B\x01\x00\x0A\x09\x01'
                '\x07\x00\x20\x00\x41\x01\x6A\x0B'
            .codeUnits);
    final exportedTable =
        Instance.fromModule(Module.fromBytes(module2Bytes)).tables['tbl']!;

    expect((exportedTable[0]! as Function)(4), 5);

    exportedTable.grow(1);
    exportedTable[1] = exportedFunction;
    expect((exportedTable[1]! as Function)(7), 6);

    /// (module
    ///  (type $t0 (func (param i32) (result i32)))
    ///  (table (import "env" "tbl") 2 funcref)
    ///  (func (export "f0") (type $t0) (param $0 i32) (result i32)
    ///   local.get $0
    ///   i32.const 0
    ///   call_indirect (type $t0)
    ///  )
    ///  (func (export "f1") (type $t0) (param $0 i32) (result i32)
    ///   local.get $0
    ///   i32.const 1
    ///   call_indirect (type $t0)
    ///  )
    /// )
    final module3Bytes = Uint8List.fromList(
        '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x02'
                '\x0D\x01\x03\x65\x6E\x76\x03\x74\x62\x6C\x01\x70\x00\x02\x03'
                '\x03\x02\x00\x00\x07\x0B\x02\x02\x66\x30\x00\x00\x02\x66\x31'
                '\x00\x01\x0A\x15\x02\x09\x00\x20\x00\x41\x00\x11\x00\x00\x0B'
                '\x09\x00\x20\x00\x41\x01\x11\x00\x00\x0B'
            .codeUnits);
    final instance =
        Instance.fromModule(Module.fromBytes(module3Bytes), importMap: {
      'env': {'tbl': exportedTable}
    });

    expect(instance.functions['f0']!(10), 11);
    expect(instance.functions['f1']!(13), 12);
  });
}
