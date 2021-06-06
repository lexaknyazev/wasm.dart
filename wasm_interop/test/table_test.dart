@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

void main() {
  test('Create and grow', () {
    final table = Table.funcref(initial: 42);

    expect(table.length, 42);

    expect(table.grow(10), 42);
    expect(table.length, 52);
  });

  test('Create and grow - externref', () {
    final table = Table.externref(initial: 42);

    expect(table.length, 42);

    expect(table.grow(10), 42);
    expect(table.length, 52);
  }, testOn: 'firefox');

  test('Create with maximum and grow', () {
    final table = Table.funcref(initial: 42, maximum: 52);

    expect(table.grow(10), 42);
    expect(table.length, 52);
  });

  test('Create with maximum and grow - externref', () {
    final table = Table.externref(initial: 42, maximum: 52);

    expect(table.grow(10), 42);
    expect(table.length, 52);
  }, testOn: 'firefox');

  test('Create table with maximum and grow beyond', () {
    final table = Table.funcref(initial: 42, maximum: 43);

    expect(() {
      table.grow(2);
    }, throwsA(isA<ArgumentError>()));
  });

  test('Create table with maximum and grow beyond - externref', () {
    final table = Table.externref(initial: 42, maximum: 43);

    expect(() {
      table.grow(2);
    }, throwsA(isA<ArgumentError>()));
  }, testOn: 'firefox');

  assert(() {
    test('Create table with invalid size', () {
      expect(() => Table.funcref(initial: -1), throwsA(isA<AssertionError>()));

      expect(() => Table.funcref(initial: 42, maximum: 1),
          throwsA(isA<AssertionError>()));
    });

    test('Create table with invalid size - externref', () {
      expect(
          () => Table.externref(initial: -1), throwsA(isA<AssertionError>()));

      expect(() => Table.externref(initial: 42, maximum: 1),
          throwsA(isA<AssertionError>()));
    }, testOn: 'firefox');

    return true;
  }());

  ///(module
  /// (table (export "tbl") 1 funcref)
  /// (elem (i32.const 0) $f0)
  /// (func $f0 (param $0 i32) (result i32)
  ///  local.get $0
  ///  i32.const 1
  ///  i32.add
  /// )
  ///)
  final _moduleTableInc = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x03\x02'
              '\x01\x00\x04\x04\x01\x70\x00\x01\x07\x07\x01\x03\x74\x62\x6C\x01'
              '\x00\x09\x07\x01\x00\x41\x00\x0B\x01\x00\x0A\x09\x01\x07\x00\x20'
              '\x00\x41\x01\x6A\x0B'
          .codeUnits);

  test('Index operators', () {
    final func = Instance.fromModule(Module.fromBytes(_moduleTableInc))
        .tables['tbl']![0]! as int Function(int i);
    expect(func(1), 2);

    final table = Table.funcref(initial: 1);
    table[0] = func;
    expect(table[0], equals(func));
  });

  test('Index operators - externref', () {
    final table = Table.externref(initial: 1);
    table[0] = 'dart';
    expect(table[0], 'dart');
  }, testOn: 'firefox');

  test('Index operators OOR', () {
    final func = Instance.fromModule(Module.fromBytes(_moduleTableInc))
        .tables['tbl']![0];

    final table = Table.funcref(initial: 1);

    expect(() {
      table[1] = func;
    }, throwsA(isA<ArgumentError>()));

    expect(() => table[1], throwsA(isA<ArgumentError>()));
  });

  test('Index operators OOR - externref', () {
    final table = Table.externref(initial: 1);

    expect(() {
      table[1] = 'dart';
    }, throwsA(isA<ArgumentError>()));

    expect(() => table[1], throwsA(isA<ArgumentError>()));
  }, testOn: 'firefox');
}
