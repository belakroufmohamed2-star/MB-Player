import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:video_player/video_player.dart';
import 'package:chewie/chewie.dart';

void main() {
  runApp(const MBPlayerApp());
}

class MBPlayerApp extends StatelessWidget {
  const MBPlayerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MB-Player IPTV',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF141414),
        primaryColor: const Color(0xFFE50914),
        appBarTheme: const AppBarTheme(
          backgroundColor: Color(0xFF141414),
          elevation: 0,
        ),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFE50914),
          secondary: Color(0xFFE50914),
        ),
      ),
      home: const LoginScreen(),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. شاشة تسجيل الدخول (Xtream Codes API & M3U Playlist)
// ---------------------------------------------------------------------------
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State createState() => _LoginScreenState();
}

class _LoginScreenState extends State {
  final _formKey = GlobalKey();
  
  // 0 = Xtream Codes API, 1 = M3U URL
  int _loginType = 0;

  final TextEditingController _serverController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _m3uController = TextEditingController();

  bool _isLoading = false;

  Future _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      if (_loginType == 0) {
        // Xtream Codes
        String server = _serverController.text.trim();
        if (!server.startsWith('http://') && !server.startsWith('https://')) {
          server = 'http://$server';
        }
        if (server.endsWith('/')) {
          server = server.substring(0, server.length - 1);
        }

        final username = _usernameController.text.trim();
        final password = _passwordController.text.trim();

        final authUrl = '\(server/player_api.php?username=\)username&password=$password';
        final response = await http.get(Uri.parse(authUrl)).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['user_info'] != null && data['user_info']['status'] == 'Active') {
            if (!mounted) return;
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => HomeScreen(
                  serverUrl: server,
                  username: username,
                  password: password,
                  isXtream: true,
                ),
              ),
            );
          } else {
            _showError('بيانات الدخول غير صحيحة أو الحساب غير مفعّل');
          }
        } else {
          _showError('فشل الاتصال بالسيرفر. رمز الاستجابة: ${response.statusCode}');
        }
      } else {
        // M3U URL
        final m3uUrl = _m3uController.text.trim();
        final response = await http.get(Uri.parse(m3uUrl)).timeout(const Duration(seconds: 15));

        if (response.statusCode == 200) {
          if (!mounted) return;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                m3uContent: response.body,
                isXtream: false,
              ),
            ),
          );
        } else {
          _showError('تعذر جلب قائمة M3U من الرابط');
        }
      }
    } catch (e) {
      _showError('حدث خطأ أثناء الاتصال بالخادم: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.redAccent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.tv_rounded,
                  size: 80,
                  color: Color(0xFFE50914),
                ),
                const SizedBox(height: 12),
                const Text(
                  'MB-Player IPTV',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 24),

                SegmentedButton(
                  segments: const [
                    ButtonSegment(value: 0, label: Text('Xtream API')),
                    ButtonSegment(value: 1, label: Text('رابط M3U')),
                  ],
                  selected: {_loginType},
                  onSelectionChanged: (Set newSelection) {
                    setState(() {
                      _loginType = newSelection.first;
                    });
                  },
                ),
                const SizedBox(height: 24),

                if (_loginType == 0) ...[
                  TextFormField(
                    controller: _serverController,
                    decoration: const InputDecoration(
                      labelText: 'رابط السيرفر (Server URL)',
                      hintText: 'http://example.com:8080',
                      prefixIcon: Icon(Icons.dns),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال رابط السيرفر' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _usernameController,
                    decoration: const InputDecoration(
                      labelText: 'اسم المستخدم (Username)',
                      prefixIcon: Icon(Icons.person),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال اسم المستخدم' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'كلمة المرور (Password)',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال كلمة المرور' : null,
                  ),
                ] else ...[
                  TextFormField(
                    controller: _m3uController,
                    decoration: const InputDecoration(
                      labelText: 'رابط M3U Playlist',
                      hintText: 'http://example.com/playlist.m3u',
                      prefixIcon: Icon(Icons.link),
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v == null || v.isEmpty ? 'يرجى إدخال رابط القائمة' : null,
                  ),
                ],

                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFFE50914),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            'تسجيل الدخول',
                            style: TextStyle(fontSize: 18, color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 2. الشاشة الرئيسية عرض القنوات والتصنيفات
// ---------------------------------------------------------------------------
class HomeScreen extends StatefulWidget {
  final String? serverUrl;
  final String? username;
  final String? password;
  final String? m3uContent;
  final bool isXtream;

  const HomeScreen({
    super.key,
    this.serverUrl,
    this.username,
    this.password,
    this.m3uContent,
    required this.isXtream,
  });

  @override
  State createState() => _HomeScreenState();
}

class _HomeScreenState extends State {
  bool _isLoading = true;
  List _categories = [];
  List _allStreams = [];
  List _filteredStreams = [];
  String? _selectedCategoryId;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future _loadData() async {
    if (widget.isXtream) {
      await _loadXtreamData();
    } else {
      _parseM3uData();
    }
  }

  Future _loadXtreamData() async {
    try {
      final catUrl = '\({widget.serverUrl}/player_api.php?username=\){widget.username}&password=${widget.password}&action=get_live_categories';
      final streamsUrl = '\({widget.serverUrl}/player_api.php?username=\){widget.username}&password=${widget.password}&action=get_live_streams';

      final catResponse = await http.get(Uri.parse(catUrl));
      final streamsResponse = await http.get(Uri.parse(streamsUrl));

      if (catResponse.statusCode == 200 && streamsResponse.statusCode == 200) {
        final catData = json.decode(catResponse.body);
        final streamsData = json.decode(streamsResponse.body);

        setState(() {
          _categories = catData is List ? catData : [];
          _allStreams = streamsData is List ? streamsData : [];
          _filteredStreams = _allStreams;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _parseM3uData() {
    if (widget.m3uContent == null) return;
    final lines = widget.m3uContent!.split('\n');
    List> streams = [];

    String currentName = 'قناة بدون اسم';
    String currentIcon = '';

    for (var line in lines) {
      line = line.trim();
      if (line.startsWith('#EXTINF:')) {
        final nameMatch = RegExp(r',(.+)$').firstMatch(line);
        if (nameMatch != null) {
          currentName = nameMatch.group(1)?.trim() ?? 'قناة';
        }
        final logoMatch = RegExp(r'tvg-logo="([^"]+)"').firstMatch(line);
        if (logoMatch != null) {
          currentIcon = logoMatch.group(1) ?? '';
        }
      } else if (line.isNotEmpty && !line.startsWith('#')) {
        streams.add({
          'name': currentName,
          'stream_icon': currentIcon,
          'url': line,
        });
        currentName = 'قناة بدون اسم';
        currentIcon = '';
      }
    }

    setState(() {
      _allStreams = streams;
      _filteredStreams = streams;
      _isLoading = false;
    });
  }

  void _filterStreams() {
    setState(() {
      _filteredStreams = _allStreams.where((stream) {
        bool matchesCategory = true;
        if (widget.isXtream && _selectedCategoryId != null) {
          matchesCategory = stream['category_id'].toString() == _selectedCategoryId;
        }

        final name = (stream['name'] ?? '').toString().toLowerCase();
        bool matchesSearch = _searchQuery.isEmpty || name.contains(_searchQuery.toLowerCase());

        return matchesCategory && matchesSearch;
      }).toList();
    });
  }

  String _getStreamUrl(dynamic stream) {
    if (widget.isXtream) {
      final streamId = stream['stream_id'];
      return '\({widget.serverUrl}/live/\){widget.username}/\({widget.password}/\)streamId.m3u8';
    } else {
      return stream['url'] ?? '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('MB-Player', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFE50914))),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const LoginScreen()),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFE50914)))
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'بحث عن قناة...',
                      prefixIcon: const Icon(Icons.search, color: Colors.grey),
                      filled: true,
                      fillColor: Colors.grey[900],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (value) {
                      _searchQuery = value;
                      _filterStreams();
                    },
                  ),
                ),

                if (widget.isXtream && _categories.isNotEmpty)
                  SizedBox(
                    height: 45,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      itemCount: _categories.length + 1,
                      itemBuilder: (context, index) {
                        if (index == 0) {
                          final isSelected = _selectedCategoryId == null;
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4),
                            child: ChoiceChip(
                              label: const Text('الكل'),
                              selected: isSelected,
                              onSelected: (selected) {
                                setState(() {
                                  _selectedCategoryId = null;
                                  _filterStreams();
                                });
                              },
                            ),
                          );
                        }
                        final category = _categories[index - 1];
                        final categoryId = category['category_id'].toString();
                        final isSelected = _selectedCategoryId == categoryId;

                        return Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: ChoiceChip(
                            label: Text(category['category_name'] ?? 'قسم'),
                            selected: isSelected,
                            onSelected: (selected) {
                              setState(() {
                                _selectedCategoryId = selected ? categoryId : null;
                                _filterStreams();
                              });
                            },
                          ),
                        );
                      },
                    ),
                  ),

                const SizedBox(height: 10),

                Expanded(
                  child: _filteredStreams.isEmpty
                      ? const Center(child: Text('لا توجد قنوات متاحة', style: TextStyle(color: Colors.grey)))
                      : GridView.builder(
                          padding: const EdgeInsets.all(12),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 0.8,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                          itemCount: _filteredStreams.length,
                          itemBuilder: (context, index) {
                            final stream = _filteredStreams[index];
                            final iconUrl = stream['stream_icon'] ?? '';
                            final name = stream['name'] ?? 'قناة';

                            return GestureDetector(
                              onTap: () {
                                final url = _getStreamUrl(stream);
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => PlayerScreen(
                                      streamUrl: url,
                                      title: name,
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                decoration: BoxDecoration(
                                  color: Colors.grey[900],
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: Colors.white12),
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: iconUrl.isNotEmpty
                                            ? Image.network(
                                                iconUrl,
                                                fit: BoxFit.contain,
                                                errorBuilder: (c, o, s) => const Icon(Icons.tv, size: 40, color: Colors.grey),
                                              )
                                            : const Icon(Icons.tv, size: 40, color: Colors.grey),
                                      ),
                                    ),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 6.0),
                                      child: Text(
                                        name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// 3. مشغل الفيديو
// ---------------------------------------------------------------------------
class PlayerScreen extends StatefulWidget {
  final String streamUrl;
  final String title;

  const PlayerScreen({
    super.key,
    required this.streamUrl,
    required this.title,
  });

  @override
  State createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State {
  late VideoPlayerController _videoPlayerController;
  ChewieController? _chewieController;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _initPlayer();
  }

  Future _initPlayer() async {
    try {
      _videoPlayerController = VideoPlayerController.networkUrl(Uri.parse(widget.streamUrl));
      await _videoPlayerController.initialize();

      _chewieController = ChewieController(
        videoPlayerController: _videoPlayerController,
        autoPlay: true,
        looping: false,
        isLive: true,
        aspectRatio: _videoPlayerController.value.aspectRatio,
        errorBuilder: (context, errorMessage) {
          return Center(
            child: Text(
              'تعذر تشغيل البث المباشر:\n$errorMessage',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
          );
        },
      );
      setState(() {});
    } catch (e) {
      setState(() {
        _hasError = true;
      });
    }
  }

  @override
  void dispose() {
    _videoPlayerController.dispose();
    _chewieController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: Colors.black,
      ),
      body: Center(
        child: _hasError
            ? const Text(
                'خطأ في تحميل رابط البث المباشر',
                style: TextStyle(color: Colors.redAccent, fontSize: 16),
              )
            : _chewieController != null && _chewieController!.videoPlayerController.value.isInitialized
                ? Chewie(controller: _chewieController!)
                : const CircularProgressIndicator(color: Color(0xFFE50914)),
      ),
    );
  }
}
