@JS()
library imports_object;

import 'package:js/js.dart';
import 'package:wasm_interop/wasm_interop.dart';

@JS()
@anonymous
abstract class MyImports {
  external factory MyImports({MyEnv env, MyJs js});
}

@JS()
@anonymous
abstract class MyEnv {
  external factory MyEnv({num g, Object g64, Function f});
}

@JS()
@anonymous
abstract class MyJs {
  external factory MyJs({Object m, Object t});
}

final importObject = MyImports(
    env: MyEnv(g: 1, g64: BigInt.one.toJs(), f: allowInterop(() => 2)),
    js: MyJs(
        m: Memory(initial: 1).jsObject, t: Table.funcref(initial: 1).jsObject));
