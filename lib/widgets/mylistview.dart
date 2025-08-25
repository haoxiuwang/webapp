import 'package:flutter/material.dart';

class MyListView extends StatefulWidget {
  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final int activeIndex;

  const MyListView({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.activeIndex,
  });

  @override
  State<MyListView> createState() => _MyListViewState();
}

class _MyListViewState extends State<MyListView> {
  static const int windowSize = 10;
  static const double itemHeight = 60.0;

  @override
  Widget build(BuildContext context) {
    final start = (widget.activeIndex - windowSize).clamp(0, widget.itemCount);
    final end = (widget.activeIndex + windowSize).clamp(0, widget.itemCount);

    final visibleItems = <Widget>[];
    for (int i = start; i < end; i++) {
      visibleItems.add(
        SizedBox(
          height: itemHeight,
          child: widget.itemBuilder(context, i),
        ),
      );
    }

    final viewportHeight = (2 * windowSize + 1) * itemHeight;
    final activeOffset = (widget.activeIndex - start) * itemHeight;

    // padding so that active item is centered
    final topPadding = viewportHeight / 2 - activeOffset - itemHeight / 2;
    final bottomPadding =
        viewportHeight - topPadding - visibleItems.length * itemHeight;

    return SizedBox(
      height: viewportHeight,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: topPadding),
            ...visibleItems,
            SizedBox(height: bottomPadding),
          ],
        ),
      ),
    );
  }
}
