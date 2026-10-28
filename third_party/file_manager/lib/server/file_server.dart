import 'dart:convert';
import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:shelf_router/shelf_router.dart';

import '../src/storage.dart';
import 'index_page.dart';

/// 浏览器远程管理文件用的 HTTP 接口。
///
/// 本身不监听端口：宿主（速享的消息服务）把 [routes] 里的接口和以 `/sdcard`
/// 开头的路径转交给 [getFileServerHandler] 返回的路由。`/sdcard` 是网页端约定的
/// 根路径，对应本机的 [Storage.root]，访问不到它外面的文件。
class Server {
  Server._();

  /// 需要转交过来的接口。`/getdir`、`/rename`、`/delete` 是速享网页端在用的，
  /// `/mkdir`、`/upload` 给目录页面用。
  static const List<String> routes = [
    '/getdir',
    '/rename',
    '/delete',
    '/mkdir',
    '/upload',
  ];

  static Router? _router;

  /// 初始化文件服务。
  ///
  /// 原来的实现会在所有网卡上另开一个不需要验证的端口；这里不再单独监听，
  /// 远程访问都经过宿主的服务，受“网页服务”开关控制。
  static Future<void> start() async => Storage.init();

  /// 处理转交过来的请求的路由。
  static Future<Router> getFileServerHandler() async => _router ??= _createRouter();

  static Router _createRouter() {
    return Router()
      ..all('/<ignored|.*>', _rejectCrossSite)
      ..get('/getdir', _getDir)
      ..get('/rename', _rename)
      ..get('/delete', _delete)
      ..get('/mkdir', _mkdir)
      ..post('/upload', _upload)
      ..all('/<ignored|.*>', _serve);
  }

  /// 拒绝其他网站发起的请求，其余请求交给后面的路由。
  ///
  /// 速享的消息服务给所有响应都加了 `Access-Control-Allow-Origin: *`，删除、重命名又是 GET 请求，
  /// 不拦的话，用户在浏览器里打开的任何网站都能读取、删除这台设备上的文件。
  /// 目录页面发的是同源请求，在地址栏直接打开时 `Sec-Fetch-Site` 是 `none`，
  /// 速享客户端不带这些请求头，都不受影响。
  static Response _rejectCrossSite(Request request, String ignored) {
    final site = request.headers['sec-fetch-site'];
    // 不支持 Sec-Fetch-Site 的老浏览器，跨源的 fetch 和 XHR 仍然会带 Origin
    final origin = request.headers['origin'];
    final crossSite = site != null
        ? site == 'cross-site'
        : origin != null && Uri.tryParse(origin)?.authority != request.headers['host'];
    return crossSite ? Response.forbidden('Cross-site request rejected') : Router.routeNotFound;
  }

  /// `GET /getdir?path=/sdcard/Download`：返回 JSON 字符串数组，格式见 [Storage.listing]。
  ///
  /// 内容类型保持 `text/plain`：网页端拿到字符串后自己 `jsonDecode`，
  /// 返回 `application/json` 会被 Dio 提前解析成列表，导致网页端解析失败。
  static Future<Response> _getDir(Request request) => _guard(() async {
        final dir = _localPath(request, 'path');
        return Response.ok(jsonEncode(await Storage.listing(dir)));
      });

  /// `GET /rename?path=/sdcard/a.txt&name=b.txt`
  static Future<Response> _rename(Request request) => _guard(() async {
        final path = _localPath(request, 'path', allowRoot: false);
        await Storage.rename(path, request.url.queryParameters['name'] ?? '');
        return Response.ok('ok');
      });

  /// `GET /delete?path=/sdcard/a.txt`，文件夹连同里面的内容一起删除。
  static Future<Response> _delete(Request request) => _guard(() async {
        await Storage.delete(_localPath(request, 'path', allowRoot: false));
        return Response.ok('ok');
      });

  /// `GET /mkdir?path=/sdcard/Download&name=新文件夹`
  static Future<Response> _mkdir(Request request) => _guard(() async {
        final dir = _localPath(request, 'path');
        await Storage.createDirectory(dir, request.url.queryParameters['name'] ?? '');
        return Response.ok('ok');
      });

  /// `POST /upload?path=/sdcard/Download&name=a.txt`，请求体是文件内容，重名时自动改名。
  static Future<Response> _upload(Request request) => _guard(() async {
        final dir = _localPath(request, 'path');
        final target = await Storage.availablePath(dir, request.url.queryParameters['name'] ?? '');
        final file = File(target);
        final sink = file.openWrite();
        try {
          await sink.addStream(request.read());
        } catch (_) {
          await sink.close();
          await file.delete();
          rethrow;
        }
        await sink.close();
        return Response.ok(jsonEncode({'path': Storage.toVirtual(target)}));
      });

