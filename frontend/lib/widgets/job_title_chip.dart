import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';

/// A selected job title. Removable, with a touch target big enough to hit the
/// cross without fighting it.
class JobTitleChip extends StatelessWidget {
  const JobTitleChip({
    super.key,
    required this.label,
    required this.onRemove,
    this.category = '',
  });

  final String label;
  final String category;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label selected',
      child: Container(
        padding: const EdgeInsets.only(left: 14, right: 6, top: 6, bottom: 6),
        decoration: BoxDecoration(
          color: TrColors.plumInk,
          borderRadius: BorderRadius.circular(100),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: Text(
                label,
                style: TrType.chip.copyWith(color: Colors.white, fontSize: 13),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Semantics(
              button: true,
              label: 'Remove $label',
              child: InkWell(
                onTap: onRemove,
                customBorder: const CircleBorder(),
                child: Container(
                  width: 26,
                  height: 26,
                  alignment: Alignment.center,
                  child: const Icon(Icons.close_rounded, size: 15, color: TrColors.lime),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
