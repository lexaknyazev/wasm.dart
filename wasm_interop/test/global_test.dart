@TestOn('js')
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

void main() {
  group('Default values', () {
    test('i32', () => expect(Global.i32().value, isZero));
    test('i64', () => expect(Global.i64().value, BigInt.zero));
    test('f32', () => expect(Global.f32().value, isZero));
    test('f64', () => expect(Global.f64().value, isZero));
    test('externref', () => expect(Global.externref().value, isNull),
        testOn: 'firefox');
  });

  group('Initial values', () {
    test('i32', () => expect(Global.i32(value: 1).value, 1));
    test('i64', () => expect(Global.i64(value: BigInt.two).value, BigInt.two));
    test('f32', () => expect(Global.f32(value: 0.1).value, .10000000149011612));
    test('f64', () => expect(Global.f64(value: 0.1).value, 0.1));
    test('externref',
        () => expect(Global.externref(value: 'StrValue').value, 'StrValue'),
        testOn: 'firefox');
  });

  group('Mutable values', () {
    test('i32', () {
      final i32 = Global.i32(mutable: true, value: 1);
      i32.value = (i32.value! as int) + 1;
      expect(i32.value, 2);
    });
    test('i64', () {
      final i64 =
          Global.i64(mutable: true, value: BigInt.parse('9007199254740992'));
      i64.value = (i64.value! as BigInt) + BigInt.one;
      expect(i64.value, BigInt.parse('9007199254740993'));
    });
    test('f32', () {
      final f32 = Global.f32(mutable: true, value: 0.1);
      f32.value = (f32.value! as double) + 0.2;
      expect(f32.value, 0.30000001192092896);
    });
    test('f64', () {
      final f64 = Global.f64(mutable: true, value: 0.1);
      f64.value = (f64.value! as double) + 0.2;
      expect(f64.value, 0.30000000000000004);
    });
    test('externref', () {
      final ref = Global.externref(mutable: true, value: 'strA')
        ..value = 'strB';
      expect(ref.value, 'strB');
    }, testOn: 'firefox');
  });

  group('Immutable values', () {
    test('i32',
        () => expect(() => Global.i32().value = 1, throwsA(isA<Error>())));
    test(
        'i64',
        () => expect(
            () => Global.i64().value = BigInt.one, throwsA(isA<Error>())));
    test('f32',
        () => expect(() => Global.f32().value = 0.5, throwsA(isA<Error>())));
    test('f64',
        () => expect(() => Global.f64().value = 0.5, throwsA(isA<Error>())));
    test(
        'externref',
        () =>
            expect(() => Global.externref().value = '', throwsA(isA<Error>())),
        testOn: 'firefox');
  });
}
