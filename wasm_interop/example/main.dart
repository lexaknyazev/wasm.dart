import 'dart:math';
import 'dart:typed_data';
import 'package:wasm_interop/wasm_interop.dart';

Future main() async {
  await reinterpret();
  await count();
}

Future reinterpret() async {
  /// (module
  ///  (func (export "reinterpret_i64") (param $0 f64) (result i64)
  ///   local.get $0
  ///   i64.reinterpret_f64
  ///  )
  /// )
  final moduleBytes = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x06\x01\x60\x01\x7C\x01\x7E\x03\x02'
              '\x01\x00\x07\x13\x01\x0F\x72\x65\x69\x6E\x74\x65\x72\x70\x72\x65'
              '\x74\x5F\x69\x36\x34\x00\x00\x0A\x07\x01\x05\x00\x20\x00\xBD\x0B'
          .codeUnits);

  final instance = await Instance.fromBytesAsync(moduleBytes);

  // The function reinterprets bits of an input float64 value as bits of a
  // 64-bit integer and returns it.
  final reinterpretFunction =
      instance.functions['reinterpret_i64']! as Object Function(double v);
  final d = Random().nextDouble();
  final reinterpreted = JsBigInt.toBigInt(reinterpretFunction(d));

  print('$d -> $reinterpreted');
}

Future count() async {
  /// (module
  ///  (memory (export "memory") 1 1)
  ///  (func (export "count") (result i32)
  ///   (local $0 i32)  (local $1 i64)
  ///   loop $for-loop|0
  ///    local.get $0
  ///    i32.const 65536
  ///    i32.lt_s
  ///    if
  ///     local.get $1
  ///     local.get $0
  ///     i64.load
  ///     i64.popcnt
  ///     i64.add
  ///     local.set $1
  ///     local.get $0
  ///     i32.const 8
  ///     i32.add
  ///     local.set $0
  ///     br $for-loop|0
  ///    end
  ///   end
  ///   local.get $1
  ///   i32.wrap_i64
  ///  )
  /// )
  final moduleBytes = Uint8List.fromList(
      '\x00\x61\x73\x6D\x01\x00\x00\x00\x01\x05\x01\x60\x00\x01\x7F\x03\x02\x01'
              '\x00\x05\x04\x01\x01\x01\x01\x07\x12\x02\x06\x6D\x65\x6D\x6F\x72'
              '\x79\x02\x00\x05\x63\x6F\x75\x6E\x74\x00\x00\x0A\x2C\x01\x2A\x02'
              '\x01\x7F\x01\x7E\x03\x40\x20\x00\x41\x80\x80\x04\x48\x04\x40\x20'
              '\x01\x20\x00\x29\x03\x00\x7B\x7C\x21\x01\x20\x00\x41\x08\x6A\x21'
              '\x00\x0C\x01\x0B\x0B\x20\x01\xA7\x0B'
          .codeUnits);

  final instance = await Instance.fromBytesAsync(moduleBytes);

  // The module exports a 1-page memory object. Fill it with random bytes.
  final memoryView = instance.memories['memory']!.buffer.asUint8List();
  final r = Random();
  for (var i = 0; i < memoryView.length; i++) {
    memoryView[i] = r.nextInt(256);
  }

  // The exported function counts the total number of ones in all bytes.
  final totalCountFunction = instance.functions['count']! as int Function();

  print(totalCountFunction());
}
