import 'demo_backend.dart';
import 'demo_store_stub.dart'
    if (dart.library.js_interop) 'demo_store_web.dart'
    as impl;

/// Browser localStorage on the web, null elsewhere.
DemoStore? createDemoStore() => impl.createDemoStore();
