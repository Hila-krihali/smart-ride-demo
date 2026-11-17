import 'package:http/http.dart' as http;

import 'demo_backend.dart';

/// An http.Client that answers requests to the demo backend from memory,
/// and sends every other request (for example OSRM) to the real network.
class DemoHttpClient extends http.BaseClient {
  DemoHttpClient(this.backend, this._network);

  final DemoBackend backend;
  final http.Client _network;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    if (!backend.handles(request.url)) {
      return _network.send(request);
    }

    final bodyBytes = await request.finalize().toBytes();
    final result = await backend.handle(
      request.method,
      request.url,
      request.headers,
      bodyBytes,
    );

    return http.StreamedResponse(
      Stream<List<int>>.value(result.bodyBytes),
      result.statusCode,
      contentLength: result.bodyBytes.length,
      request: request,
      headers: result.headers,
    );
  }

  @override
  void close() {
    _network.close();
  }
}

/// Builds the client used by ApiService in demo mode.
DemoHttpClient createDemoHttpClient(String baseUrl) {
  final network = http.Client();
  final backend = DemoBackend(
    baseUrl: baseUrl,
    fetchText: (uri) async {
      final response = await network.get(uri);
      return response.statusCode == 200 ? response.body : null;
    },
  );
  return DemoHttpClient(backend, network);
}
