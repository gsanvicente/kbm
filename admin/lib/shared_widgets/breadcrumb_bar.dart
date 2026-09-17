import 'package:flutter/material.dart';

import '../app/theme.dart';

class BreadcrumbItem {
  final String label;
  final VoidCallback? onTap;
  const BreadcrumbItem(this.label, {this.onTap});
}

/// Shared by every drill-down section (Clientes → Tarjetahabientes →
/// detalle, and the global Tarjetahabientes list → detalle) so navigation
/// looks and behaves consistently across the app.
class BreadcrumbBar extends StatelessWidget {
  const BreadcrumbBar({super.key, required this.items});

  final List<BreadcrumbItem> items;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      final item = items[i];
      final isLast = i == items.length - 1;

      children.add(
        item.onTap != null
            ? InkWell(
                key: Key('breadcrumb-$i'),
                onTap: item.onTap,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                  child: Text(
                    item.label,
                    style: const TextStyle(color: KoonsColors.blue, fontWeight: FontWeight.w600),
                  ),
                ),
              )
            : Text(
                item.label,
                style: TextStyle(fontWeight: isLast ? FontWeight.w600 : FontWeight.w400),
              ),
      );

      if (!isLast) {
        children.add(Icon(Icons.chevron_right_rounded, size: 18, color: Colors.grey.shade500));
      }
    }
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: children),
    );
  }
}
