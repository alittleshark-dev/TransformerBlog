import 'package:flutter/material.dart';

/// 分页控件，只有一页时不显示。
class PaginationBar extends StatelessWidget {
  const PaginationBar({
    super.key,
    required this.page,
    required this.pageCount,
    required this.onPageChanged,
  });

  final int page;
  final int pageCount;
  final ValueChanged<int> onPageChanged;

  @override
  Widget build(BuildContext context) {
    if (pageCount <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            onPressed: page > 1 ? () => onPageChanged(page - 1) : null,
            icon: const Icon(Icons.chevron_left),
            tooltip: '上一页',
          ),
          Text('$page / $pageCount'),
          IconButton(
            onPressed: page < pageCount ? () => onPageChanged(page + 1) : null,
            icon: const Icon(Icons.chevron_right),
            tooltip: '下一页',
          ),
        ],
      ),
    );
  }
}
