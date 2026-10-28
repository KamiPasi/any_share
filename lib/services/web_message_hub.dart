/// 发给网页端（浏览器）的消息。
///
/// 浏览器没有自己的服务器，只能轮询 /message 来取消息。以前所有浏览器共用一个队列，
/// 谁先取到就归谁，同时开两个网页会互相抢消息。现在发给网页端的消息都记在 [history] 里，
/// 每个浏览器各记一个读到哪儿的位置，互不影响。
class WebMessageHub {
  /// 本机发出的消息，以及浏览器发给本机的消息，按到达顺序排列
  final List<Map<String, dynamic>> history = [];
  final Map<String, _WebClient> _clients = {};

  void add(Map<String, dynamic> message) {
    history.add(message);
  }

  /// 只发给眼下在线的浏览器、不进历史的消息，比如让浏览器上传文件的通知
  void notify(Map<String, dynamic> message) {
    final DateTime now = DateTime.now();
    for (final _WebClient client in _clients.values) {
      if (now.difference(client.lastSeen) < const Duration(seconds: 30)) {
        client.pending.add(message);
      }
    }
  }

  /// 取 [id] 这个浏览器还没取过的消息，最多 [max] 条。
  ///
  /// [reset] 为 true 时从头开始取，网页刷新后用它把之前的消息重新拿一遍。
  List<Map<String, dynamic>> take(String id, {int max = 1, bool reset = false}) {
    final _WebClient client = _clients.putIfAbsent(id, () => _WebClient());
    client.lastSeen = DateTime.now();
    if (reset) {
      client.cursor = 0;
      client.pending.clear();
    }
    final List<Map<String, dynamic>> result = [];
    while (result.length < max && client.pending.isNotEmpty) {
      result.add(client.pending.removeAt(0));
    }
    while (result.length < max && client.cursor < history.length) {
      result.add(history[client.cursor]);
      client.cursor++;
    }
    return result;
  }
}

class _WebClient {
  int cursor = 0;
  final List<Map<String, dynamic>> pending = [];
  DateTime lastSeen = DateTime.now();
}
