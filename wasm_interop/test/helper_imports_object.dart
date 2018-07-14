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
  external factory MyEnv({num val, Function foo});
}

@JS()
@anonymous
abstract class MyJs {
  external factory MyJs({Object mem, Object tbl});
}

final Object importObject = MyImports(
    env: MyEnv(val: 42, foo: allowInterop((int v) => v * 2)),
    js: MyJs(mem: Memory(1).jsObject, tbl: Table(1).jsObject));
