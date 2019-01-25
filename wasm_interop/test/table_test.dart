@TestOn('js')
import 'dart:typed_data';
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

final _moduleTableInc = Uint8List.fromList(
    '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x03\x02'
        '\x01\x00\x04\x04\x01\x70\x00\x01\x07\x07\x01\x03\x74\x62\x6C\x01\x00'
        '\x09\x07\x01\x00\x41\x00\x0B\x01\x00\x0A\x09\x01\x07\x00\x20\x00\x41'
        '\x01\x6A\x0B'
        .codeUnits);

final _moduleTableDec = Uint8List.fromList(
    '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7F\x01\x7F\x03\x02'
        '\x01\x00\x04\x04\x01\x70\x00\x01\x07\x07\x01\x03\x74\x62\x6C\x01\x00'
        '\x09\x07\x01\x00\x41\x00\x0B\x01\x00\x0A\x09\x01\x07\x00\x20\x00\x41'
        '\x01\x6B\x0B'
        .codeUnits);

void main() {
  test('Create with initial size', () {
    final table = Table(42);
    expect(table, const TypeMatcher<Table>());
    expect(table.length, equals(42));
  });

  assert(() {
    test('Create table with invalid size', () {
      expect(() => Table(-1), throwsA(const TypeMatcher<AssertionError>()));

      expect(() => Table(null), throwsA(const TypeMatcher<AssertionError>()));

      expect(() => Table(42, maximum: 1),
          throwsA(const TypeMatcher<AssertionError>()));
    });
    return true;
  }());

  test('Create table and grow', () {
    final table = Table(42)..length += 10;

    expect(table.length, 52);
  });

  test('Create table with maximum and grow', () {
    final table = Table(42, maximum: 52)..length += 10;

    expect(table.length, 52);
  });

  test('Create table with maximum and grow beyond', () {
    final table = Table(42, maximum: 43);

    expect(() {
      table.length += 2;
    }, throwsA(const TypeMatcher<ArgumentError>()));
  });

  test('Index operators', () {
    final func = Instance.fromBytes(_moduleTableInc).tables['tbl'][0];

    expect(func(1), 2);

    final table = Table(1);
    table[0] = func;
    expect(table[0], equals(func));

    // invocation through table
    expect(table[0](), 1);
    expect(table[0](1), 2);
    expect(table[0](1, 2), 2);
  });

  test('Index operators OOR', () {
    final func = Instance.fromBytes(_moduleTableInc).tables['tbl'][0];

    final table = Table(1);

    expect(() {
      table[1] = func;
    }, throwsA(const TypeMatcher<ArgumentError>()));

    expect(() => table[1], throwsA(const TypeMatcher<ArgumentError>()));
  });

  test('Operator add', () {
    final func1 = Instance.fromBytes(_moduleTableInc).tables['tbl'][0];
    final func2 = Instance.fromBytes(_moduleTableDec).tables['tbl'][0];

    final table1 = Table(1);
    final table2 = Table(1);

    table1[0] = func1;
    table2[0] = func2;

    final table3 = table1 + table2;

    expect(table3.length, 2);

    expect(table3[0], equals(table1[0]));
    expect(table3[0](2), func1(2));

    expect(table3[1], equals(table2[0]));
    expect(table3[1](2), func2(2));
  });

  test('Method add', () {
    final func = Instance.fromBytes(_moduleTableInc).tables['tbl'][0];

    final table = Table(1, maximum: 2);

    expect(() {
      table.add(func);
    }, returnsNormally);

    expect(() {
      table.add(func);
    }, throwsA(const TypeMatcher<RangeError>()));
  });

  test('Method addAll', () {
    final func = Instance.fromBytes(_moduleTableInc).tables['tbl'][0];

    final table = Table(1, maximum: 2);

    expect(() {
      table.addAll([func]);
    }, returnsNormally);

    expect(() {
      table.addAll([func]);
    }, throwsA(const TypeMatcher<RangeError>()));
  });
}
