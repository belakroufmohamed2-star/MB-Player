import 'dart:convert';

import 'package:chewie/chewie.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';

const _accent = Color(0xFFE50914);
const _background = Color(0xFF101010);

void main() => runApp(const MBPlayerApp());

class MBPlayerApp extends StatelessWidget {
  const MBPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MB-Player',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true).copyWith(
        scaffoldBackgroundColor: _background,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _accent,
          brightness: Brightness.dark,
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: const Color(0xFF1D1D1D),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _server = TextEditingController();
  final _username = TextEditingController();
  final _password = TextEditingController();
  final _playlist = TextEditingController();
  int _mode = 0;
  bool _loading = false;
  bool _hidePassword = true;

  @override
  void dispose() {
    _server.dispose();
    _username.dispose();
    _password.dispose();
    _playlist.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      if (_mode == 0) {
        final server = _normaliseServer(_server.text);
        final user = _username.text.trim();
        final pass = _password.text.trim();
        final uri = Uri.parse('$server/player_api.php').replace(
          queryParameters: {'username': user, 'password': pass},
        );
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        final data = jsonDecode(response.body);
        final active = response.statusCode == 200 &&
            data is Map &&
            data['user_info'] is Map &&
            data['user_info']['status'].toString().toLowerCase() == 'active';
        if (!active) throw Exception('بيانات الدخول غير صحيحة أو الحساب غير مفعّل');
        if (!mounted) return;
        _openHome(serverUrl: server, username: user, password: pass, xtream: true);
      } else {
        final uri = Uri.parse(_playlist.text.trim());
        final response = await http.get(uri).timeout(const Duration(seconds: 15));
        if (response.statusCode != 200) throw Exception('تعذر تحميل قائمة M3U');
        if (!mounted) return;
        _openHome(m3u: response.body, xtream: false);
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  String _normaliseServer(String value) {
    var result = value.trim();
    if (!result.startsWith('http://') && !result.startsWith('https://')) {
      result = 'http://$result';
    }
    return result.replaceFirst(RegExp(r'/*$'), '');
  }

  void _openHome({String? serverUrl, String? username, String? password, String? m3u, required bool xtream}) {
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => HomeScreen(
          serverUrl: serverUrl,
          username: username,
          password: password,
          m3uContent: m3u,
          isXtream: xtream,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const Icon(Icons.live_tv_rounded, color: _accent, size: 76),
                    const SizedBox(height: 12),
                    const Text('MB-PLAYER', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 8),
                    Text('شاهد قنواتك المفضلة في مكان واحد', style: TextStyle(color: Colors.grey.shade400)),
                    const SizedBox(height: 32),
                    SegmentedButton<int>(
                      segments: const [
                        ButtonSegment(value: 0, label: Text('Xtream API'), icon: Icon(Icons.dns_outlined)),
                        ButtonSegment(value: 1, label: Text('رابط M3U'), icon: Icon(Icons.link)),
                      ],
                      selected: {_mode},
                      onSelectionChanged: (value) => setState(() => _mode = value.first),
                    ),
                    const SizedBox(height: 24),
                    if (_mode == 0) ...[
                      _field(_server, 'رابط السيرفر', Icons.dns_outlined, 'مثال: http://example.com:8080'),
                      const SizedBox(height: 14),
                      _field(_username, 'اسم المستخدم', Icons.person_outline),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _password,
                        obscureText: _hidePassword,
                        validator: _required,
                        decoration: InputDecoration(
                          labelText: 'كلمة المرور',
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _hidePassword = !_hidePassword),
                            icon: Icon(_hidePassword ? Icons.visibility : Icons.visibility_off),
                          ),
                        ),
                      ),
                    ] else
                      _field(_playlist, 'رابط قائمة M3U', Icons.link, 'https://example.com/playlist.m3u'),
                    const SizedBox(height: 26),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _loading ? null : _connect,
                        icon: _loading ? const SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.login),
                        label: Text(_loading ? 'جارٍ الاتصال...' : 'اتصال'),
                        style: FilledButton.styleFrom(backgroundColor: _accent),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _field(TextEditingController controller, String label, IconData icon, [String? hint]) {
    return TextFormField(controller: controller, validator: _required, decoration: InputDecoration(labelText: label, hintText: hint, prefixIcon: Icon(icon)));
  }

