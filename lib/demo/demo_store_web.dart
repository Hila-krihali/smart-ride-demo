import 'package:web/web.dart' as web;

import 'demo_backend.dart';

class _LocalStorageStore implements DemoStore {
  @override
  String? read(String key) => web.window.localStorage.getItem(key);

  @override
  void write(String key, String value) =>
      web.window.localStorage.setItem(key, value);
}

DemoStore? createDemoStore() {
  try {
    // Accessing localStorage can throw (e.g. blocked storage).
    web.window.localStorage.length;
    return _LocalStorageStore();
  } catch (_) {
    return null;
  }
}
