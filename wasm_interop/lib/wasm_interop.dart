/// Dart wrapper for WebAssembly JavaScript API
@JS()
library wasm_interop;

import 'dart:async';
import 'dart:collection';
import 'dart:typed_data';
import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:meta/meta.dart';

/// Compiled WebAssembly module.
///
/// A [Module] can be compiled from [Uint8List] or [ByteBuffer] source data.
/// When data length exceeds 4 KB, some runtimes may require asynchronous
/// compilation via [Module.fromBufferAsync] or [Module.fromBytesAsync].
@immutable
class Module {
  /// JavaScript `WebAssembly.Module` object
  final _Module jsObject;

  Module._(this.jsObject);

  /// Synchronously compiles WebAssembly [Module] from [Uint8List] source.
  ///
  /// Throws a [CompileError] on invalid module source.
  /// Some runtimes do not allow synchronous compilation of modules
  /// bigger than 4 KB in the main thread. In such case, an [ArgumentError]
  /// will be thrown.
  Module.fromBytes(Uint8List bytes) : jsObject = _Module(bytes);

  /// Synchronously compiles WebAssembly [Module] from [ByteBuffer] source.
  ///
  /// Throws a [CompileError] on invalid module source.
  /// Some runtimes do not allow synchronous compilation of modules
  /// bigger than 4 KB in the main thread. In such case, an [ArgumentError]
  /// will be thrown.
  Module.fromBuffer(ByteBuffer buffer) : jsObject = _Module(buffer);

  /// Builds and returns a list of module's export descriptors.
  List<ModuleExportDescriptor> get exports {
    final jsExports = _Module.exports(jsObject).cast<_ModuleExportDescriptor>();
    return List.generate(
        jsExports.length, (i) => ModuleExportDescriptor._(jsExports[i]),
        growable: false);
  }

  /// Builds and returns a list of module's import descriptors.
  List<ModuleImportDescriptor> get imports {
    final jsImports = _Module.imports(jsObject).cast<_ModuleImportDescriptor>();
    return List.generate(
        jsImports.length, (i) => ModuleImportDescriptor._(jsImports[i]),
        growable: false);
  }