  String? _required(String? value) => value == null || value.trim().isEmpty ? 'هذا الحقل مطلوب' : null;
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, this.serverUrl, this.username, this.password, this.m3uContent, required this.isXtream});
  final String? serverUrl, username, password, m3uContent;
  final bool isXtream;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Map<String, dynamic>> _channels = [];
  List<Map<String, dynamic>> _categories = [];
  String? _category;
  String _search = '';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      if (widget.isXtream) {
        final base = Uri.parse('${widget.serverUrl}/player_api.php');
        Uri request(String action) => base.replace(queryParameters: {'username': widget.username!, 'password': widget.password!, 'action': action});
        final responses = await Future.wait([http.get(request('get_live_categories')), http.get(request('get_live_streams'))]);
        final categories = jsonDecode(responses[0].body);
        final streams = jsonDecode(responses[1].body);
        _categories = (categories is List ? categories : []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        _channels = (streams is List ? streams : []).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
      } else {
        _channels = _parseM3u(widget.m3uContent ?? '');
      }
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تعذر تحميل القنوات')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _parseM3u(String content) {
    final result = <Map<String, dynamic>>[];
    String name = 'قناة بدون اسم';
    String icon = '';
    for (final raw in content.split(RegExp(r'\r?\n'))) {
      final line = raw.trim();
      if (line.startsWith('#EXTINF:')) {
        name = RegExp(r',(.+)$').firstMatch(line)?.group(1)?.trim() ?? name;
        icon = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line)?.group(1) ?? '';
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        result.add({'name': name, 'stream_icon': icon, 'url': line});
        name = 'قناة بدون اسم';
        icon = '';
      }
    }
    return result;
  }

  List<Map<String, dynamic>> get _visibleChannels => _channels.where((channel) {
        final matchesCategory = _category == null || channel['category_id']?.toString() == _category;
        final name = (channel['name'] ?? '').toString().toLowerCase();
        return matchesCategory && name.contains(_search.toLowerCase());
      }).toList();

  String _url(Map<String, dynamic> channel) => widget.isXtream
      ? '${widget.serverUrl}/live/${widget.username}/${widget.password}/${channel['stream_id']}.m3u8'
      : (channel['url'] ?? '').toString();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MB-PLAYER', style: TextStyle(fontWeight: FontWeight.w800, color: _accent)),
        actions: [IconButton(tooltip: 'تسجيل الخروج', onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LoginScreen())), icon: const Icon(Icons.logout))],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: _accent))
          : Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(16, 8, 16, 12), child: TextField(onChanged: (value) => setState(() => _search = value), decoration: const InputDecoration(hintText: 'ابحث عن قناة...', prefixIcon: Icon(Icons.search)))),
              if (widget.isXtream && _categories.isNotEmpty) SizedBox(height: 42, child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 12), children: [
                _chip('الكل', null),
                ..._categories.map((item) => _chip(item['category_name']?.toString() ?? 'قسم', item['category_id']?.toString())),
              ])),
              const SizedBox(height: 8),
              Expanded(child: _visibleChannels.isEmpty ? const Center(child: Text('لا توجد قنوات متاحة')) : GridView.builder(padding: const EdgeInsets.all(12), gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(maxCrossAxisExtent: 180, childAspectRatio: .82, crossAxisSpacing: 10, mainAxisSpacing: 10), itemCount: _visibleChannels.length, itemBuilder: (_, index) => _channelCard(_visibleChannels[index]))),
            ]),
    );
  }

  Widget _chip(String label, String? value) => Padding(padding: const EdgeInsets.symmetric(horizontal: 4), child: ChoiceChip(label: Text(label), selected: _category == value, onSelected: (_) => setState(() => _category = value)));

  Widget _channelCard(Map<String, dynamic> channel) {
    final name = channel['name']?.toString() ?? 'قناة';
    final icon = channel['stream_icon']?.toString() ?? '';
    return Card(color: const Color(0xFF1D1D1D), clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PlayerScreen(title: name, streamUrl: _url(channel)))), child: Column(children: [Expanded(child: Padding(padding: const EdgeInsets.all(12), child: icon.isEmpty ? const Icon(Icons.live_tv, size: 54, color: Colors.grey) : Image.network(icon, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.live_tv, size: 54, color: Colors.grey)))), Padding(padding: const EdgeInsets.all(8), child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center))]));
  }
}

class PlayerScreen extends StatefulWidget {
  const PlayerScreen({super.key, required this.title, required this.streamUrl});
  final String title, streamUrl;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  VideoPlayerController? _video;
  ChewieController? _chewie;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initialise();
  }

  Future<void> _initialise() async {
    try {
      final video = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await video.initialize();
      if (!mounted) return;
      _video = video;
      _chewie = ChewieController(videoPlayerController: video, autoPlay: true, isLive: true, aspectRatio: video.value.aspectRatio > 0 ? video.value.aspectRatio : 16 / 9);
      setState(() {});
    } catch (_) {
      if (mounted) setState(() => _error = 'تعذر تشغيل هذا البث');
    }
  }

  @override
  void dispose() {
    _chewie?.dispose();
    _video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(widget.title)), backgroundColor: Colors.black, body: Center(child: _error != null ? Text(_error!, style: const TextStyle(color: Colors.redAccent)) : _chewie != null ? Chewie(controller: _chewie!) : const CircularProgressIndicator(color: _accent)));
}
