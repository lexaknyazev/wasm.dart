# Changelog

## 2.0.1

* Documentation updates.

* Fixed error objects not being thrown correctly.

## 2.0.0

* Null-safety release.

* Updated to the latest WebAssembly IDL:

  * Added interop support for 64-bit integer Globals.

  * Added support for Globals and Tables of `externref` type.

  * Added a new `Memory.shared` constructor.

* __Breaking API changes__:

  * `Module.imports` and `Module.exports` getters generate and return a `List` of descriptors instead of an `Iterable`.

  * `ModuleImportDescriptor` and `ModuleExportDescriptor` no longer override `toString()`.

  * `Instance.fromBytes` and `Instance.fromBuffer` sync factories have been removed.

  * `Instance.functions` and `Instance.globals` have static types of `Map<String, Function>` and `Map<String, Global>` respectively.

  * `ExportedFunction` wrapper class has been removed.

  * `Memory` constructor now uses required named parameters.

  * `Table` no longer extends `ListBase`.

  * Default `Table()` constructor have been removed.

  * `Table.length` setter has been removed. Users should explicitly call `Table.grow()` instead.

  * `Global.value` setter and getter have a static type of `Object?`.

* The package adds `JsBigInt` extension on `BigInt` class to enable interop with JavaScript BigInt values.

## 1.0.0-dev.1.0

* Implemented `WebAssembly.Global` interface.

* Updated to the latest SDK.

## 1.0.0-dev.0.0

* Initial release.
