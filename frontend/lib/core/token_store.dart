/// Conditional-export shim: web builds get the real localStorage bridge from
/// `token_store_web.dart`; IO builds get no-op stubs from `token_store_io.dart`.
library;

export 'token_store_io.dart'
    if (dart.library.js_interop) 'token_store_web.dart';
