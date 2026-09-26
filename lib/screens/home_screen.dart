import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../api.dart';
import 'login_screen.dart';
import 'settings_screen.dart';
import 'library_screen.dart';

class HomeScreen extends StatefulWidget {
  final String? username;
  const HomeScreen({super.key, this.username});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _step = 0;

  // 第 1 步
  final _topic = TextEditingController();
  final _style = TextEditingController();
  final _extra = TextEditingController();
  String _template = 'general';
  int _count = 5;
  List<String> _titles = [];
  String? _selectedTitle;

  // 第 2 步
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _feedback = TextEditingController();
  final _materialReq = TextEditingController();
  final List<Map<String, String>> _selectedMaterials = [];

  // 第 3 步
  final _imgQuery = TextEditingController();
  List<dynamic> _imgResults = [];
  final List<Map<String, String>> _selectedImages = [];

  // 第 4 步
  String _theme = 'default';
  String _tone = '';
  bool _polish = true;
  bool _addSummary = false;
  bool _addGolden = false;
  bool _addFollow = false;
  final _result = TextEditingController();
  int? _articleId;
  String? _coverPath;

  bool _loading = false;
  bool _previewMode = false; // 编译/预览模式开关：小屏手机可切到预览查看排版效果
  List<dynamic> _templates = [];
  List<dynamic> _themes = [];

  @override
  void initState() {
    super.initState();
    _loadMeta();
  }

