import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/home_providers.dart';
import '../../widgets/tr_components.dart';

/// Report and block, offered from the overflow menu on any profile.
///
/// A block hides both people from each other everywhere — search, radar, chat
/// and saved lists — because the server applies it in one place rather than
/// each screen filtering for itself.
Future<void> showSafetySheet(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  required String subjectKind,
  VoidCallback? onDone,
}) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    backgroundColor: TrColors.canvas,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
    ),
    builder: (sheetContext) => SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: TrColors.borderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.flag_outlined, color: TrColors.plumInk),
              title: Text('Report $name', style: TrType.itemTitle.copyWith(fontSize: 14.5)),
              subtitle: Text('Spam, a fake profile or a misleading role', style: TrType.itemMeta),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _report(context, ref, subjectId: userId, subjectKind: subjectKind, name: name);
              },
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.block_rounded, color: TrColors.clayText),
              title: Text(
                'Block $name',
                style: TrType.itemTitle.copyWith(fontSize: 14.5, color: TrColors.clayText),
              ),
              subtitle: Text(
                'You will not see each other anywhere on TalentRadar',
                style: TrType.itemMeta,
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                await _confirmBlock(context, ref, userId: userId, name: name, onDone: onDone);
              },
            ),
          ],
        ),
      ),
    ),
  );
}

Future<void> _confirmBlock(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
  VoidCallback? onDone,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      backgroundColor: TrColors.card,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Text('Block $name?', style: TrType.cardTitle),
      content: Text(
        'You will not appear in each other\'s search, radar or chats. '
        'Existing conversations stop. You can undo this in Privacy at any time.',
        style: TrType.bodySmall,
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: Text('Cancel', style: TrType.chip.copyWith(color: TrColors.bodyMuted)),
        ),
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: Text('Block', style: TrType.chip.copyWith(color: TrColors.clayText)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return;

  try {
    await ref.read(searchRepositoryProvider).setBlocked(userId, blocked: true);
    ref.refreshHome();
    ref.invalidate(blockedPeopleProvider);
    onDone?.call();
    if (context.mounted) {
      showTrSnack(context, '$name is blocked.');
      Navigator.of(context).maybePop();
    }
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}

const _reasons = <(String, String)>[
  ('spam', 'Spam or a scam'),
  ('fake_profile', 'Fake or impersonating profile'),
  ('misleading_job', 'Misleading job or salary'),
  ('harassment', 'Harassment or abuse'),
  ('other', 'Something else'),
];

Future<void> _report(
  BuildContext context,
  WidgetRef ref, {
  required String subjectId,
  required String subjectKind,
  required String name,
}) async {
  final controller = TextEditingController();
  String reason = _reasons.first.$1;

  final send = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        backgroundColor: TrColors.card,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Text('Report $name', style: TrType.cardTitle),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (value, label) in _reasons)
                InkWell(
                  onTap: () => setState(() => reason = value),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      children: [
                        Icon(
                          reason == value
                              ? Icons.radio_button_checked_rounded
                              : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: reason == value ? TrColors.plumInk : TrColors.icon,
                        ),
                        const SizedBox(width: 10),
                        Expanded(child: Text(label, style: TrType.bodySmall)),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              TextField(
                controller: controller,
                maxLines: 3,
                maxLength: 500,
                decoration: const InputDecoration(hintText: 'Anything else we should know?'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text('Cancel', style: TrType.chip.copyWith(color: TrColors.bodyMuted)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text('Send report', style: TrType.chip),
          ),
        ],
      ),
    ),
  );

  if (send != true || !context.mounted) return;
  try {
    await ref.read(searchRepositoryProvider).report(
          subjectKind: subjectKind,
          subjectId: subjectId,
          reason: reason,
          details: controller.text.trim(),
        );
    if (context.mounted) showTrSnack(context, 'Thanks — our team will review this.');
  } catch (error) {
    if (context.mounted) showTrSnack(context, errorText(error));
  }
}
