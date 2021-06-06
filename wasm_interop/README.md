# WebAssembly JS API Bindings for Dart

## Upstream Specification

- [WebAssembly JavaScript Interface (Editor’s Draft)](https://webassembly.github.io/spec/js-api/)

## Running tests

Release mode on all available platforms (Chrome, Firefox, Safari, and node):

```
$ dart test
```

Debug mode (DDC) on Chrome:
```
$ dart run build_runner test -- -p chrome
```