  /// `GET /sdcard/...`：文件夹返回目录页面，文件返回内容，支持断点续传和视频拖动。
  static Future<Response> _serve(Request request, String ignored) => _guard(() async {
        if (request.method != 'GET' && request.method != 'HEAD') {
          return Response(HttpStatus.methodNotAllowed);
        }
        final local = Storage.toLocal('/${request.url.pathSegments.join('/')}');
        if (local == null) return Response.notFound('Not Found');
        final type = await FileSystemEntity.type(local);
        if (type == FileSystemEntityType.directory) {
          final language = request.headers[HttpHeaders.acceptLanguageHeader] ?? '';
          final html = indexPage(
            path: Storage.toVirtual(local),
            entries: await Storage.list(local),
            chinese: language.toLowerCase().startsWith('zh'),
          );
          return Response.ok(
            html,
            headers: {HttpHeaders.contentTypeHeader: 'text/html; charset=utf-8'},
          );
        }
        if (type == FileSystemEntityType.file) return _sendFile(request, File(local));
        return Response.notFound('Not Found');
      });

  static Future<Response> _sendFile(Request request, File file) async {
    final length = await file.length();
    final headers = <String, String>{
      HttpHeaders.contentTypeHeader: lookupMimeType(file.path) ?? 'application/octet-stream',
      HttpHeaders.acceptRangesHeader: 'bytes',
      HttpHeaders.lastModifiedHeader: HttpDate.format(await file.lastModified()),
    };
    if (request.url.queryParameters['download'] == 'true') {
      final name = Uri.encodeComponent(p.basename(file.path));
      headers['content-disposition'] = "attachment; filename*=UTF-8''$name";
    }
    final range = _parseRange(request.headers[HttpHeaders.rangeHeader], length);
    if (range == null) {
      headers[HttpHeaders.contentLengthHeader] = '$length';
      return Response.ok(file.openRead(), headers: headers);
    }
    final (start, end) = range;
    headers[HttpHeaders.contentRangeHeader] = 'bytes $start-$end/$length';
    headers[HttpHeaders.contentLengthHeader] = '${end - start + 1}';
    return Response(
      HttpStatus.partialContent,
      body: file.openRead(start, end + 1),
      headers: headers,
    );
  }

  /// 解析单段的 `Range: bytes=start-end`，不支持的写法按整个文件返回。
  static (int, int)? _parseRange(String? header, int length) {
    if (header == null || length == 0) return null;
    final match = RegExp(r'^bytes=(\d*)-(\d*)$').firstMatch(header.trim());
    if (match == null) return null;
    final from = match.group(1)!;
    final to = match.group(2)!;
    int start;
    int end;
    if (from.isEmpty) {
      // `bytes=-500` 表示最后 500 个字节
      final suffix = int.tryParse(to) ?? 0;
      if (suffix == 0) return null;
      start = suffix >= length ? 0 : length - suffix;
      end = length - 1;
    } else {
      start = int.parse(from);
      end = to.isEmpty ? length - 1 : int.parse(to);
      if (end >= length) end = length - 1;
    }
    if (start > end) return null;
    return (start, end);
  }

  /// 查询参数 [key] 对应的本机路径
  static String _localPath(Request request, String key, {bool allowRoot = true}) {
    final value = request.url.queryParameters[key];
    if (value == null || value.isEmpty) {
      throw _HttpError(HttpStatus.badRequest, 'Missing parameter: $key');
    }
    final path = Storage.toLocal(value);
    if (path == null) {
      throw _HttpError(HttpStatus.forbidden, 'Outside of ${Storage.virtualRoot}: $value');
    }
    if (!allowRoot && p.equals(path, Storage.root)) {
      throw _HttpError(HttpStatus.forbidden, 'Not allowed on ${Storage.virtualRoot}');
    }
    return path;
  }

  static Future<Response> _guard(Future<Response> Function() handler) async {
    try {
      return await handler();
    } on _HttpError catch (e) {
      return Response(e.status, body: e.message);
    } on FileManagerException catch (e) {
      final status = switch (e.error) {
        FileManagerError.invalidName => HttpStatus.badRequest,
        FileManagerError.alreadyExists => HttpStatus.conflict,
        FileManagerError.notFound => HttpStatus.notFound,
      };
      return Response(status, body: e.toString());
    } on FileSystemException catch (e) {
      return Response.forbidden(e.osError?.message ?? e.message);
    }
  }
}

class _HttpError implements Exception {
  const _HttpError(this.status, this.message);

  final int status;
  final String message;
}
