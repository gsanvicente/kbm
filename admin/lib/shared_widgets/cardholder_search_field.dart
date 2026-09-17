import 'package:flutter/material.dart';

import '../core/models/cardholder.dart';

/// Autocomplete search box for picking one Tarjetahabiente by name, used
/// as a filter facet in list screens. Selecting a suggestion sets the
/// filter to that exact person — free-typed text that never resolves to
/// a selection filters nothing on its own, by design (avoids ambiguous
/// partial-name matches). See
/// docs/feature/pool-y-asignacion-de-tarjetas/README.md.
class CardholderSearchField extends StatefulWidget {
  const CardholderSearchField({super.key, required this.candidates, required this.onChanged});

  final List<Cardholder> candidates;
  final ValueChanged<Cardholder?> onChanged;

  @override
  State<CardholderSearchField> createState() => _CardholderSearchFieldState();
}

class _CardholderSearchFieldState extends State<CardholderSearchField> {
  TextEditingController? _controller;

  void _attachListenerOnce(TextEditingController controller) {
    if (identical(_controller, controller)) return;
    _controller?.removeListener(_handleTextChanged);
    _controller = controller;
    _controller!.addListener(_handleTextChanged);
  }

  void _handleTextChanged() {
    if (_controller!.text.isEmpty) {
      widget.onChanged(null);
    }
  }

  @override
  void dispose() {
    _controller?.removeListener(_handleTextChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: Autocomplete<Cardholder>(
        displayStringForOption: (c) => c.fullName,
        optionsBuilder: (value) {
          final query = value.text.trim().toLowerCase();
          if (query.isEmpty) return const Iterable<Cardholder>.empty();
          return widget.candidates.where((c) => c.fullName.toLowerCase().contains(query));
        },
        onSelected: widget.onChanged,
        optionsViewBuilder: (context, onSelected, options) {
          final list = options.toList();
          return Align(
            alignment: Alignment.topLeft,
            child: Material(
              key: const Key('cardholder-search-options'),
              elevation: 4,
              borderRadius: BorderRadius.circular(10),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240, maxWidth: 260),
                child: ListView.builder(
                  // Avoids fighting the underlying list for the ambient
                  // PrimaryScrollController — same issue as
                  // MultiSelectFilterButton's menu content.
                  primary: false,
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final option = list[index];
                    return ListTile(
                      dense: true,
                      title: Text(option.fullName),
                      onTap: () => onSelected(option),
                    );
                  },
                ),
              ),
            ),
          );
        },
        fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
          _attachListenerOnce(controller);
          return TextField(
            controller: controller,
            focusNode: focusNode,
            decoration: InputDecoration(
              isDense: true,
              hintText: 'Buscar tarjetahabiente...',
              prefixIcon: const Icon(Icons.search_rounded, size: 20),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.close_rounded, size: 18),
                      onPressed: () {
                        controller.clear();
                        widget.onChanged(null);
                      },
                    ),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          );
        },
      ),
    );
  }
}