  /// Returns a [List] of module's custom binary sections by [sectionName].
  List<ByteBuffer> customSections(String sectionName) =>
      _Module.customSections(jsObject, sectionName).cast();

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Module` object.
  @override
  bool operator ==(Object other) =>
      other is Module && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;

  /// Asynchronously compiles WebAssembly [Module] from [Uint8List] source.
  ///
  /// Throws a [CompileError] on invalid module source.
  static Future<Module> fromBytesAsync(Uint8List bytes) =>
      promiseToFuture<_Module>(_compile(bytes))
          .then((_module) => Module._(_module));

  /// Asynchronously compiles WebAssembly [Module] from [ByteBuffer] source.
  ///
  /// Throws a [CompileError] on invalid module source.
  static Future<Module> fromBufferAsync(ByteBuffer buffer) =>
      promiseToFuture<_Module>(_compile(buffer))
          .then((_module) => Module._(_module));

  /// Returns `true` if provided WebAssembly [Uint8List] source is valid.
  static bool validateBytes(Uint8List bytes) => _validate(bytes);

  /// Returns `true` if provided WebAssembly [ByteBuffer] source is valid.
  static bool validateBuffer(ByteBuffer buffer) => _validate(buffer);
}

/// Instantiated WebAssembly module.
///
/// An [Instance] can be compiled and instantiated from [Uint8List] or
/// [ByteBuffer] source data, or from already compiled [Module].
/// When data length exceeds 4 KB, some runtimes may require asynchronous
/// compilation and instantiation via [Instance.fromBufferAsync],
/// [Instance.fromBytesAsync], or [Instance.fromModuleAsync].
@immutable
class Instance {
  /// JavaScript `WebAssembly.Instance` object
  final _Instance jsObject;

  /// WebAssembly [Module] this instance was instantiated from.
  final Module module;

  final Map<String, Function> _functions = <String, Function>{};
  final Map<String, Memory> _memories = <String, Memory>{};
  final Map<String, Table> _tables = <String, Table>{};
  final Map<String, Global> _globals = <String, Global>{};

  Instance._(this.jsObject, this.module) {
    // Fill exports helper maps
    final exportsObject = jsObject.exports;
    for (final key in _objectKeys(exportsObject).cast<String>()) {
      final value = getProperty(exportsObject, key) as Object;
      if (value is Function) {
        _functions[key] = value;
      } else if (value is _Memory && instanceof(value, _memoryConstructor)) {
        _memories[key] = Memory._(value);
      } else if (value is _Table && instanceof(value, _tableConstructor)) {
        _tables[key] = Table._(value);
      } else if (value is _Global && instanceof(value, _globalConstructor)) {
        _globals[key] = Global._(value);
      }
    }
  }

  /// Synchronously instantiates compiled WebAssembly [Module].
  ///
  /// Some runtimes do not allow synchronous instantiation of modules
  /// bigger than 4 KB in the main thread.
  ///
  /// Imports could be provided via either [importMap] parameter like this:
  /// ```
  /// final importMap = {
  ///   'env': {
  ///     'log': allowInterop(print)
  ///   }
  /// }
  ///
  /// final instance = Instance.fromModule(module, importMap: importMap);
  /// ```
  ///
  /// or via [importObject] parameter which must be a `JsObject`:
  /// ```
  /// import 'package:js/js.dart';
  ///
  /// @JS()
  /// @anonymous
  /// abstract class MyImports {
  ///   external factory MyImports({MyEnv env});
  /// }
  ///
  /// @JS()
  /// @anonymous
  /// abstract class MyEnv {
  ///   external factory MyEnv({Function log});
  /// }
  ///
  /// final importObject = MyImports(env: MyEnv(log: allowInterop(print)));
  /// final instance = Instance.fromModule(module, importObject: importObject);
  factory Instance.fromModule(Module module,
          {Map<String, Map<String, Object>>? importMap,
          Object? importObject}) =>
      Instance._(
          _Instance(module.jsObject, _reifyImports(importMap, importObject)),
          module);

  /// A `JsObject` representing instantiated module's exports.
  ///
  /// This object may be directly cast to an anonymous JS class representing
  /// the exported members to avoid accessing them via maps.
  Object get exports => jsObject.exports;

  /// An unmodifiable [Map] view of instantiated module's exported functions.
  Map<String, Function> get functions => UnmodifiableMapView(_functions);

  /// An unmodifiable [Map] view of instantiated module's exported memories.
  Map<String, Memory> get memories => UnmodifiableMapView(_memories);

  /// An unmodifiable [Map] view of instantiated module's exported tables.
  Map<String, Table> get tables => UnmodifiableMapView(_tables);

  /// An unmodifiable [Map] view of instantiated module's exported globals.
  Map<String, Global> get globals => UnmodifiableMapView(_globals);

