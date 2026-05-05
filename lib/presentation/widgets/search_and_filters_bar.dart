import 'package:flutter/material.dart';

import '../layout/responsive_content.dart';

/// Search field plus optional filter chips row.
class SearchAndFiltersBar extends StatelessWidget {
  const SearchAndFiltersBar({
    super.key,
    required this.controller,
    required this.hintText,
    this.onChanged,
    this.filterChips,
  });

  final TextEditingController controller;
  final String hintText;
  final ValueChanged<String>? onChanged;
  final List<Widget>? filterChips;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < Breakpoints.compact;
        final field = TextField(
          controller: controller,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: const Icon(Icons.search),
            border: const OutlineInputBorder(),
            isDense: true,
          ),
          onChanged: onChanged,
        );
        if (narrow) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              field,
              if (filterChips != null && filterChips!.isNotEmpty) ...[
                const SizedBox(height: 8),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: filterChips!),
                ),
              ],
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: field),
            if (filterChips != null && filterChips!.isNotEmpty) ...[
              const SizedBox(width: 12),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(children: filterChips!),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
