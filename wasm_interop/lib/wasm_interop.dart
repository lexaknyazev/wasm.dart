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
class Module {
  /// JavaScript `WebAssembly.Module` object
  final _Module jsObject;

  /// Creates a [Module] object from existing JS `WebAssembly.Module`.
  ///
  /// This can be used to leverage caching of compiled modules with IndexedDB.
  Module.fromJsObject(this.jsObject);

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

  // TODO dart-lang/sdk#33598

  /// A lazy [Iterable] with module's export descriptors.
  Iterable<ModuleExportDescriptor> get exports =>
      _Module.exports(jsObject).map((_descriptor) =>
          ModuleExportDescriptor._(_descriptor as _ModuleExportDescriptor));

  /// A lazy [Iterable] with module's import descriptors.
  Iterable<ModuleImportDescriptor> get imports =>
      _Module.imports(jsObject).map((_descriptor) =>
          ModuleImportDescriptor._(_descriptor as _ModuleImportDescriptor));

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
      _futureFromPromise(_compile(bytes))
          .then((_module) => Module.fromJsObject(_module));

  /// Asynchronously compiles WebAssembly [Module] from [ByteBuffer] source.
  ///
  /// Throws a [CompileError] on invalid module source.
  static Future<Module> fromBufferAsync(ByteBuffer buffer) =>
      _futureFromPromise(_compile(buffer))
          .then((_module) => Module.fromJsObject(_module));

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
class Instance {
  /// JavaScript `WebAssembly.Instance` object
  final _Instance jsObject;

  /// WebAssembly [Module] this instance was instantiated from.
  final Module module;

  final Map<String, ExportedFunction> _functions = <String, ExportedFunction>{};
  final Map<String, Memory> _memories = <String, Memory>{};
  final Map<String, Table> _tables = <String, Table>{};
  final Map<String, Object> _globals = <String, Object>{};

