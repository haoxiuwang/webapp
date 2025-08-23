/// Parses SRT text into a list of subtitle objects with keys: text, start, end.
/// start/end are in seconds (double).
List<Map<String, dynamic>> parseSrt(String srtContent) {
  final regex = RegExp(
    r'(\d+)\s+(\d{2}:\d{2}:\d{2},\d{3}) --> (\d{2}:\d{2}:\d{2},\d{3})\s+([\s\S]*?)(?=\n\n|\n\r\n|\$)',
    multiLine: true,
  );

  final List<Map<String, dynamic>> out = [];
  for (final m in regex.allMatches(srtContent)) {
    final start = _timeToSeconds(m.group(2)!);
    final end = _timeToSeconds(m.group(3)!);
    final text = m.group(4)!.trim().replaceAll('\r', '');
    out.add({
      'text': text,
      'start': start,
      'end': end,
    });
  }
  return out;
}

double _timeToSeconds(String t) {
  // format: HH:MM:SS,mmm
  final parts = t.split(RegExp(r'[:,]'));
  final h = int.parse(parts[0]);
  final m = int.parse(parts[1]);
  final s = int.parse(parts[2]);
  final ms = int.parse(parts[3]);
  return h * 3600 + m * 60 + s + ms / 1000.0;
}
