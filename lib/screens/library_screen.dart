import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../api.dart';

class LibraryScreen extends StatefulWidget {
  const LibraryScreen({super.key});

  @override
  State<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends State<LibraryScreen> {
  List<dynamic> _articles = [];
  List<dynamic> _materials = [];
  bool _loading = true;
  int _tab = 0; // 0=文章库 1=素材库
  bool _uploading = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final a = await Api.get('/api/articles');
      final m = await Api.get('/api/materials');
      if (mounted) {
        setState(() {
          _articles = (a as List?) ?? [];
          _materials = (m as List?) ?? [];
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadArticle(int id) async {
    try {
      final a = await Api.get('/api/articles/$id');
      if (mounted) Navigator.of(context).pop(a);
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _deleteArticle(int id) async {
    final ok = await _confirm('删除文章', '确定删除这篇文章？');
    if (ok != true) return;
    try {
      await Api.delete('/api/articles/$id');
      await _load();
    } catch (e) {
      _err(e);
    }
  }

  Future<void> _uploadMaterials() async {
    try {
      final res = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (res == null || res.files.isEmpty) return;
      setState(() => _uploading = true);
      var ok = 0;
      for (final f in res.files) {
        final p = f.path;
        if (p == null) continue;
        await Api.postMultipart('/api/materials', 'file', [p]);
        ok++;
      }
      await _load();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('已上传 $ok 个素材')));
      }
    } catch (e) {
      _err(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _deleteMaterial(int id) async {
    final ok = await _confirm('删除素材', '确定删除这个素材？');
    if (ok != true) return;
    try {
      await Api.delete('/api/materials/$id');
      await _load();
    } catch (e) {
      _err(e);
    }
  }

  Future<bool?> _confirm(String title, String msg) {
    return showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(msg),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('删除')),
        ],
      ),
    );
  }

  void _err(Object e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('本地库')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: SegmentedButton<int>(
              segments: const [
                ButtonSegment(value: 0, label: Text('文章库')),
                ButtonSegment(value: 1, label: Text('素材库')),
              ],
              selected: {_tab},
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
          ),
          if (_tab == 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _uploading ? null : _uploadMaterials,
                  icon: const Icon(Icons.upload_file),
                  label: Text(_uploading ? '上传中…' : '上传素材（文字 / 图片等任意文件）'),
                ),
              ),
            ),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_tab == 0) return _buildArticles();
    return _buildMaterials();
  }

  Widget _buildArticles() {
    if (_articles.isEmpty) {
      return const Center(child: Text('暂无保存的文章', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _articles.length,
        itemBuilder: (_, i) {
          final a = _articles[i];
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              title: Text(a['title'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text('${a['topic'] ?? ''} · ${a['status'] == 'pushed' ? '已推送' : '草稿'}'),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(onPressed: () => _loadArticle(a['id']), child: const Text('载入')),
                  IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteArticle(a['id'])),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMaterials() {
    if (_materials.isEmpty) {
      return const Center(child: Text('暂无素材，点击上方「上传素材」添加', style: TextStyle(color: Colors.grey)));
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        itemCount: _materials.length,
        itemBuilder: (_, i) {
          final m = _materials[i];
          final size = (m['size'] as num?)?.toInt() ?? 0;
          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            child: ListTile(
              leading: const Icon(Icons.description_outlined),
              title: Text(m['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(_formatSize(size)),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => _deleteMaterial(m['id'])),
            ),
          );
        },
      ),
    );
  }

  String _formatSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
}