  Instance._(this.jsObject, this.module) {
    // Fill exports helper maps
    final exportsObject = jsObject.exports;
    for (final String key in _objectKeys(exportsObject)) {
      final Object value = getProperty(exportsObject, key);
      if (value is Function) {
        _functions[key] = ExportedFunction._(value);
        // TODO dart-lang/sdk#33524
      } else if (value is _Memory && instanceof(value, _memoryConstructor)) {
        _memories[key] = Memory._(value);
        // TODO dart-lang/sdk#33524
      } else if (value is _Table && instanceof(value, _tableConstructor)) {
        _tables[key] = Table._(value);
        // TODO dart-lang/sdk#33524
      } else if (value is _Global && instanceof(value, _globalConstructor)) {
        _globals[key] = Global._(value);
      } else if (value is num) {
        _globals[key] = value;
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
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      Instance._(
          _Instance(module.jsObject, _reifyImports(importMap, importObject)),
          module);

  /// Synchronously compiles and instantiates WebAssembly from [Uint8List]
  /// source.
  ///
  /// Some runtimes do not allow synchronous instantiation of modules
  /// bigger than 4 KB in the main thread. In such case, an [ArgumentError]
  /// will be thrown.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  factory Instance.fromBytes(Uint8List bytes,
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      Instance.fromModule(Module.fromBytes(bytes),
          importMap: importMap, importObject: importObject);

  /// Synchronously compiles and instantiates WebAssembly from [ByteBuffer]
  /// source.
  ///
  /// Some runtimes do not allow synchronous instantiation of modules
  /// bigger than 4 KB in the main thread. In such case, an [ArgumentError]
  /// will be thrown.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  factory Instance.fromBuffer(ByteBuffer buffer,
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      Instance.fromModule(Module.fromBuffer(buffer),
          importMap: importMap, importObject: importObject);

  /// A `JsObject` representing instantiated module's exports.
  Object get exports => jsObject.exports;

  /// An unmodifiable [Map] containing instantiated module's exported functions.
  Map<String, ExportedFunction> get functions =>
      UnmodifiableMapView(_functions);

  /// An unmodifiable [Map] containing instantiated module's exported memories.
  Map<String, Memory> get memories => UnmodifiableMapView(_memories);

  /// An unmodifiable [Map] containing instantiated module's exported tables.
  Map<String, Table> get tables => UnmodifiableMapView(_tables);

  /// An unmodifiable [Map] containing instantiated module's exported globals.
  /// Values of the map are either regular numbers or instances of `Global`.
  Map<String, Object> get globals => UnmodifiableMapView(_globals);

  /// Asynchronously instantiates compiled WebAssembly [Module] with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromModuleAsync(Module module,
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      _futureFromPromise(_instantiateModule(
              module.jsObject, _reifyImports(importMap, importObject)))
          .then((_instance) => Instance._(_instance, module));

  /// Asynchronously compiles WebAssembly Module from [Uint8List] source and
  /// instantiates it with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromBytesAsync(Uint8List bytes,
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      _futureFromPromise(
              _instantiate(bytes, _reifyImports(importMap, importObject)))
          .then((_source) => Instance._(
              _source.instance, Module.fromJsObject(_source.module)));

  /// Asynchronously compiles WebAssembly Module from [ByteBuffer] source and
  /// instantiates it with imports.
  ///
  /// See [Instance.fromModule] regarding [importMap] and [importObject] usage.
  static Future<Instance> fromBufferAsync(ByteBuffer buffer,
          {Map<String, Map<String, Object>> importMap, Object importObject}) =>
      _futureFromPromise(
              _instantiate(buffer, _reifyImports(importMap, importObject)))
          .then((_source) => Instance._(
              _source.instance, Module.fromJsObject(_source.module)));

  static Object _reifyImports(
      Map<String, Map<String, Object>> importMap, Object importObject) {
    assert(importMap == null || importObject == null);
    assert(importObject is! Map, 'importObject must be a JsObject.');

    if (importObject != null) {
      return importObject;
    }

    if (importMap != null) {
      final Object importObject = newObject();

      importMap.forEach((moduleName, module) {
        final Object moduleObject = newObject();
        module.forEach((name, value) {
          if (value is Function) {
            setProperty(moduleObject, name, allowInterop(value));
            return;
          }

          if (value is ExportedFunction) {
            setProperty(moduleObject, name, value.jsObject);
            return;
          }

          if (value is num) {
            setProperty(moduleObject, name, value);
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

  /// Number ([num])
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
class ModuleImportDescriptor {
  final _ModuleImportDescriptor _descriptor;
  ModuleImportDescriptor._(this._descriptor);

  /// Name of import module, not to confuse with [Module].
  String get module => _descriptor.module;

  /// Name of import entry.
  String get name => _descriptor.name;

  /// Kind of import entry.
  ImportExportKind get kind => _importExportKindMap[_descriptor.kind];

  @override
  String toString() => 'ModuleImportDescriptor: $module/$name -> $kind';
}

/// [Module] exports entry.
class ModuleExportDescriptor {
  final _ModuleExportDescriptor _descriptor;
  ModuleExportDescriptor._(this._descriptor);

  /// Name of export entry.
  String get name => _descriptor.name;

  /// Kind of export entry.
  ImportExportKind get kind => _importExportKindMap[_descriptor.kind];

  @override
  String toString() => 'ModuleExportDescriptor: $name -> $kind';
}

/// WebAssembly Memory instance. Could be shared between different instantiated
/// modules.
class Memory {
  /// JavaScript `WebAssembly.Memory` object
  final _Memory jsObject;

  /// Creates a [Memory] of [initial] pages. One page is 65536 bytes.
  ///
  /// If provided, [maximum] must be greater than or equal to [initial].
  Memory(int initial, {int maximum})
      : jsObject = _Memory(_descriptor(initial, maximum));

  Memory._(this.jsObject);

  /// Returns a [ByteBuffer] backing this memory object.
  ///
  /// Calling [grow] invalidates [buffer] reference.
  ByteBuffer get buffer => jsObject.buffer;

  // TODO dart-lang/sdk#33527

  /// Returns a number of bytes of [ByteBuffer] backing this memory object.
  int get lengthInBytes =>
      // ignore: return_of_invalid_type
      getProperty(buffer, 'byteLength');

  /// Returns a number of pages backing this memory object.
  int get lengthInPages => lengthInBytes >> 16;

  /// Increases size of allocated memory by [delta] pages. One page is 65536
  /// bytes.
  ///
  /// New memory size shouldn't exceed `maximum` parameter if it was provided.
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

  static _MemoryDescriptor _descriptor(int initial, int maximum) {
    assert(initial != null && initial >= 0);
    assert(maximum == null || maximum >= initial);
    // Without this check, JS will get `{..., maximum: null}` and fail.
    if (maximum != null) {
      return _MemoryDescriptor(initial: initial, maximum: maximum);
    }
    return _MemoryDescriptor(initial: initial);
  }
}

/// WebAssembly Table instance. Could be shared between different instantiated
/// modules.
class Table extends ListBase<ExportedFunction> {
  /// JavaScript `WebAssembly.Table` object
  final _Table jsObject;

  /// Creates a functions [Table] of [initial] elements.
  ///
  /// If provided, [maximum] must be greater than or equal to [initial].
  Table(int initial, {int maximum})
      : jsObject = _Table(_descriptor(initial, maximum));

  Table._(this.jsObject);

  static _TableDescriptor _descriptor(int initial, int maximum) {
    assert(initial != null && initial >= 0);
    assert(maximum == null || maximum >= initial);
    const anyfunc = 'anyfunc';
    // Without this check, JS will get `{..., maximum: null}` and fail.
    if (maximum != null) {
      return _TableDescriptor(
          element: anyfunc, initial: initial, maximum: maximum);
    }
    return _TableDescriptor(element: anyfunc, initial: initial);
  }

  /// Returns an [ExportedFunction] by its index.
  @override
  ExportedFunction operator [](int index) =>
      ExportedFunction._(jsObject.get(index));

  /// Sets a [ExportedFunction] by its index.
  @override
  void operator []=(int index, ExportedFunction value) =>
      jsObject.set(index, value.jsObject);

  /// Returns the size of [Table].
  @override
  int get length => jsObject.length;

  /// Sets a new size. Table cannot be shrinked.
  @override
  set length(int newLength) {
    if (newLength < length) {
      return _throw();
    }
    jsObject.grow(newLength - length);
  }

  @override
  Table operator +(List<ExportedFunction> other) => Table(length + other.length)
    ..setRange(0, length, this)
    ..setRange(length, length + other.length, other);

  /// Adds [function] to the end of this table, extending the length by one.
  ///
  /// Throws `RangeError` if table cannot grow anymore.
  @override
  void add(ExportedFunction function) {
    final currentLength = length;
    try {
      jsObject.grow(1);
      // ignore: avoid_catching_errors
    } on ArgumentError catch (_) {
      throw RangeError('Table has reached its maximum size ($currentLength).');
    }
    this[currentLength] = function;
  }

  /// Adds all [functions] to the end of this table, extending the length.
  ///
  /// Throws `RangeError` if table cannot grow anymore.
  @override
  void addAll(Iterable<ExportedFunction> functions) {
    var i = length;
    for (final function in functions) {
      assert(length == i || (throw ConcurrentModificationError(this)));
      try {
        jsObject.grow(1);
        // ignore: avoid_catching_errors
      } on ArgumentError catch (_) {
        throw RangeError('Table has reached its maximum size ($i).');
      }
      this[i] = function;
      i++;
    }
  }

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Table` object.
  @override
  bool operator ==(Object other) =>
      other is Table && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;

  /// This operation is not supported.
  @override
  @alwaysThrows
  bool remove(Object element) => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  void removeWhere(bool Function(ExportedFunction element) test) => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  void retainWhere(bool Function(ExportedFunction element) test) => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  ExportedFunction removeLast() => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  void removeRange(int start, int end) => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  ExportedFunction removeAt(int index) => _throw();

  /// This operation is not supported.
  @override
  @alwaysThrows
  void clear() => _throw();

  static T _throw<T>() => throw UnsupportedError('Cannot shrink table.');
}

/// WebAssembly Global instance. Could be shared between different instantiated
/// modules.
class Global {
  /// JavaScript `WebAssembly.Memory` object
  final _Global jsObject;

  /// Creates a [Global] of 32-bit integer type with `value`.
  Global.i32({int value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('i32', mutable), value);

  /// Creates a [Global] of 64-bit integer type.
  Global.i64({bool mutable = false})
      : jsObject = _Global(_descriptor('i64', mutable));

  /// Creates a [Global] of single-precision floating point type with `value`.
  Global.f32({double value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('f32', mutable), value);

  /// Creates a [Global] of double-precision floating point type with `value`.
  Global.f64({double value = 0, bool mutable = false})
      : jsObject = _Global(_descriptor('f64', mutable), value);

  Global._(this.jsObject);

  /// Returns a value stored in [Global]. Attempting to read a value of
  /// 64-bit integer type will cause a runtime error.
  num get value => jsObject.value;

  /// Sets a value stored in [Global]. Attempting to set a value when [Global]
  /// is immutable or of 64-bit integer type will cause a runtime error.
  set value(num value) => jsObject.value = value;

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same `WebAssembly.Memory` object.
  @override
  bool operator ==(Object other) =>
      other is Global && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;

  static _GlobalDescriptor _descriptor(String value, bool mutable) {
    assert(mutable != null);
    return _GlobalDescriptor(value: value, mutable: mutable);
  }
}

/// Callable object representing a function exported from WebAssembly module.
class ExportedFunction {
  /// JavaScript WebAssembly Exported Function
  final Function jsObject;
  ExportedFunction._(this.jsObject);

  /// Invoke associated WebAssembly function.
  Object call(
          [Object arg0,
          Object arg1,
          Object arg2,
          Object arg3,
          Object arg4,
          Object arg5,
          Object arg6,
          Object arg7,
          Object arg8,
          Object arg9,
          Object arg10,
          Object arg11,
          Object arg12,
          Object arg13,
          Object arg14,
          Object arg15]) =>
      jsObject(arg0, arg1, arg2, arg3, arg4, arg5, arg6, arg7, arg8, arg9,
          arg10, arg11, arg12, arg13, arg14, arg15);

  /// The equality operator.
  ///
  /// Returns true if and only if `this` and [other] wrap
  /// the same WebAssembly exported JS function.
  @override
  bool operator ==(Object other) =>
      other is ExportedFunction && other.jsObject == jsObject;

  @override
  int get hashCode => jsObject.hashCode;
}

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
  external factory _MemoryDescriptor({@required int initial, int maximum});
}

@JS()
@anonymous
abstract class _TableDescriptor {
  external factory _TableDescriptor(
      {@required String element, @required int initial, int maximum});
}

@JS()
@anonymous
abstract class _GlobalDescriptor {
  external factory _GlobalDescriptor({@required String value, bool mutable});
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
external _Promise<_Module> _compile(Object bytesOrBuffer);

@JS('WebAssembly.instantiate')
external _Promise<_WebAssemblyInstantiatedSource> _instantiate(
    Object bytesOrBuffer, Object import);

@JS('WebAssembly.instantiate')
external _Promise<_Instance> _instantiateModule(_Module module, Object import);

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
  external _Table(_TableDescriptor descriptor);
  external int grow(int delta);
  external Function get(int index);
  external void set(int index, Function value);
  external int get length;
}

@JS('WebAssembly.Global')
class _Global {
  external _Global(_GlobalDescriptor descriptor, [num v]);
  external num get value;
  external set value(num v);
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
external List _objectKeys(Object value);

@JS('Promise')
class _Promise<T> {
  external _Promise then(void Function(T result) onFulfilled,
      [Function onRejected]);
}

Future<T> _futureFromPromise<T>(_Promise<T> promise) {
  final completer = Completer<T>();
  promise.then(
      allowInterop(completer.complete), allowInterop(completer.completeError));
  return completer.future;
}
