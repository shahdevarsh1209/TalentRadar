import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/enums.dart';
import '../../data/models/session.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/tr_components.dart';

/// "Privacy & stealth mode" from the design. Every switch saves immediately and
/// rolls back on failure, so the screen always shows what the server holds.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _saving = false;

  Future<void> _update(Future<Session> Function() call, {String? confirmation}) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final session = await call();
      ref.read(sessionProvider.notifier).update(session);
      ref.refreshHome();
      if (mounted && confirmation != null) showTrSnack(context, confirmation);
    } catch (error) {
      if (mounted) showTrSnack(context, errorText(error));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(sessionProvider)?.candidate;
    final people = ref.read(peopleRepositoryProvider);

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Privacy')),
      body: profile == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              children: [
                // Stealth mode — the design's dark card.
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(color: TrColors.plumInk, borderRadius: BorderRadius.circular(24)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.shield_outlined, color: TrColors.lime, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Stealth mode',
                              style: TrType.cardTitle.copyWith(color: Colors.white),
                            ),
                          ),
                          TrToggle(
                            value: profile.stealthMode,
                            label: 'Stealth mode',
                            onChanged: _saving
                                ? null
                                : (value) => _update(
                                      () => people.updatePrivacy(stealthMode: value),
                                      confirmation: value
                                          ? 'Stealth mode on. Recruiters no longer see you on their radar.'
                                          : 'Stealth mode off. Recruiters nearby can discover you again.',
                                    ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        'Your exact location and open-to-work status stay hidden. Recruiters see only your area and skills.',
                        style: TrType.bodySmall.copyWith(color: Colors.white.withValues(alpha: 0.75), height: 1.55),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                  decoration: BoxDecoration(color: TrColors.card, borderRadius: BorderRadius.circular(24), boxShadow: TrColors.cardShadow),
                  child: Column(
                    children: [
                      _Row(
                        title: 'Profile visibility',
                        subtitle: 'Who sees your full profile',
                        trailing: _VisibilityPicker(
                          value: profile.profileVisibility,
                          onChanged: _saving
                              ? null
                              : (visibility) => _update(() => people.updatePrivacy(visibility: visibility)),
                        ),
                      ),
                      _Row(
                        title: 'Location detail',
                        subtitle: 'Area only, never an exact pin',
                        // Always on: exact location is never shared, so this is shown, not offered.
                        trailing: const TrToggle(value: true, onChanged: null, label: 'Area only, always on'),
                      ),
                      _Row(
                        title: 'Open to connect',
                        subtitle: 'Recruiters can message you and send requests',
                        trailing: TrToggle(
                          value: profile.openToConnect,
                          label: 'Open to connect',
                          onChanged: _saving ? null : (value) => _update(() => people.updatePrivacy(openToConnect: value)),
                        ),
                      ),
                      _Row(
                        title: 'Walk-in alerts',
                        subtitle: 'Reminders for walk-ins you saved',
                        last: true,
                        trailing: TrToggle(
                          value: profile.walkInAlerts,
                          label: 'Walk-in alerts',
                          onChanged: _saving ? null : (value) => _update(() => people.updatePrivacy(walkInAlerts: value)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                Text('OPEN TO WORK', style: TrType.eyebrow),
                const SizedBox(height: 10),
                for (final status in OpenToWork.values) ...[
                  OptionTile(
                    title: status.label,
                    subtitle: status.description,
                    selected: profile.openToWork == status,
                    onTap: () {
                      if (_saving || profile.openToWork == status) return;
                      _update(
                        () => people.updatePrivacy(openToWork: status),
                        confirmation: status == OpenToWork.notLooking
                            ? 'Stealth mode switched on — you will not show as available.'
                            : null,
                      );
                    },
                  ),
                  const SizedBox(height: 9),
                ],
                const SizedBox(height: 18),
                const InfoNote(
                  text: 'Whatever you choose, recruiters never see your exact location — only an approximate area and a rounded distance.',
                ),
              ],
            ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.title, required this.subtitle, required this.trailing, this.last = false});

  final String title;
  final String subtitle;
  final Widget trailing;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        border: last ? null : const Border(bottom: BorderSide(color: TrColors.pageCanvas)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TrType.itemTitle.copyWith(fontSize: 14)),
                const SizedBox(height: 3),
                Text(subtitle, style: TrType.itemMeta.copyWith(fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          trailing,
        ],
      ),
    );
  }
}

/// Compact visibility control. The design shows two segments; the product has
/// four options, so the current one is shown and tapping opens the full list.
class _VisibilityPicker extends StatelessWidget {
  const _VisibilityPicker({required this.value, required this.onChanged});

  final ProfileVisibility value;
  final ValueChanged<ProfileVisibility>? onChanged;

  Future<void> _open(BuildContext context) async {
    final choice = await showModalBottomSheet<ProfileVisibility>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 12),
          children: [
            for (final option in ProfileVisibility.values)
              ListTile(
                title: Text(option.label),
                subtitle: Text(option.description),
                trailing: option == value ? const Icon(Icons.check_rounded, color: TrColors.plumInk) : null,
                onTap: () => Navigator.of(sheetContext).pop(option),
              ),
          ],
        ),
      ),
    );
    if (choice != null && choice != value) onChanged?.call(choice);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Profile visibility: ${value.label}',
      child: InkWell(
        onTap: onChanged == null ? null : () => _open(context),
        borderRadius: TrRadius.pillR,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(color: TrColors.plumInk, borderRadius: TrRadius.pillR),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  value.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TrType.tag.copyWith(color: Colors.white, fontSize: 11),
                ),
              ),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more_rounded, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
