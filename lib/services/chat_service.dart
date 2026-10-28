import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart' show rootBundle;
import 'package:shelf/shelf.dart';
import 'package:shelf/shelf_io.dart' as io;
import 'package:shelf_router/shelf_router.dart';
import 'package:shelf_static/shelf_static.dart';
import 'package:get/get.dart' hide Response;
import 'package:path/path.dart' as p;
import 'package:file_manager/server/file_server.dart' as file_manager;
import 'package:global_repository/global_repository.dart';

import 'package:speed_share/common/common.dart';
import 'package:speed_share/utils/utils.dart';
import 'package:speed_share/controllers/controllers.dart';
import 'package:speed_share/generated/l10n.dart';

/// Singleton chat server that serves registered files via a single HTTP server.
/// TODO: pure dart and add test
const _tag = 'AnyShareChatServer';

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

class ServerRoutes {
  static const String ping = '/ping';
  static const String uploadFile = '/file_upload';
  static const String message = '/message';
  static const String info = '/info';

  /// 2.2.x 及更早的速享（包括旧网页端）用它探测哪个地址能连通
  static const String checkToken = '/check_token';
}

/// 发起请求的设备的 IP
String _remoteAddress(Request request) {
  final Object? info = request.context['shelf.io.connection_info'];
  if (info is HttpConnectionInfo) {
    return info.remoteAddress.address;
  }
  return 'unknown';
}

/// 浏览器是通过 [host] 打开网页的，这个地址一定连得上，放到消息里地址列表的最前面，
/// 旧网页端按顺序逐个探测，不用再等连不上的地址超时
Map<String, dynamic> _preferHost(Map<String, dynamic> message, String host) {
  final Object? addrs = message['addrs'];
  if (addrs is! List || host.isEmpty) {
    return message;
  }
  return {
    ...message,
    'addrs': [host, ...addrs.where((e) => e != host)],
  };
}

class _ChatService {
  _ChatService._();
  static final _ChatService instance = _ChatService._();
  late final ChatController chatController = Get.find();
  late final SettingController settingController = Get.find();
  late final DeviceController deviceController = Get.find();
  late final DownloadController downloadController = Get.find();
  // set message handler for the server
  late final void Function(Map<String, dynamic>) messageHandler;

  final Router _router = Router();
  HttpServer? _server;
  int _port = 0;
  final Set<String> _registeredPaths = {};

  /// 网页端就是一个 HTML 文件，第一次有人打开时从 assets 读出来
  String? _webPage;

  Future<Response> _serveWebPage(Request request) async {
    _webPage ??= await rootBundle.loadString('${Config.flutterPackage}assets/web/index.html');
    return Response.ok(
      _webPage,
      headers: {
        HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8',
        HttpHeaders.cacheControlHeader: 'no-cache',
      },
    );
  }