  /// Asynchronously instantiates compiled WebAssembly [Module] with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromModuleAsync(Module module,
          {Map<String, Map<String, Object>>? importMap,
          Object? importObject}) =>
      promiseToFuture<_Instance>(_instantiateModule(
              module.jsObject, _reifyImports(importMap, importObject)))
          .then((_instance) => Instance._(_instance, module));

  /// Asynchronously compiles WebAssembly Module from [Uint8List] source and
  /// instantiates it with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromBytesAsync(Uint8List bytes,
          {Map<String, Map<String, Object>>? importMap,
          Object? importObject}) =>
      promiseToFuture<_WebAssemblyInstantiatedSource>(
              _instantiate(bytes, _reifyImports(importMap, importObject)))
          .then((_source) =>
              Instance._(_source.instance, Module._(_source.module)));

  /// Asynchronously compiles WebAssembly Module from [ByteBuffer] source and
  /// instantiates it with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromBufferAsync(ByteBuffer buffer,
          {Map<String, Map<String, Object>>? importMap,
          Object? importObject}) =>
      promiseToFuture<_WebAssemblyInstantiatedSource>(
              _instantiate(buffer, _reifyImports(importMap, importObject)))
          .then((_source) =>
              Instance._(_source.instance, Module._(_source.module)));

  static Object _reifyImports(
      Map<String, Map<String, Object>>? importMap, Object? importObject) {
    assert(importMap == null || importObject == null);
    assert(importObject is! Map, 'importObject must be a JsObject.');

    if (importObject != null) {
      return importObject;
    }

    if (importMap != null) {
      final importObject = newObject() as Object;

      importMap.forEach((moduleName, module) {
        final moduleObject = newObject() as Object;
        module.forEach((name, value) {
          if (value is Function) {
            setProperty(moduleObject, name, allowInterop(value));
            return;
          }

          if (value is num) {
            setProperty(moduleObject, name, value);
            return;
          }

          if (value is BigInt) {
            setProperty(moduleObject, name, value.toJs());
            return;
          }

          if (value is Memory) {
            setProperty(moduleObject, name, value.jsObject);
            return;
          }

          if (value is Table) {
            setProperty(moduleObject, name, value.jsObject);
            return;
          }

          if (value is Global) {
            setProperty(moduleObject, name, value.jsObject);
            return;
          }

          assert(false,
              '$moduleName/$name value ($value) is of unsupported type.');
        });
        setProperty(importObject, moduleName, moduleObject);
      });

      return importObject;
    }

    return _undefined;
  }
}

/// Possible kinds of import or export descriptors.
enum ImportExportKind {
  /// [Function]
  function,

  /// [Global]
  global,

  /// [Memory]
  memory,

  /// [Table]
  table
}

const _importExportKindMap = {
  'function': ImportExportKind.function,
  'global': ImportExportKind.global,
  'memory': ImportExportKind.memory,
  'table': ImportExportKind.table
};

/// [Module] imports entry.
@immutable
class ModuleImportDescriptor {
  final _ModuleImportDescriptor _descriptor;
  ModuleImportDescriptor._(this._descriptor);

  /// Name of import module, not to confuse with [Module].
  String get module => _descriptor.module;

  /// Name of import entry.
  String get name => _descriptor.name;

  /// Kind of import entry.
  ImportExportKind get kind => _importExportKindMap[_descriptor.kind]!;
}

/// [Module] exports entry.
@immutable
class ModuleExportDescriptor {
  final _ModuleExportDescriptor _descriptor;
  ModuleExportDescriptor._(this._descriptor);

  /// Name of export entry.
  String get name => _descriptor.name;

  /// Kind of export entry.
  ImportExportKind get kind => _importExportKindMap[_descriptor.kind]!;
}

/// WebAssembly Memory instance. Could be shared between different instantiated
/// modules.
@immutable
class Memory {
  /// JavaScript `WebAssembly.Memory` object
  final _Memory jsObject;

  /// Creates a [Memory] of [initial] pages. One page is 65536 bytes.
  ///
  /// If provided, [maximum] must be greater than or equal to [initial].
  Memory({required int initial, int? maximum})
      : jsObject = _Memory(_descriptor(initial, maximum, false));

  /// Creates a shared [Memory] of [initial] and [maximum] pages. One page is
  /// 65536 bytes.
  ///
  /// [maximum] must be greater than or equal to [initial].
  Memory.shared({required int initial, required int maximum})
      : jsObject = _Memory(_descriptor(initial, maximum, true));

  Memory._(this.jsObject);

  /// Returns a [ByteBuffer] backing this memory object.
  ///
  /// Calling [grow] invalidates [buffer] reference.
  ByteBuffer get buffer => jsObject.buffer;

  // https://github.com/dart-lang/sdk/issues/33527

  /// Returns a number of bytes of [ByteBuffer] backing this memory object.
  int get lengthInBytes => getProperty(buffer, 'byteLength') as int;

  /// Returns a number of pages backing this memory object.
  int get lengthInPages => lengthInBytes >> 16;