  @override
  void dispose() {
    for (final c in [_topic, _style, _extra, _title, _content, _feedback, _materialReq, _imgQuery, _result]) {
      c.dispose();
    }
    super.dispose();
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _loadMeta() async {
    try {
      final tpls = await Api.get('/api/templates');
      final themes = await Api.get('/api/themes');
      if (mounted) {
        setState(() {
          _templates = tpls is List ? tpls : [];
          _themes = themes is List ? themes : [];
          if (_templates.isNotEmpty) _template = _templates.first['key'];
        });
      }
    } catch (_) {}
  }

  Future<void> _logout() async {
    try { await Api.post('/api/auth/logout'); } catch (_) {}
    Api.token = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('token');
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginScreen()),
      (route) => false,
    );
  }

  Future<void> _openLibrary() async {
    final a = await Navigator.of(context).push<Map>(
      MaterialPageRoute(builder: (_) => const LibraryScreen()),
    );
    if (a == null || !mounted) return;
    setState(() {
      _articleId = a['id'];
      _topic.text = a['topic'] ?? '';
      _title.text = a['title'] ?? '';
      _content.text = a['content_md'] ?? '';
      _result.text = a['content_md'] ?? '';
      _theme = a['theme'] ?? 'default';
      _step = 3;
    });
  }

  void _showHelp() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: const Text('使用说明'),
      content: const SingleChildScrollView(child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('① 选题：输入主题 → 生成题目 → 选一个'),
          SizedBox(height: 6),
          Text('② 成文：按题目生成正文，可反复提意见改写'),
          SizedBox(height: 6),
          Text('③ 选图：本地上传 / 全网搜索配图'),
          SizedBox(height: 6),
          Text('④ 排版：格式优化 → 保存 / 推送到草稿箱'),
          SizedBox(height: 6),
          Text('⑤ 正文 / 结果处有「编辑 / 预览」开关，小屏手机可切到预览看排版效果。'),
          SizedBox(height: 6),
          Text('⑥ 本地库支持上传素材（文字、图片等任意文件）。'),
          SizedBox(height: 12),
          Text('推送到草稿箱前，需在「设置」填好 DeepSeek Key 和公众号 AppID/AppSecret，并把本机公网 IP 加入公众号「IP 白名单」。'),
        ],
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('知道了'))],
    ));
  }

  // ---------------- 动作 ----------------
  Future<void> _genTitles() async {
    if (_topic.text.trim().isEmpty) { _toast('请先填写主题'); return; }
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/generate/titles', {
        'topic': _topic.text.trim(),
        'count': _count,
        'style': _style.text.trim(),
        'extra': _extra.text.trim(),
        'template': _template,
      });
      setState(() { _titles = (r['titles'] as List).cast<String>(); _selectedTitle = null; });
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _genContent() async {
    if (_title.text.trim().isEmpty) { _toast('请先填写标题'); return; }
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/generate/content', {
        'topic': _topic.text.trim(),
        'title': _title.text.trim(),
        'style': _style.text.trim(),
        'extra': _extra.text.trim(),
        'template': _template,
        'feedback': '',
        'previous_content': '',
        'material_ids': _materialIds(),
        'material_note': _materialReq.text.trim(),
      });
      setState(() => _content.text = r['content']);
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _refine() async {
    if (_feedback.text.trim().isEmpty) { _toast('请先填写调试意见'); return; }
    if (_content.text.trim().isEmpty) { _toast('请先生成正文'); return; }
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/generate/content', {
        'topic': _topic.text.trim(),
        'title': _title.text.trim(),
        'style': _style.text.trim(),
        'extra': _extra.text.trim(),
        'template': _template,
        'feedback': _feedback.text.trim(),
        'previous_content': _content.text,
        'material_ids': _materialIds(),
        'material_note': _materialReq.text.trim(),
      });
      setState(() { _content.text = r['content']; _feedback.clear(); });
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickLocalImages() async {
    try {
      final files = await ImagePicker().pickMultiImage();
      if (files.isEmpty) return;
      setState(() => _loading = true);
      final paths = files.map((f) => f.path).toList();
      final r = await Api.postMultipart('/api/images', 'files', paths);
      final items = (r as List?) ?? [];
      setState(() {
        for (final it in items) {
          _selectedImages.add({'url': it['url'], 'name': it['name'] ?? '配图'});
        }
      });
      _toast('图片已上传');
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _searchImages() async {
    if (_imgQuery.text.trim().isEmpty) { _toast('请输入关键词'); return; }
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/images/search', {'query': _imgQuery.text.trim()});
      setState(() => _imgResults = (r['results'] as List?) ?? []);
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickImage(dynamic img) async {
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/images/fetch', {
        'url': img['url'], 'thumb': img['thumb'] ?? '', 'page': img['page'] ?? '',
      });
      setState(() => _selectedImages.add({'url': r['url'], 'name': img['title'] ?? r['name'] ?? '配图'}));
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  bool _isImageName(String name) {
    final n = name.toLowerCase();
    return n.endsWith('.jpg') || n.endsWith('.jpeg') || n.endsWith('.png') ||
        n.endsWith('.gif') || n.endsWith('.webp') || n.endsWith('.bmp');
  }

  Future<void> _useMaterial(int id, String name) async {
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/materials/$id/use');
      setState(() => _selectedImages.add({'url': r['url'], 'name': name}));
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _pickMaterialImages() async {
    try {
      final items = await Api.get('/api/materials');
      final imgs = ((items as List?) ?? [])
          .where((m) => _isImageName(m['name']?.toString() ?? ''))
          .toList();
      if (imgs.isEmpty) { _toast('素材库里还没有图片素材'); return; }
      if (!mounted) return;
      await showModalBottomSheet(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('从素材库选图', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: imgs.map((m) => ListTile(
                    leading: Image.network(
                      Api.resolveUrl(m['url']?.toString() ?? ''),
                      width: 48, height: 48, fit: BoxFit.cover,
                      headers: Api.authHeaders,
                      errorBuilder: (_, __, ___) => const Icon(Icons.image),
                    ),
                    title: Text(m['name']?.toString() ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                    trailing: const Icon(Icons.add_circle_outline, color: Color(0xFF20a53a)),
                    onTap: () async {
                      Navigator.pop(ctx);
                      await _useMaterial(m['id'] as int, m['name']?.toString() ?? '素材');
                    },
                  )).toList(),
                ),
              ),
            ],
          ),
        ),
      );
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
  }

  List<int> _materialIds() => _selectedMaterials
      .map((m) => int.tryParse(m['id'] ?? ''))
      .whereType<int>()
      .toList();

  Future<void> _pickMaterials() async {
    try {
      final items = await Api.get('/api/materials');
      final all = (items as List?) ?? [];
      if (all.isEmpty) { _toast('素材库还是空的，先去「本地库」上传素材'); return; }
      if (!mounted) return;
      final chosen = <int>{ for (final m in _selectedMaterials) int.tryParse(m['id'] ?? '') ?? -1 };
      chosen.remove(-1);
      final picked = await showModalBottomSheet<List<dynamic>>(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, setSheet) {
            final cur = {...chosen};
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('选择素材（可多选）', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        Text('已选 ${cur.length}', style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: all.map((m) {
                        final id = (m['id'] as num?)?.toInt() ?? 0;
                        final name = m['name']?.toString() ?? '';
                        return CheckboxListTile(
                          value: cur.contains(id),
                          title: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
                          onChanged: (v) => setSheet(() {
                            if (v == true) {
                              cur.add(id);
                            } else {
                              cur.remove(id);
                            }
                          }),
                        );
                      }).toList(),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton(
                      onPressed: () => Navigator.pop(ctx, all.where((m) => cur.contains((m['id'] as num?)?.toInt() ?? 0)).toList()),
                      child: const Text('确定'),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );
      if (picked != null && mounted) {
        setState(() {
          _selectedMaterials.clear();
          for (final m in picked) {
            _selectedMaterials.add({
              'id': ((m['id'] as num?)?.toInt() ?? 0).toString(),
              'name': m['name']?.toString() ?? '素材',
            });
          }
        });
      }
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
  }

  Future<void> _format() async {
    if (_content.text.trim().isEmpty) { _toast('正文为空'); return; }
    setState(() => _loading = true);
    try {
      final r = await Api.post('/api/generate/format', {
        'content': _content.text,
        'title': _title.text.trim(),
        'theme': _theme,
        'tone': _tone,
        'template': _template,
        'add_summary': _addSummary,
        'add_golden': _addGolden,
        'add_follow': _addFollow,
        'polish': _polish,
        'images': _selectedImages.map((s) => {'url': s['url'], 'alt': s['name']}).toList(),
      });
      setState(() { _result.text = r['content']; _content.text = r['content']; _selectedImages.clear(); });
      _toast('格式优化完成');
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<int> _save() async {
    final body = {
      'topic': _topic.text.trim(),
      'title': _title.text.trim(),
      'content_md': _content.text,
      'content_html': '',
      'theme': _theme,
      'cover': '',
    };
    if (_articleId == null) {
      final r = await Api.post('/api/articles', body);
      _articleId = r['id'];
    } else {
      await Api.put('/api/articles/$_articleId', body);
    }
    return _articleId!;
  }

  Future<void> _uploadCover(int id) async {
    if (_coverPath == null) return;
    await Api.postMultipart('/api/articles/$id/cover', 'file', [_coverPath!]);
  }

  Future<void> _pickCover() async {
    try {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (f != null) setState(() => _coverPath = f.path);
    } catch (_) {}
  }

  Future<void> _push() async {
    setState(() => _loading = true);
    try {
      final id = await _save();
      await _uploadCover(id);
      await Api.post('/api/articles/$id/push', {});
      _toast('已推送到公众号草稿箱');
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _saveOnly() async {
    setState(() => _loading = true);
    try {
      final id = await _save();
      await _uploadCover(id);
      _toast('已保存到本地库');
    } catch (e) { _toast(e.toString().replaceFirst('Exception: ', '')); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  // ---------------- UI ----------------
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.username == null ? '妙文' : '妙文 · ${widget.username}'),
        actions: [
          IconButton(icon: const Icon(Icons.help_outline), onPressed: _showHelp),
          IconButton(icon: const Icon(Icons.collections_bookmark), onPressed: _openLibrary),
          IconButton(icon: const Icon(Icons.settings), onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen()))),
          IconButton(icon: const Icon(Icons.logout), onPressed: _logout),
        ],
      ),
      body: Column(
        children: [
          _stepBar(),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: _buildStep(),
                  ),
          ),
        ],
      ),
      bottomNavigationBar: _stepNav(),
    );
  }

  Widget _stepBar() {
    const names = ['选题', '成文', '选图', '排版'];
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          for (int i = 0; i < 4; i++) ...[
            if (i > 0) Expanded(child: Container(height: 2, color: i <= _step ? const Color(0xFF20a53a) : Colors.grey.shade300)),
            Column(
              children: [
                CircleAvatar(
                  radius: 12,
                  backgroundColor: i <= _step ? const Color(0xFF20a53a) : Colors.grey.shade300,
                  child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 13)),
                ),
                const SizedBox(height: 4),
                Text(names[i], style: TextStyle(fontSize: 12, color: i <= _step ? const Color(0xFF20a53a) : Colors.grey)),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0: return _buildStep1();
      case 1: return _buildStep2();
      case 2: return _buildStep3();
      default: return _buildStep4();
    }
  }

  Widget _field(String label, TextEditingController c, {int maxLines = 1, String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 6),
        TextField(controller: c, maxLines: maxLines, decoration: InputDecoration(hintText: hint, border: const OutlineInputBorder(), isDense: true)),
      ],
    );
  }

  // 正文/结果编辑器 + 编辑/预览开关（小屏手机可切到预览查看排版效果）
  Widget _contentEditorOrPreview(TextEditingController c, String label, {int maxLines = 12}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('编辑', style: TextStyle(fontSize: 12, color: _previewMode ? Colors.grey.shade500 : const Color(0xFF20a53a))),
                Switch(value: _previewMode, onChanged: (v) => setState(() => _previewMode = v)),
                Text('预览', style: TextStyle(fontSize: 12, color: _previewMode ? const Color(0xFF20a53a) : Colors.grey.shade500)),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        _previewMode
            ? Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: c.text.trim().isEmpty
                    ? Text('暂无内容，请先生成或输入正文', style: TextStyle(color: Colors.grey.shade400))
                    : MarkdownBody(
                        data: c.text,
                        selectable: true,
                        sizedImageBuilder: (config) => Image.network(
                          Api.resolveUrl(config.uri.toString()),
                          fit: BoxFit.contain,
                          errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                        ),
                      ),
              )
            : TextField(controller: c, maxLines: maxLines, decoration: const InputDecoration(border: OutlineInputBorder(), isDense: true)),
      ],
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('文章主题 / 关键词 *', _topic, maxLines: 3, hint: '例如：如何高效学习 Python'),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _templates.isEmpty ? null : _template,
          decoration: const InputDecoration(labelText: '写作模板', border: OutlineInputBorder(), isDense: true),
          items: _templates.map((t) => DropdownMenuItem<String>(value: t['key'] as String, child: Text(t['name'] as String))).toList(),
          onChanged: (v) => setState(() => _template = v ?? 'general'),
        ),
        const SizedBox(height: 12),
        _field('风格倾向（可选）', _style, hint: '轻松幽默 / 专业严谨'),
        const SizedBox(height: 12),
        _field('补充说明（可选）', _extra, hint: '例如：面向零基础读者'),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(
          value: _count,
          decoration: const InputDecoration(labelText: '生成数量', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: 3, child: Text('3')),
            DropdownMenuItem(value: 5, child: Text('5')),
            DropdownMenuItem(value: 8, child: Text('8')),
          ],
          onChanged: (v) => setState(() => _count = v ?? 5),
        ),
        const SizedBox(height: 16),
        FilledButton(onPressed: _genTitles, child: const Text('生成题目')),
        if (_titles.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('选择题目', style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
          const SizedBox(height: 8),
          for (final t in _titles)
            Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(t),
                leading: Icon(_selectedTitle == t ? Icons.radio_button_checked : Icons.radio_button_off, color: const Color(0xFF20a53a)),
                onTap: () => setState(() { _selectedTitle = t; _title.text = t; }),
              ),
            ),
        ],
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _field('文章标题', _title),
        const SizedBox(height: 12),
        FilledButton(onPressed: _genContent, child: const Text('生成正文')),
        const SizedBox(height: 12),
        _contentEditorOrPreview(_content, '正文（Markdown，可编辑）', maxLines: 12),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _field('调试意见', _feedback, hint: '例如：开头更吸引人一点 / 语气再活泼些 / 加一个小结 / 字数修改')),
            const SizedBox(width: 8),
            OutlinedButton(onPressed: _refine, child: const Text('按意见重写')),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: _field('需要根据素材库进行优化', _materialReq, maxLines: 2, hint: '例如：结合所选素材补充数据与观点')),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _pickMaterials,
              icon: const Icon(Icons.folder_open),
              label: const Text('从素材库选择'),
            ),
          ],
        ),
        if (_selectedMaterials.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedMaterials.map((m) => Chip(
              label: Text(m['name'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
              onDeleted: () => setState(() => _selectedMaterials.remove(m)),
            )).toList(),
          ),
        ],
      ],
    );
  }

  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: OutlinedButton.icon(onPressed: _pickLocalImages, icon: const Icon(Icons.add_photo_alternate), label: const Text('本地上传'))),
            const SizedBox(width: 8),
            Expanded(child: _field('搜索', _imgQuery, hint: '城市夜景')),
            const SizedBox(width: 8),
            FilledButton(onPressed: _searchImages, child: const Text('搜索')),
          ],
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _pickMaterialImages,
          icon: const Icon(Icons.folder_open),
          label: const Text('从素材库选图'),
        ),
        const SizedBox(height: 16),
        if (_selectedImages.isNotEmpty) ...[
          Text('已选图片（${_selectedImages.length} 张）', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.grey.shade700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _selectedImages.map((img) => Stack(
              alignment: Alignment.topRight,
              children: [
                Image.network(Api.resolveUrl(img['url']!), width: 90, height: 90, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
                GestureDetector(
                  onTap: () => setState(() => _selectedImages.remove(img)),
                  child: const Icon(Icons.cancel, color: Colors.red),
                ),
              ],
            )).toList(),
          ),
          const SizedBox(height: 16),
        ],
        Text('搜索结果（点击使用）', style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          children: _imgResults.map((img) => GestureDetector(
            onTap: () => _pickImage(img),
            child: Image.network(Api.resolveUrl(img['thumb'] ?? img['url'] ?? ''), fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.image)),
          )).toList(),
        ),
      ],
    );
  }

  Widget _buildStep4() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          value: _themes.isEmpty ? null : _theme,
          decoration: const InputDecoration(labelText: '配色方案', border: OutlineInputBorder(), isDense: true),
          items: _themes.map((t) => DropdownMenuItem<String>(value: t['key'] as String, child: Text(t['name'] as String))).toList(),
          onChanged: (v) => setState(() => _theme = v ?? 'default'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          value: _tone,
          decoration: const InputDecoration(labelText: '语气', border: OutlineInputBorder(), isDense: true),
          items: const [
            DropdownMenuItem(value: '', child: Text('保持不变')),
            DropdownMenuItem(value: '正式专业', child: Text('正式专业')),
            DropdownMenuItem(value: '轻松活泼', child: Text('轻松活泼')),
            DropdownMenuItem(value: '温暖治愈', child: Text('温暖治愈')),
            DropdownMenuItem(value: '犀利观点', child: Text('犀利观点')),
          ],
          onChanged: (v) => setState(() => _tone = v ?? ''),
        ),
        const SizedBox(height: 8),
        SwitchListTile(title: const Text('智能排版润色'), value: _polish, onChanged: (v) => setState(() => _polish = v), contentPadding: EdgeInsets.zero),
        CheckboxListTile(title: const Text('加导语摘要'), value: _addSummary, onChanged: (v) => setState(() => _addSummary = v ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('提炼金句'), value: _addGolden, onChanged: (v) => setState(() => _addGolden = v ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        CheckboxListTile(title: const Text('结尾引导关注'), value: _addFollow, onChanged: (v) => setState(() => _addFollow = v ?? false), contentPadding: EdgeInsets.zero, controlAffinity: ListTileControlAffinity.leading),
        const SizedBox(height: 8),
        FilledButton(onPressed: _format, child: const Text('格式优化')),
        const SizedBox(height: 12),
        _contentEditorOrPreview(_result, '结果（Markdown）', maxLines: 8),
        const SizedBox(height: 12),
        Row(
          children: [
            OutlinedButton.icon(onPressed: _pickCover, icon: const Icon(Icons.image), label: Text(_coverPath == null ? '选封面图' : '已选封面')),
            const SizedBox(width: 8),
            if (_coverPath != null) Expanded(child: Text('已选：${_coverPath!.split('/').last}', style: TextStyle(fontSize: 12, color: Colors.grey.shade600))),
          ],
        ),
      ],
    );
  }

  Widget _stepNav() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(child: OutlinedButton(onPressed: () => setState(() => _step -= 1), child: const Text('上一步'))),
              const SizedBox(width: 12),
            ],
            if (_step == 3)
              Expanded(child: OutlinedButton(onPressed: _saveOnly, child: const Text('保存到本地库'))),
            if (_step == 3) const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: () { _step < 3 ? setState(() => _step += 1) : _push(); },
                child: Text(_step < 3 ? '下一步' : '推送到草稿箱'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
