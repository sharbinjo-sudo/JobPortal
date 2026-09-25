/// Web implementation of the localStorage token fallback backed by
/// `dart:js_interop`. Only imported (conditionally) on the web platform.
library;

import 'dart:js_interop';

@JS('localStorage')
external _LocalStorage get _localStorage;

extension type _LocalStorage._(JSObject _) implements JSObject {
  external String? getItem(String key);
  external void setItem(String key, String value);
  external void removeItem(String key);
}

/// Reads a token from browser localStorage. Returns null when absent.
String? readToken(String key) {
  final value = _localStorage.getItem(key);
  return value == null || value.isEmpty ? null : value;
}

/// Persists a token in browser localStorage.
void writeToken(String key, String value) => _localStorage.setItem(key, value);

/// Removes a token from browser localStorage.
void removeToken(String key) => _localStorage.removeItem(key);
