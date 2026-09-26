import 'dart:convert';
import 'package:http/http.dart' as http;

/// 后端 API 客户端。baseUrl 可在设置里改；token 登录后保存。
class Api {
  static String baseUrl = 'http://81.70.191.44:8001';
  static String? token;

  /// 把后端返回的相对地址（/images/x.jpg、/materials/...）补全为完整 URL
  static String resolveUrl(String url) {
    if (url.startsWith('http://') || url.startsWith('https://')) return url;
    return '$baseUrl$url';
  }

  /// 供 Image.network 直接访问受保护资源时带上的鉴权头
  static Map<String, String> get authHeaders {
    final t = token;
    if (t != null && t.isNotEmpty) return {'Authorization': 'Bearer $t'};
    return const {};
  }

  static Map<String, String> get _headers {
    final h = {'Content-Type': 'application/json'};
    final t = token;
    if (t != null && t.isNotEmpty) h['Authorization'] = 'Bearer $t';
    return h;
  }

  static Future<dynamic> get(String path) async {
    final r = await http.get(Uri.parse('$baseUrl$path'), headers: _headers);
    return _handle(r);
  }

  static Future<dynamic> post(String path, [Map<String, dynamic>? body]) async {
    final r = await http.post(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(r);
  }

  static Future<dynamic> put(String path, [Map<String, dynamic>? body]) async {
    final r = await http.put(
      Uri.parse('$baseUrl$path'),
      headers: _headers,
      body: body == null ? null : jsonEncode(body),
    );
    return _handle(r);
  }

  static Future<dynamic> delete(String path) async {
    final r = await http.delete(Uri.parse('$baseUrl$path'), headers: _headers);
    return _handle(r);
  }

  /// multipart 文件上传（field 如 "files"/"file"）
  static Future<dynamic> postMultipart(String path, String field, List<String> filePaths) async {
    final req = http.MultipartRequest('POST', Uri.parse('$baseUrl$path'));
    final t = token;
    if (t != null && t.isNotEmpty) req.headers['Authorization'] = 'Bearer $t';
    for (final p in filePaths) {
      req.files.add(await http.MultipartFile.fromPath(field, p));
    }
    final streamed = await req.send();
    final r = await http.Response.fromStream(streamed);
    return _handle(r);
  }

  static Future<dynamic> _handle(http.Response r) async {
    dynamic data;
    if (r.bodyBytes.isNotEmpty) {
      try {
        data = jsonDecode(utf8.decode(r.bodyBytes));
      } catch (_) {
        data = utf8.decode(r.bodyBytes);
      }
    }
    if (r.statusCode >= 400) {
      String msg = '请求失败 (${r.statusCode})';
      if (data is Map && data['detail'] != null) msg = data['detail'].toString();
      throw Exception(msg);
    }
    return data;
  }
}
