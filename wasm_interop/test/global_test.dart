@TestOn('js')
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

void main() {
  test('Default values', () {
    {
      final i32 = Global.i32();

      expect(i32.value, 0);
    }
    {
      final f32 = Global.f32();
      expect(f32.value, 0);
    }
    {
      final f64 = Global.f64();
      expect(f64.value, 0);
    }
  });

  test('Custom values', () {
    {
      final i32 = Global.i32(value: 1);
      expect(i32.value, 1);
    }
    {
      final f32 = Global.f32(value: 0.1);
      expect(f32.value, 0.10000000149011612); // rounded to 32-bit float
    }
    {
      final f64 = Global.f64(value: 0.1);
      expect(f64.value, 0.1);
    }
  });

  test('Mutable values', () {
    {
      final i32 = Global.i32(mutable: true);
      expect(++i32.value, 1);
    }
    {
      final f32 = Global.f32(mutable: true);
      expect(++f32.value, 1);
    }
    {
      final f64 = Global.f64(mutable: true);
      expect(++f64.value, 1);
    }
  });

  test('Immutable values', () {
    {
      final i32 = Global.i32();
      expect(() => ++i32.value, throwsA(anything));
    }
    {
      final f32 = Global.f32();
      expect(() => ++f32.value, throwsA(anything));
    }
    {
      final f64 = Global.f64();
      expect(() => ++f64.value, throwsA(anything));
    }
  });

  test('Integer 64', () {
    {
      final i64 = Global.i64();
      expect(() => i64.value, throwsA(anything));
    }
    {
      final i64 = Global.i64(mutable: true);
      expect(() => i64.value = 1, throwsA(anything));
    }
  }, testOn: 'firefox');
}
