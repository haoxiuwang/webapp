import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../db_helper.dart';
import '../utils/srt_parser.dart';
import 'player_page.dart';

class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key});

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  List<Map<String, dynamic>> _songs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    final rows = await DBHelper.getSongs();
    setState(() => _songs = rows);
  }

  Future<void> _addFromFolder() async {
    setState(() => _loading = true);
    try {
      final dirPath = await FilePicker.platform.getDirectoryPath();
      if (dirPath == null) return; // user canceled

      final dir = Directory(dirPath);
      if (!await dir.exists()) {
        _snack('Directory not found');
        return;
      }

      // Find expected files
      File? audio; // .mp3 or .wav
      File? cover; // .jpg
      File? srt;   // .srt
      File? json;  // .json

      await for (final entity in dir.list(recursive: false, followLinks: false)) {
        if (entity is! File) continue;
        final path = entity.path.toLowerCase();
        if (path.endsWith('.mp3') || path.endsWith('.wav')) audio = entity;
        else if (path.endsWith('.jpg')) cover = entity;
        else if (path.endsWith('.srt')) srt = entity;
        else if (path.endsWith('.json')) json = entity;
      }

      if (audio == null || json == null) {
        _snack('Folder must contain an audio file and data.json');
        return;
      }

      // Parse metadata
      final metaMap = jsonDecode(await json!.readAsString());
      final String id = metaMap['id'].toString();
      final String title = metaMap['title']?.toString() ?? id;

      // Parse subtitles (optional)
      List<Map<String, dynamic>> subs = [];
      if (srt != null) {
        subs = parseSrt(await srt.readAsString());
      }

      // Prepare app-owned storage per track
      final appDoc = await getApplicationDocumentsDirectory();
      final trackDir = Directory(p.join(appDoc.path, id));
      if (!await trackDir.exists()) {
        await trackDir.create(recursive: true);
      }

      // Copy audio & cover into app storage
      final newAudioPath = p.join(trackDir.path, p.basename(audio!.path));
      await audio.copy(newAudioPath);

      String newCoverPath = '';
      if (cover != null) {
        newCoverPath = p.join(trackDir.path, p.basename(cover!.path));
        await cover!.copy(newCoverPath);
      }

      // Save into DB (subtitles as JSON array string)
      await DBHelper.upsertSong({
        'id': id,
        'title': title,
        'audioPath': newAudioPath,
        'coverPath': newCoverPath,
        'subtitles': jsonEncode(subs),
      });

      _snack('Imported: $title');
      await _refresh();
    } catch (e) {
      _snack('Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteTrack(Map<String, dynamic> song) async {
    final id = song['id'].toString();
    final audioPath = song['audioPath']?.toString() ?? '';
    final coverPath = song['coverPath']?.toString() ?? '';

    // Remove files and per-track folder if empty
    try {
      if (audioPath.isNotEmpty) {
        final f = File(audioPath);
        if (await f.exists()) await f.delete();
      }
      if (coverPath.isNotEmpty) {
        final f = File(coverPath);
        if (await f.exists()) await f.delete();
      }
      // Attempt deleting the folder
      final dir = Directory(File(audioPath).parent.path);
      if (await dir.exists()) {
        try { await dir.delete(recursive: true); } catch (_) {}
      }
    } catch (_) {}

    await DBHelper.deleteSong(id);
    await _refresh();
  }

  void _snack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Playlist'),
        actions: [
          IconButton(
            onPressed: _loading ? null : _addFromFolder,
            icon: const Icon(Icons.folder),
            tooltip: 'Import folder',
          ),
        ],
      ),
      body: _songs.isEmpty
          ? const Center(child: Text('No tracks. Tap the folder icon to import.'))
          : ListView.separated(
              itemCount: _songs.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                final s = _songs[index];
                final coverPath = (s['coverPath'] ?? '').toString();
                return ListTile(
                  leading: coverPath.isNotEmpty && File(coverPath).existsSync()
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: Image.file(
                            File(coverPath),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          ),
                        )
                      : const Icon(Icons.music_note, size: 36),
                  title: Text(s['title'] ?? ''),
                  subtitle: Text(s['id'] ?? ''),
                  onTap: () async {
                    if (!mounted) return;
                    await Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => PlayerPage(song: s)),
                    );
                  },
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => _deleteTrack(s),
                  ),
                );
              },
            ),
    );
  }
}
