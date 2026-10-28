import 'dart:convert';

import 'package:path/path.dart' as p;

import '../src/storage.dart';

const _escape = HtmlEscape();

/// 浏览器打开 `/sdcard/...` 下的文件夹时显示的页面，
/// 可以浏览、下载、上传、新建文件夹、重命名和删除，操作调用 `Server.routes` 里的接口。
String indexPage({
  required String path,
  required List<FileEntry> entries,
  required bool chinese,
}) {
  String t(String zh, String en) => chinese ? zh : en;

  final segments = path.split('/').where((segment) => segment.isNotEmpty).toList();
  final crumbs = StringBuffer();
  for (var i = 0; i < segments.length; i++) {
    final name = _escape.convert(segments[i]);
    if (i > 0) crumbs.write('<span class="sep">/</span>');
    if (i == segments.length - 1) {
      crumbs.write('<strong>$name</strong>');
    } else {
      crumbs.write('<a href="${_href('/${segments.sublist(0, i + 1).join('/')}')}">$name</a>');
    }
  }

  final rows = StringBuffer();
  if (path != Storage.virtualRoot) {
    rows.write(
      '<tr><td class="name" colspan="4"><a href="${_href(p.posix.dirname(path))}">📁 ..</a></td></tr>',
    );
  }
  for (final entry in entries) {
    final virtualPath = p.posix.join(path, entry.name);
    final href = _href(virtualPath);
    final name = _escape.convert(entry.name);
    final data = 'data-path="${_escape.convert(virtualPath)}" data-name="$name"';
    rows
      ..write('<tr${entry.isHidden ? ' class="hidden"' : ''}>')
      ..write('<td class="name"><a href="$href">${entry.isDirectory ? '📁' : '📄'} $name</a></td>')
      ..write('<td class="size">${entry.isDirectory ? '' : Storage.formatSize(entry.size)}</td>')
      ..write('<td class="time">${Storage.formatTime(entry.modified)}</td>')
      ..write('<td class="actions">')
      ..write(entry.isDirectory ? '' : '<a href="$href?download=true">${t('下载', 'Download')}</a>')
      ..write('<button data-action="rename" $data>${t('重命名', 'Rename')}</button>')
      ..write('<button data-action="delete" $data>${t('删除', 'Delete')}</button>')
      ..write('</td></tr>');
  }
  if (entries.isEmpty) {
    rows.write('<tr><td class="empty" colspan="4">${t('文件夹是空的', 'This folder is empty')}</td></tr>');
  }

  final strings = {
    'folderName': t('文件夹名称', 'Folder name'),
    'newName': t('新名称', 'New name'),
    'confirmDelete': t(
      '确定删除“%s”吗？文件夹会连同里面的内容一起删除。',
      'Delete "%s"? A folder is deleted together with everything inside it.',
    ),
    'uploading': t('正在上传 %d/%n：', 'Uploading %d/%n: '),
  };

  return '''
<!doctype html>
<html lang="${chinese ? 'zh-CN' : 'en'}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${_escape.convert(path)}</title>
<style>$_style</style>
</head>
<body>
<main>
<header>
<nav>$crumbs</nav>
<div class="tools">
<span id="status"></span>
<button data-action="mkdir">${t('新建文件夹', 'New folder')}</button>
<label class="button">${t('上传文件', 'Upload')}<input id="upload" type="file" multiple hidden></label>
</div>
</header>
<table><tbody>$rows</tbody></table>
</main>
<script>const DIR = ${_json(path)}; const T = ${_json(strings)};</script>
<script>$_script</script>
</body>
</html>
''';
}

/// 逐段编码的链接地址
String _href(String virtualPath) => virtualPath.split('/').map(Uri.encodeComponent).join('/');

/// 嵌进 `<script>` 的 JSON，转义 `<` 以免提前结束标签
String _json(Object value) => jsonEncode(value).replaceAll('<', r'<');

const _style = r'''
:root { color-scheme: light dark; --fg: #1f2328; --muted: #656d76; --line: #d0d7de; --bg: #fff; --accent: #0969da; }
@media (prefers-color-scheme: dark) { :root { --fg: #e6edf3; --muted: #8d96a0; --line: #30363d; --bg: #0d1117; --accent: #4493f8; } }
body { margin: 0; color: var(--fg); background: var(--bg); font: 14px/1.5 system-ui, -apple-system, "Segoe UI", "PingFang SC", "Microsoft YaHei", sans-serif; }
main { max-width: 960px; margin: 0 auto; padding: 16px; }
header { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; justify-content: space-between; margin-bottom: 12px; }
nav { font-size: 16px; word-break: break-all; }
nav a { color: var(--accent); text-decoration: none; }
.sep { color: var(--muted); margin: 0 4px; }
.tools { display: flex; flex-wrap: wrap; gap: 8px; align-items: center; }
button, .button { font: inherit; padding: 4px 10px; border: 1px solid var(--line); border-radius: 6px; background: transparent; color: inherit; cursor: pointer; }
table { width: 100%; border-collapse: collapse; }
td { padding: 8px 6px; border-top: 1px solid var(--line); vertical-align: middle; }
td.name a { color: inherit; text-decoration: none; word-break: break-all; }
tr.hidden td.name a { opacity: .6; }
td.size, td.time, #status, .empty { color: var(--muted); }
td.size, td.time { white-space: nowrap; }
td.size, td.actions { text-align: right; }
td.actions { white-space: nowrap; }
td.actions a { color: var(--accent); text-decoration: none; margin-right: 4px; }
td.actions button { padding: 2px 8px; margin-left: 4px; }
@media (max-width: 640px) { td.time { display: none; } td.actions { white-space: normal; } }
''';

const _script = r'''
async function call(route, params, init) {
  const response = await fetch(route + '?' + new URLSearchParams(params), init);
  if (!response.ok) throw new Error(await response.text());
}
function finish(promise) {
  promise.then(() => location.reload(), (error) => alert(error.message));
}
document.addEventListener('click', (event) => {
  const button = event.target.closest('button[data-action]');
  if (!button) return;
  const { action, path, name } = button.dataset;
  if (action === 'mkdir') {
    const value = prompt(T.folderName);
    if (value) finish(call('/mkdir', { path: DIR, name: value }));
  } else if (action === 'rename') {
    const value = prompt(T.newName, name);
    if (value && value !== name) finish(call('/rename', { path, name: value }));
  } else if (action === 'delete') {
    if (confirm(T.confirmDelete.replace('%s', name))) finish(call('/delete', { path }));
  }
});
document.getElementById('upload').addEventListener('change', async (event) => {
  const files = Array.from(event.target.files);
  const status = document.getElementById('status');
  try {
    for (let i = 0; i < files.length; i++) {
      status.textContent = T.uploading.replace('%d', i + 1).replace('%n', files.length) + files[i].name;
      await call('/upload', { path: DIR, name: files[i].name }, { method: 'POST', body: files[i] });
    }
    location.reload();
  } catch (error) {
    status.textContent = '';
    alert(error.message);
  }
});
''';
