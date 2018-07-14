@JS()
library js_matchers;

import 'package:js/js.dart';
import 'package:js/js_util.dart';
import 'package:test/test.dart';

final Matcher isCompileError =
    _JsTypeMatcher('WebAssembly.CompileError', _compileError);

final Matcher isLinkError = _JsTypeMatcher('WebAssembly.LinkError', _linkError);

final Matcher isRuntimeError =
    _JsTypeMatcher('WebAssembly.RuntimeError', _runtimeError);

class _JsTypeMatcher extends Matcher {
  final String type;
  final Function jsConstructor;

  const _JsTypeMatcher(this.type, this.jsConstructor);

  @override
  Description describe(Description description) =>
      description.add('Instance of $type');

  @override
  bool matches(Object item, Map matchState) => instanceof(item, jsConstructor);
}

@JS('WebAssembly.CompileError')
external Function get _compileError;

@JS('WebAssembly.LinkError')
external Function get _linkError;

@JS('WebAssembly.RuntimeError')
external Function get _runtimeError;
