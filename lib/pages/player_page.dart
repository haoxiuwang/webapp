import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../widgets/mylistview.dart';

class PlayerPage extends StatefulWidget {
  final Map<String, dynamic> song;
  const PlayerPage({super.key, required this.song});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage> {
  final AudioPlayer _player = AudioPlayer();
  final ScrollController _controller = ScrollController();
  List<dynamic> _subs = [];
  List<GlobalKey> _keys = [];
  int _activeIdx = -1;


  @override
  void initState() {
    super.initState();
    _init();
   
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
  void scrollToIndex(int index) {
    if (index < 0 || index >= _subs.length) return;
    final context = _keys[index].currentContext;
    if (context == null) return;

    Scrollable.ensureVisible(
      context,
      duration: const Duration(milliseconds: 400),
      alignment: 0.5, // <-- always keep item in the center
      curve: Curves.easeInOut,
    );
  }
  int _findSubtitleIndex(Duration d) {
    final t = d.inMilliseconds / 1000.0;
    return _subs.indexWhere((s) => t >= (s['start'] as double) && t <= (s['end'] as double));
  }


  Future<void> _init() async {
   
    await _player.setFilePath(widget.song['audioPath']);
    

    _subs = [];
    final raw = (widget.song['subtitles'] ?? '').toString();
    if (raw.isNotEmpty) {
      final list = jsonDecode(raw) as List;
      _subs = list
          .map((e) => {
                'text': e['text'],
                'start': (e['start'] as num).toDouble(),
                'end': (e['end'] as num).toDouble(),
              })
          .toList();
    }
    _keys = List.generate(_subs.length, (_) => GlobalKey());
    
    // Update active subtitle while playing
    _player.positionStream.listen((pos) {
      final t = pos.inMilliseconds / 1000.0; // seconds (double)
      final idx = _subs.indexWhere((s) => t >= (s['start'] as double) && t <= (s['end'] as double));
      if (idx != _activeIdx) {
        setState(() => _activeIdx = idx);
        scrollToIndex(_activeIdx);
      }
    });

    // Autoplay
    await _player.play();
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Widget _controls() {
    return StreamBuilder<PlayerState>(
      stream: _player.playerStateStream,
      builder: (context, snapshot) {
        final playing = snapshot.data?.playing ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.replay_10),
              onPressed: () async {
                final pos = await _player.position;
                final extra = const Duration(seconds: 10);
                _player.seek(pos > extra?pos - extra:Duration.zero);
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 48,
              icon: Icon(playing ? Icons.pause_circle_filled : Icons.play_circle_filled),
              onPressed: () async {
                if (playing) {
                  await _player.pause();
                } else {
                  await _player.play();
                }
              },
            ),
            const SizedBox(width: 8),
            IconButton(
              iconSize: 36,
              icon: const Icon(Icons.forward_10),
              onPressed: () async {
                final pos = await _player.position;
                
                _player.seek(pos + const Duration(seconds: 10));
              },
            ),
          ],
        );
      },
    );
  }

  Widget _positionBar() {
    return StreamBuilder<Duration>(
      stream: _player.positionStream,
      builder: (context, snap) {
        final pos = snap.data ?? Duration.zero;
        final dur = _player.duration ?? Duration.zero;
        return Column(
          children: [
            Slider(
              value: pos.inMilliseconds.toDouble().clamp(0, dur.inMilliseconds.toDouble()),
              max: dur.inMilliseconds > 0 ? dur.inMilliseconds.toDouble() : 1,
              onChanged: (value) {
                // only seek, don’t scroll yet
                // print(value);
                final seekPos = Duration(milliseconds: value.toInt());
                // print(seekPos);
                
                // _player.seek(seekPos);
              },
              onChangeEnd: (value) {
                // after drag finished, scroll once to center active subtitle
               
                final seekPos = Duration(milliseconds: value.toInt());
                
                // final newIndex = _findSubtitleIndex(seekPos);
                
                _player.seek(const Duration(seconds: 2400));
                // if (newIndex != -1) {
                //   scrollToIndex(newIndex);
                // }
              },
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(_fmt(pos)),
                  Text(_fmt(dur)),
                ],
              ),
            )
          ],
        );
      },
    );
  }


  String _fmt(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    final h = d.inHours;
    final m = d.inMinutes % 60;
    final s = d.inSeconds % 60;
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  @override
  Widget build(BuildContext context) {
    final coverPath = (widget.song['coverPath'] ?? '').toString();

    return Scaffold(
      appBar: AppBar(title: Text(widget.song['title'] ?? 'Player')),
      body: Column(
        children: [
          const SizedBox(height: 12),
          if (coverPath.isNotEmpty && File(coverPath).existsSync())
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.file(
                File(coverPath),
                width: 220,
                height: 220,
                fit: BoxFit.cover,
              ),
            )
          else
            const Icon(Icons.album, size: 160),
          const SizedBox(height: 8),
          Text(
            widget.song['title'] ?? '',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          _controls(),
          _positionBar(),
          const Divider(height: 1),
          const SizedBox(height: 8),
          const Text('Subtitles', style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              controller: _controller,
              itemCount: _subs.length,
              itemBuilder: (context, index) {
                final s = _subs[index];
                final active = index == _activeIdx;
                return AnimatedContainer(
                  key: _keys[index],
                  duration: const Duration(milliseconds: 1200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: TextButton(
                    onPressed: (){                      
                      int x = (s["start"]*1000).round();
                      _player.seek(Duration(milliseconds: x));
                    },
                    child: Text(
                      s['text'] ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: active ? 20 : 16,
                        fontWeight: active ? FontWeight.bold : FontWeight.normal,
                        color: active ? Colors.blue : Colors.black,
                      )
                    )
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
