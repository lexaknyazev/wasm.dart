# WebAssembly JS API Bindings for Dart

## Upstream Specification

- [WebAssembly JavaScript Interface (Editor’s Draft)](https://webassembly.github.io/spec/js-api/)

## Overview

This package provides Dart bindings for the WebAssembly JavaScript API. It is intended to be used with standalone WebAssembly modules, i.e., modules that do not need specialized JavaScript glue code. For the latter case, Dart applications should target that glue code via `dart:js` or `package:js` instead of using this package.

Standalone WebAssembly modules could be created with:

- [AssemblyScript](https://www.assemblyscript.org/)

- [Emscripten](https://github.com/emscripten-core/emscripten/wiki/WebAssembly-Standalone)

To use WebAssembly from Dart in non-JS environments, see the [wasm](https://github.com/dart-lang/wasm) package.

## Running tests

Release mode on all available platforms (Chrome, Firefox, Safari, and node):

```
$ dart test
```

Debug mode (DDC) on Chrome:

```
$ dart run build_runner test -- -p chrome
```
