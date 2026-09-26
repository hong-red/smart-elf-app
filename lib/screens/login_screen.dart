import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _register = false;
  bool _loading = false;
  final _user = TextEditingController();
  final _pass = TextEditingController();
  final _invite = TextEditingController();

  @override
  void dispose() {
    _user.dispose();
    _pass.dispose();
    _invite.dispose();
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final u = _user.text.trim();
    final p = _pass.text;
    if (u.isEmpty || p.isEmpty) {
      _toast('请填写用户名和密码');
      return;
    }
    setState(() => _loading = true);
    try {
      if (_register) {
        await Api.post('/api/auth/register', {
          'username': u,
          'password': p,
          'invite_code': _invite.text.trim(),
        });
        _toast('注册成功，请登录');
        setState(() => _register = false);
      } else {
        final r = await Api.post('/api/auth/login', {'username': u, 'password': p});
        Api.token = r['token'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('token', r['token']);
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => HomeScreen(username: r['username'])),
        );
      }
    } catch (e) {
      _toast(e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('🧚 妙文', textAlign: TextAlign.center, style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('公众号文章生成器 · 邀请制', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade600)),
                const SizedBox(height: 20),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: false, label: Text('登录')),
                    ButtonSegment(value: true, label: Text('注册')),
                  ],
                  selected: {_register},
                  onSelectionChanged: (s) => setState(() => _register = s.first),
                ),
                const SizedBox(height: 16),
                TextField(controller: _user, decoration: const InputDecoration(labelText: '用户名', border: OutlineInputBorder())),
                const SizedBox(height: 12),
                TextField(controller: _pass, obscureText: true, decoration: const InputDecoration(labelText: '密码（至少 6 位）', border: OutlineInputBorder())),
                if (_register) ...[
                  const SizedBox(height: 12),
                  TextField(controller: _invite, decoration: const InputDecoration(labelText: '邀请码', border: OutlineInputBorder())),
                ],
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                  child: Text(_loading ? '请稍候…' : (_register ? '注册' : '登录')),
                ),
                const SizedBox(height: 12),
                Text('免费期至 2026-12 · 到期可导出数据迁移', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
