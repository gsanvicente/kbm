import 'package:flutter/material.dart';

/// Reusable "combo" multiselect filter: a compact button that opens a
/// checklist menu. Toggling an option never closes the menu — the user
/// can pick several before dismissing it (tap outside, or the button
/// again). Empty [selected] means "no restriction", never "show
/// nothing" — see docs/feature/pool-y-asignacion-de-tarjetas/README.md.
class MultiSelectFilterButton<T> extends StatelessWidget {
  const MultiSelectFilterButton({
    super.key,
    required this.label,
    required this.options,
    required this.optionLabel,
    required this.selected,
    required this.onChanged,
  });

  final String label;
  final List<T> options;
  final String Function(T option) optionLabel;
  final Set<T> selected;
  final ValueChanged<Set<T>> onChanged;

  void _toggle(T option, bool checked) {
    final next = Set<T>.from(selected);
    if (checked) {
      next.add(option);
    } else {
      next.remove(option);
    }
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return MenuAnchor(
      menuChildren: [
        ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 220, maxHeight: 320),
          child: SingleChildScrollView(
            // Without this, both this menu's scroll view and the list
            // underneath try to attach to the same PrimaryScrollController
            // (both are vertical with no explicit controller) — Flutter
            // then refuses to paint either Scrollbar.
            primary: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final option in options)
                  CheckboxListTile(
                    dense: true,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: selected.contains(option),
                    title: Text(optionLabel(option)),
                    onChanged: (checked) => _toggle(option, checked ?? false),
                  ),
              ],
            ),
          ),
        ),
      ],
      builder: (context, controller, child) {
        final count = selected.length;
        return OutlinedButton.icon(
          onPressed: () => controller.isOpen ? controller.close() : controller.open(),
          icon: const Icon(Icons.arrow_drop_down_rounded, size: 18),
          label: Text(count > 0 ? '$label ($count)' : label),
        );
      },
    );
  }
}
