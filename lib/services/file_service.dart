import 'dart:io';

import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:path/path.dart' as p;
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';

/// Singleton file server that serves registered files via a single HTTP server.
/// TODO: pure dart and add test
const _tag = 'AnyShareFileServer';

Middleware _corsMiddleware() {
  return _corsHandler;
}

Handler _corsHandler(Handler innerHandler) {
  return (request) async {
    if (request.method == 'OPTIONS') {
      return Response.ok(
        null,
        headers: {
          'access-control-allow-origin': '*',
          'access-control-allow-methods': 'GET, HEAD, OPTIONS',
          'access-control-allow-headers': '*',
        },
      );
    }
    final response = await innerHandler(request);
    return response.change(
      headers: {'access-control-allow-origin': '*'},
    );
  };
}

/// 浏览器下载时链接带 `?download=1`，回一个 Content-Disposition，让浏览器按原文件名保存，
/// 而不是直接打开图片、文本之类的文件
Middleware _downloadMiddleware() {
  return (Handler innerHandler) {
    return (request) async {
      final response = await innerHandler(request);
      if (!request.url.queryParameters.containsKey('download') || response.statusCode != 200) {
        return response;
      }
      String name = p.url.basename(request.url.path);
      try {
        name = Uri.decodeComponent(name);
      } catch (_) {}
      // RFC 5987 的写法，中文文件名也能正确保存
      final String encoded = Uri.encodeComponent(name).replaceAll("'", '%27').replaceAll('(', '%28').replaceAll(')', '%29').replaceAll('*', '%2A');
      return response.change(
        headers: {'content-disposition': "attachment; filename*=UTF-8''$encoded"},
      );
    };
  };
}

/// TODO: Consider use isolate to server every file
class _FileService {
  _FileService._internal();
  static final _FileService _instance = _FileService._internal();
  static _FileService get instance => _instance;

  final Router _router = Router();
  HttpServer? _server;
  int _port = 0;
  int get port => _port;
  final Set<String> _registeredPaths = {};

  /// Start the HTTP server on [port]. Idempotent — only starts once.
  Future<void> start() async {
    if (_server != null) {
      return;
    }
    // 别的设备收到文件消息后，先挨个探测消息里的地址哪个能连上：
    // 新版速享请求 /ping，2.2.x 及更早的版本（包括旧网页端）请求 /check_token
    _router.get('/ping', (Request request) => Response.ok('pong'));
    _router.get('/check_token', (Request request) => Response.ok('success'));
    var pipeline = const Pipeline();
    pipeline = pipeline.addMiddleware(logRequests());
    pipeline = pipeline.addMiddleware(_corsMiddleware());
    pipeline = pipeline.addMiddleware(_downloadMiddleware());
    final handler = pipeline.addHandler(_router);
    int rangeStart = Config.shelfPortRangeStart;
    int rangeEnd = Config.shelfPortRangeEnd;
    _port = rangeStart;
    while (true) {
      try {
        _server = await io.serve(handler, InternetAddress.anyIPv6, _port);
        break;
      } catch (e) {
        Log.w('Port $_port is in use, trying another port...');
        _port = _port + 1;
        if (_port > rangeEnd) {
          throw Exception('No available ports in the range $rangeStart-$rangeEnd');
        }
      }
    }
    Log.i('FileServer started on port $_port', _tag);
  }

  String _normalize(String filePath) {
    String path = filePath.replaceAll('\\', '/');
    path = path.replaceAll(RegExp('^[A-Z]:'), '');
    path = path.replaceAll(RegExp('^/'), '');
    return path;
  }

  /// Register a file to be served. [start] must have been called first.
  /// Returns the URL path segment that can be used to access this file.
  Future<String> addFile(String path) async {
    assert(_server != null, 'FileServer must be started before adding files');

    if (_registeredPaths.contains(path)) {
      return urlFor(path);
    }

    final normalized = _normalize(path);
    final urlPath = p.toUri(normalized).toString();
    final handler = createFileHandler(path, url: urlPath);
    _router.get('/$urlPath', handler);
    _registeredPaths.add(path);

    // log the URL for debugging
    Log.i('Registered file: $path at URL path: /$urlPath');

    return urlPath;
  }

  /// Get the URL path segment for a file path (without registering).
  String urlFor(String path) {
    final normalized = _normalize(path);
    return p.toUri(normalized).toString();
  }

  /// The shelf Router. Exposed so external code can register custom routes
  /// (e.g. token check) before or after the server starts.
  Router get router => _router;

  /// Number of registered files.
  int get registeredCount => _registeredPaths.length;

  /// Whether the server is running.
  bool get isRunning => _server != null;

  /// Stop the server and clear all registered files.
  Future<void> dispose() async {
    await _server?.close(force: true);
    _server = null;
    _registeredPaths.clear();
  }
}

// ignore: non_constant_identifier_names
final FileService = _FileService.instance;
