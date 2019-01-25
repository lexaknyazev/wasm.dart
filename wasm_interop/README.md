# WebAssembly JS API Bindings for Dart

## Specification
- [WebAssembly JavaScript Interface (Editor’s Draft)](https://webassembly.github.io/spec/js-api/)

## Running tests
Release mode on Chrome and Firefox:
```
$ pub run build_runner test -- --release -p "chrome,firefox"
```

Debug mode (DDC) on Chrome and node:
```
$ pub run build_runner test -- -p "chrome,node"
```