  /// Increases size of allocated memory by [delta] pages. One page is 65536
  /// bytes. Returns the original size before grow attempt.
  ///
  /// New memory size must not exceed `maximum` parameter if it was provided.
  int grow(int delta) {
    assert(delta >= 0);
    return jsObject.grow(delta);
  }

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Memory` object.
  @override
  bool operator ==(Object other) =>
      other is Memory && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;

  static _MemoryDescriptor _descriptor(int initial, int? maximum, bool shared) {
    assert(initial >= 0);
    assert(maximum == null || maximum >= initial);
    assert(!shared || maximum != null);
    return _MemoryDescriptor(
        initial: initial,
        maximum: maximum ?? _undefined,
        shared: shared ? true : _undefined);
  }
}

/// WebAssembly Table instance. Could be shared between different instantiated
/// modules.
@immutable
class Table {
  /// JavaScript `WebAssembly.Table` object
  final _Table jsObject;

  /// Creates a [Table] of [initial] elements of `anyfunc` type.
  ///
  /// If provided, [maximum] must be greater than or equal to [initial]. If
  /// provided, [value] must be a WebAssembly exported function and it will be
  /// assigned to all table entries.
  Table.funcref({required int initial, int? maximum, Object? value})
      : jsObject = _Table(_descriptor('anyfunc', initial, maximum), value);

  /// Creates a [Table] of [initial] elements of reference type.
  ///
  /// If provided, [maximum] must be greater than or equal to [initial]. If
  /// provided, [value] will be assigned to all table entries.
  Table.externref({required int initial, int? maximum, Object? value})
      : jsObject = _Table(_descriptor('externref', initial, maximum), value);

  Table._(this.jsObject);

  static _TableDescriptor _descriptor(
      String element, int initial, int? maximum) {
    assert(initial >= 0);
    assert(maximum == null || maximum >= initial);
    return _TableDescriptor(
        element: element, initial: initial, maximum: maximum ?? _undefined);
  }

  /// Returns a table element by its index.
  Object? operator [](int index) => jsObject.get(index);

  /// Sets a table element by its index.
  void operator []=(int index, Object? value) => jsObject.set(index, value);

  /// Returns the size of [Table].
  int get length => jsObject.length;

  /// Grow the table by [delta] elements. Returns the previous length of the
  /// table. New memory size must not exceed `maximum` parameter if it was
  /// provided.
  int grow(int delta) => jsObject.grow(delta);

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Table` object.
  @override
  bool operator ==(Object other) =>
      other is Table && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;
}

/// WebAssembly Global instance. Could be shared between different instantiated
/// modules.
@immutable
class Global {
  /// JavaScript `WebAssembly.Global` object
  final _Global jsObject;

