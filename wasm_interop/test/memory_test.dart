@TestOn('js')
import 'package:test/test.dart';
import 'package:wasm_interop/wasm_interop.dart';

void main() {
  test('Create with initial size', () {
    final memory = Memory(42);
    expect(memory, const TypeMatcher<Memory>());
    expect(memory.lengthInPages, equals(42));
    expect(memory.lengthInBytes, equals(2752512));
  });

  test('Create memory with invalid size', () {
    expect(() => Memory(-1), throwsA(const TypeMatcher<AssertionError>()));

    expect(() => Memory(null), throwsA(const TypeMatcher<AssertionError>()));

    expect(() => Memory(42, maximum: 1),
        throwsA(const TypeMatcher<AssertionError>()));
  });

  test('Create memory and grow', () {
    final memory = Memory(42)..grow(10);

    expect(memory.lengthInPages, 52);
  });

  test('Create table with maximum and grow', () {
    final memory = Memory(42, maximum: 52)..grow(10);

    expect(memory.lengthInPages, 52);
  });

  test('Create table with maximum and grow beyond', () {
    final memory = Memory(42, maximum: 43);

    expect(() {
      memory.grow(2);
    }, throwsA(const TypeMatcher<ArgumentError>()));
  });
}
