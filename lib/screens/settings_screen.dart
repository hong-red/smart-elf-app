import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _baseUrl = TextEditingController();
  final _key = TextEditingController();
  final _model = TextEditingController();
  final _appid = TextEditingController();
  final _secret = TextEditingController();
  bool _keySet = false;
  bool _secretSet = false;
  bool _loading = false;
  String _freeUntil = '2026-12';

  @override
  void initState() {
    super.initState();
    _baseUrl.text = Api.baseUrl;
    _load();
  }

  @override
  void dispose() {
    for (final c in [_baseUrl, _key, _model, _appid, _secret]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _load() async {
    try {
      final info = await Api.get('/api/info');
      final s = await Api.get('/api/settings');
      if (mounted) {
        setState(() {
          _freeUntil = info['free_until'] ?? '2026-12';
          _model.text = s['deepseek_model'] ?? 'deepseek-chat';
          _appid.text = s['wechat_appid'] ?? '';
          _keySet = s['deepseek_api_key_set'] ?? false;
          _secretSet = s['wechat_appsecret_set'] ?? false;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      Api.baseUrl = _baseUrl.text.trim().replaceAll(RegExp(r'/+$'), '');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('baseUrl', Api.baseUrl);
      final body = <String, dynamic>{
        'deepseek_model': _model.text.trim(),
        'wechat_appid': _appid.text.trim(),
      };
      if (_key.text.trim().isNotEmpty) body['deepseek_api_key'] = _key.text.trim();
      if (_secret.text.trim().isNotEmpty) body['wechat_appsecret'] = _secret.text.trim();
      await Api.post('/api/settings', body);
      _toast('已保存');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _export() async {
    try {
      final data = await Api.get('/api/export');
      final json = const JsonEncoder.withIndent('  ').convert(data);
      await Clipboard.setData(ClipboardData(text: json));
      _toast('数据已复制到剪贴板');
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('后端地址', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
                const SizedBox(height: 6),
                TextField(controller: _baseUrl, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true, hintText: 'http://IP:8001')),
                const SizedBox(height: 20),
                const Text('DeepSeek（内容生成）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _key, obscureText: true, decoration: InputDecoration(
                  labelText: _keySet ? 'API Key（已设置，留空则不修改）' : 'API Key', border: const OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _model, decoration: const InputDecoration(labelText: '模型', border: OutlineInputBorder())),
                const SizedBox(height: 20),
                const Text('微信公众号（可选）', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                TextField(controller: _appid, decoration: const InputDecoration(labelText: 'AppID', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _secret, obscureText: true, decoration: InputDecoration(
                  labelText: _secretSet ? 'AppSecret（已设置，留空则不修改）' : 'AppSecret', border: const OutlineInputBorder())),
                const SizedBox(height: 24),
                FilledButton(onPressed: _save, child: const Text('保存设置')),
                const SizedBox(height: 12),
                OutlinedButton.icon(onPressed: _export, icon: const Icon(Icons.download), label: const Text('导出我的数据')),
                const SizedBox(height: 20),
                Text('免费期至 $_freeUntil · 到期后可导出数据迁移', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
    );
  }
}
