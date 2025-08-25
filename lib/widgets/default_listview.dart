import 'package:flutter/material.dart';

class DefaultListView extends StatefulWidget {
  final List<Map<String, String>> subs;
  final int initialActive;

  const MyListView({
    super.key,
    required this.subs,
    this.initialActive = 0,
  });

  @override
  State<MyListView> createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  final _scrollController = ScrollController();
  final _itemExtent = 60.0; // fixed height
  late int _activeIdx;

  @override
  void initState() {
    super.initState();
    _activeIdx = widget.initialActive;

    // Center the active item once UI is built
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerOnActive());
  }

  void _centerOnActive() {
    final screenHeight = MediaQuery.of(context).size.height;
    final offset =
        (_activeIdx * _itemExtent) - (screenHeight / 2) + (_itemExtent / 2);

    _scrollController.jumpTo(
      offset.clamp(0, _scrollController.position.maxScrollExtent),
    );
  }

  void _setActive(int index) {
    setState(() => _activeIdx = index);

    _scrollController.animateTo(
      (_activeIdx * _itemExtent) -
          (MediaQuery.of(context).size.height / 2) +
          (_itemExtent / 2),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    // show ±10 items around active
    final start = (_activeIdx - 10).clamp(0, widget.subs.length - 1);
    final end = (_activeIdx + 10).clamp(0, widget.subs.length - 1);

    final visibleItems = widget.subs.sublist(start, end + 1);

    return ListView.builder(
              itemCount: _subs.length,
              itemBuilder: (context, index) {
                final s = _subs[index];
                final active = index == _activeIdx;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    s['text'] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: active ? 20 : 16,
                      fontWeight: active ? FontWeight.bold : FontWeight.normal,
                      color: active ? Colors.blue : Colors.black,
                    ),
                  ),
                );
              },
            );
  }
}