  /// Creates a [Global] of 32-bit integer type with [value].
  Global.i32({int value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('i32', mutable), value);

  /// Creates a [Global] of 64-bit integer type with [value].
  Global.i64({BigInt? value, bool mutable = false})
      : jsObject =
            _Global(_descriptor('i64', mutable), (value ?? BigInt.zero).toJs());

  /// Creates a [Global] of single-precision floating point type with [value].
  Global.f32({double value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('f32', mutable), value);

  /// Creates a [Global] of double-precision floating point type with [value].
  Global.f64({double value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('f64', mutable), value);

  /// Creates a [Global] of `externref` type with [value].
  Global.externref({Object? value, bool mutable = false})
      : jsObject = _Global(_descriptor('externref', mutable), value);

  Global._(this.jsObject);

  /// Returns a value stored in [Global].
  ///
  /// Automatically converts BigInt values between Dart and JS.
  Object? get value {
    final v = jsObject.value;
    return v != null && JsBigInt.isJsBigInt(v) ? JsBigInt.toBigInt(v) : v;
  }

  /// Sets a value stored in [Global]. Attempting to set a value when [Global]
  /// is immutable will cause a runtime error.
  ///
  /// Automatically converts BigInt values between Dart and JS.
  set value(Object? value) {
    jsObject.value = value is BigInt ? value.toJs() : value;
  }

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Global` object.
  @override
  bool operator ==(Object other) =>
      other is Global && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;

  static _GlobalDescriptor _descriptor(String value, bool mutable) =>
      _GlobalDescriptor(value: value, mutable: mutable);
}

/// BigInt interop
extension JsBigInt on BigInt {
  /// Convert to JavaScript `BigInt`.
  Object toJs() => _jsBigInt(toString());

  /// Create from JavaScript `BigInt`.
  static BigInt toBigInt(Object jsBigInt) =>
      BigInt.parse(callMethod(jsBigInt, 'toString', const []) as String);

  /// Returns `true` when the argument is a JavaScript `BigInt` value.
  static bool isJsBigInt(Object o) =>
      getProperty(getProperty(o, 'constructor') as Object, 'name') == 'BigInt';
}

@JS('BigInt')
external Object Function(String string) get _jsBigInt;

/// WebAssembly IDL

@JS()
@anonymous
abstract class _ModuleImportDescriptor {
  external String get module;
  external String get name;
  external String get kind;
}

@JS()
@anonymous
abstract class _ModuleExportDescriptor {
  external String get name;
  external String get kind;
}

@JS()
@anonymous
abstract class _MemoryDescriptor {
  external factory _MemoryDescriptor(
      {required int initial, Object maximum, Object shared});
}

@JS()
@anonymous
abstract class _TableDescriptor {
  external factory _TableDescriptor(
      {required String element, required int initial, Object maximum});
}

@JS()
@anonymous
abstract class _GlobalDescriptor {
  external factory _GlobalDescriptor(
      {required String value, bool mutable = false});
}

@JS()
@anonymous
abstract class _WebAssemblyInstantiatedSource {
  external _Module get module;
  external _Instance get instance;
}

@JS('WebAssembly.Memory')
external Function get _memoryConstructor;

@JS('WebAssembly.Table')
external Function get _tableConstructor;

@JS('WebAssembly.Global')
external Function get _globalConstructor;

@JS('WebAssembly.validate')
external bool _validate(Object bytesOrBuffer);

@JS('WebAssembly.compile')
external Object _compile(Object bytesOrBuffer);

@JS('WebAssembly.instantiate')
external Object _instantiate(Object bytesOrBuffer, Object import);

@JS('WebAssembly.instantiate')
external Object _instantiateModule(_Module module, Object import);

@JS('WebAssembly.Module')
class _Module {
  external _Module(Object bytesOfBuffer);

  // List<_ModuleExportDescriptor>
  external static List<Object> exports(_Module module);

  // List<_ModuleImportDescriptor>
  external static List<Object> imports(_Module module);

  // List<ByteBuffer>
  external static List<Object> customSections(
      _Module module, String sectionName);
}

@JS('WebAssembly.Instance')
class _Instance {
  external _Instance(_Module module, Object import);
  external Object get exports;
}

@JS('WebAssembly.Memory')
class _Memory {
  external _Memory(_MemoryDescriptor descriptor);
  external ByteBuffer get buffer;
  external int grow(int delta);
}

@JS('WebAssembly.Table')
class _Table {
  external _Table(_TableDescriptor descriptor, Object? value);
  external int grow(int delta);
  external Object? get(int index);
  external void set(int index, Object? value);
  external int get length;
}

@JS('WebAssembly.Global')
class _Global {
  external _Global(_GlobalDescriptor descriptor, Object? v);
  external Object? get value;
  external set value(Object? v);
}

/// This object is thrown when an exception occurs during compilation.
@JS('WebAssembly.CompileError')
abstract class CompileError {}

/// This object is thrown when an exception occurs during linking.
@JS('WebAssembly.LinkError')
abstract class LinkError {}

/// This object is thrown when an exception occurs from WebAssembly module.
@JS('WebAssembly.RuntimeError')
abstract class RuntimeError {}

/// Special JS `undefined` value
@JS('undefined')
external Object get _undefined;

/// Returns a [List<String>] of JS object's fields
@JS('Object.keys')
external List<Object> _objectKeys(Object value);