  /// Start the HTTP server on [port]. Idempotent — only starts once.
  Future<void> start() async {
    if (_server != null) {
      return;
    }
    var pipeline = const Pipeline();
    _router.get(ServerRoutes.ping, (Request request) {
      return Response.ok('pong');
    });
    _router.get(ServerRoutes.checkToken, (Request request) {
      return Response.ok('success');
    });
    // 网页端打开时用来显示连上的是哪台设备
    _router.get(ServerRoutes.info, (Request request) {
      return Response.ok(
        jsonEncode({
          'deviceName': deviceController.deviceName,
          'deviceType': deviceController.deviceType.name,
        }),
        headers: {HttpHeaders.contentTypeHeader: 'application/json; charset=utf-8'},
      );
    });
    _router.get('/', _serveWebPage);
    _router.get('/index.html', _serveWebPage);
    // TODO: Consider change route path?
    _router.post('/', (Request request) async {
      Map<String, dynamic> data = jsonDecode(await request.readAsString());
      messageHandler(data);
      // 这儿应该返回本机信息
      return Response.ok(
        "success",
        headers: {
          HttpHeaders.contentTypeHeader: ContentType.text.toString(),
        },
      );
    });
    _router.post(ServerRoutes.uploadFile, _receiveUpload);
    // 浏览器轮询这里取消息。新网页端会带上自己的 id 和名字，旧网页端什么都不带，按 IP 区分
    _router.get(ServerRoutes.message, (Request request) {
      final Map<String, String> query = request.url.queryParameters;
      final String address = _remoteAddress(request);
      final String id = query['id'] ?? 'ip:$address';
      deviceController.onBrowserPoll(id, query['name'] ?? '浏览器 $address', address);
      final bool batch = query['batch'] == '1';
      final List<Map<String, dynamic>> messages = chatController.webHub.take(
        id,
        max: batch ? 100 : 1,
        reset: query['reset'] == '1',
      );
      final String host = request.requestedUri.host;
      final List<Map<String, dynamic>> result = [
        for (final Map<String, dynamic> message in messages) _preferHost(message, host),
      ];
      // 旧网页端一次只取一条，没有消息时要回 {"type": "none"}
      if (batch) {
        return Response.ok(jsonEncode(result));
      }
      return Response.ok(jsonEncode(result.isEmpty ? {'type': 'none'} : result.first));
    });
    _router.mount('/', (r) async {
      // `http://192.168.0.103:12000/sdcard/`的形式，说明是想要访问文件
      if (r.requestedUri.path.startsWith('/sdcard') || file_manager.Server.routes.contains(r.requestedUri.path)) {
        if (!settingController.enableWebServer) {
          return Response.ok(
            l10n.needWSTip,
            headers: {
              HttpHeaders.contentTypeHeader: 'text/plain',
            },
          );
        }
        try {
          Router fileRouter = await file_manager.Server.getFileServerHandler();
          return fileRouter.call(r);
        } catch (e) {
          return Response.notFound(
            e.toString(),
            headers: {
              HttpHeaders.contentTypeHeader: 'text/plain',
            },
          );
        }
      }
      return Response.notFound('Not Found');
    });
    pipeline = pipeline.addMiddleware(logRequests());
    pipeline = pipeline.addMiddleware(_corsMiddleware());
    final handler = pipeline.addHandler(_router);
    _port = Config.chatPortRangeStart;
    while (true) {
      try {
        // TODO:: Test ipv6 does contain ipv4 address or not
        _server = await io.serve(handler, InternetAddress.anyIPv4, _port);
        break;
      } catch (e) {
        Log.w('Port $_port is in use, trying another port...');
        _port = _port + 1;
        if (_port > Config.chatPortRangeEnd) {
          throw Exception('No available ports in the range ${Config.chatPortRangeStart}-${Config.chatPortRangeEnd}');
        }
      }
    }
    Log.i('ChatService started on port $_port', _tag);
  }

  /// 接收浏览器上传的文件，存到下载目录，进度记在 DownloadController 里（key 是请求头里的 blob）
  Future<Response> _receiveUpload(Request request) async {
    final String? encodedName = request.headers['filename'];
    if (encodedName == null) {
      return Response.badRequest(body: 'missing filename');
    }
    // 只取文件名，防止 ../ 之类的路径把文件写到下载目录外面
    final String fileName = p.basename(utf8.decode(base64Decode(encodedName)).replaceAll('\\', '/'));
    if (fileName.isEmpty || fileName == '.' || fileName == '..') {
      return Response.badRequest(body: 'bad filename');
    }
    final File file = File(getSafePath('${settingController.savePath}/$fileName'));
    // 保存目录（Windows 上默认在 exe 旁边）第一次接收文件时还不存在
    await file.parent.create(recursive: true);
    final int? fullLength = int.tryParse(request.headers['content-length'] ?? '');
    final DownloadInfo info = DownloadInfo();
    downloadController.progress[request.headers['blob']] = info;
    final Timer speedTimer = await downloadController.computeNetSpeed(info);
    final IOSink sink = file.openWrite();
    DateTime lastUpdate = DateTime(2000);
    try {
      await for (final List<int> chunk in request.read()) {
        sink.add(chunk);
        info.count += chunk.length;
        if (fullLength != null && fullLength > 0) {
          // 文件关闭前不显示 100%
          info.progress = (info.count / fullLength).clamp(0.0, 0.99);
        }
        final DateTime now = DateTime.now();
        if (now.difference(lastUpdate) > const Duration(milliseconds: 100)) {
          lastUpdate = now;
          downloadController.update();
        }
      }
      await sink.close();
    } catch (e) {
      Log.e('receive upload error : $e');
      speedTimer.cancel();
      await sink.close();
      info.progress = 0;
      downloadController.update();
      return Response.internalServerError(body: 'upload failed');
    }
    speedTimer.cancel();
    info.progress = 1.0;
    info.path = file.path;
    downloadController.update();
    Log.v('receive upload success : ${file.path}');
    return Response.ok('success');
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

  /// The port the server is running on, or null if not started.
  int? get port => _port;

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
final ChatService = _ChatService.instance;
