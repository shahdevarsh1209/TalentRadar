import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import '../data/models/enums.dart';

/// Shared row used by every single- and multi-choice control below, so the
/// selected look, touch target and semantics are identical throughout the flow.
class OptionTile extends StatelessWidget {
  const OptionTile({
    super.key,
    required this.title,
    required this.selected,
    required this.onTap,
    this.subtitle,
    this.icon,
    this.multiSelect = false,
  });

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;

  /// Square marker for multi-select, round for single choice — the shape tells
  /// the user whether picking this one will drop their previous answer.
  final bool multiSelect;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: !multiSelect,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.inputR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          curve: Curves.easeOut,
          constraints: const BoxConstraints(minHeight: 56),
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: TrRadius.inputR,
            border: Border.all(
              color: selected ? TrColors.plumInk : TrColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: selected ? TrColors.plumSurface : TrColors.canvas,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 19, color: TrColors.plumInk),
                ),
                const SizedBox(width: 13),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                    if (subtitle != null) ...[
                      const SizedBox(height: 3),
                      Text(subtitle!, style: TrType.itemMeta),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _Marker(selected: selected, square: multiSelect),
            ],
          ),
        ),
      ),
    );
  }
}

class _Marker extends StatelessWidget {
  const _Marker({required this.selected, required this.square});

  final bool selected;
  final bool square;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 23,
      height: 23,
      decoration: BoxDecoration(
        shape: square ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: square ? BorderRadius.circular(7) : null,
        color: selected ? TrColors.plumInk : Colors.transparent,
        border: selected ? null : Border.all(color: TrColors.borderStrong, width: 1.5),
      ),
      child: selected
          ? const Icon(Icons.check_rounded, size: 15, color: TrColors.lime)
          : null,
    );
  }
}

/// Compact pill choice, used where options are short (experience bands).
class ChoicePill extends StatelessWidget {
  const ChoicePill({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.pillR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? TrColors.plumInk : TrColors.card,
            borderRadius: TrRadius.pillR,
            border: Border.all(color: selected ? TrColors.plumInk : TrColors.border),
          ),
          child: Text(
            label,
            style: TrType.chip.copyWith(
              fontSize: 13,
              color: selected ? Colors.white : TrColors.bodyMuted,
            ),
          ),
        ),
      ),
    );
  }
}

/// Experience band. Optional by design — "Fresher" is preselected so a first-job
/// candidate can move straight past it.
class ExperienceSelector extends StatelessWidget {
  const ExperienceSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final ExperienceLevel value;
  final ValueChanged<ExperienceLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Experience', style: TrType.label),
            const SizedBox(width: 7),
            Text('Optional', style: TrType.itemMeta.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final level in ExperienceLevel.values)
              ChoicePill(
                label: level.label,
                selected: level == value,
                onTap: () => onChanged(level),
              ),
          ],
        ),
      ],
    );
  }
}

/// Preferred work mode. Multi-select from the start, and Hybrid is a first-class
/// option rather than something bolted on later.
class WorkModeSelector extends StatelessWidget {
  const WorkModeSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    this.label = 'Preferred Work Mode',
    this.isRequired = true,
    this.errorText,
    this.helper = 'Pick every mode that works for you.',
  });

  final List<WorkMode> selected;
  final ValueChanged<List<WorkMode>> onChanged;
  final String label;
  final bool isRequired;
  final String? errorText;
  final String helper;

  static const Map<WorkMode, IconData> _icons = {
    WorkMode.remote: Icons.laptop_mac_rounded,
    WorkMode.onsite: Icons.apartment_rounded,
    WorkMode.hybrid: Icons.sync_alt_rounded,
  };

  void _toggle(WorkMode mode) {
    final next = selected.contains(mode)
        ? selected.where((item) => item != mode).toList()
        : [...selected, mode];
    onChanged(next);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RichText(
          text: TextSpan(
            text: label,
            style: TrType.label,
            children: [
              if (isRequired)
                TextSpan(text: ' *', style: TrType.label.copyWith(color: TrColors.clay)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        for (final mode in WorkMode.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: OptionTile(
              title: mode.label,
              subtitle: mode.description,
              icon: _icons[mode],
              multiSelect: true,
              selected: selected.contains(mode),
              onTap: () => _toggle(mode),
            ),
          ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            errorText ?? helper,
            style: TrType.itemMeta.copyWith(
              fontSize: 11.5,
              color: errorText != null ? TrColors.error : TrColors.icon,
            ),
          ),
        ),
      ],
    );
  }
}

/// Open-to-work status. Feeds stealth mode: "Not looking currently" keeps the
/// candidate out of recruiter discovery.
class OpenToWorkSelector extends StatelessWidget {
  const OpenToWorkSelector({super.key, required this.value, required this.onChanged});

  final OpenToWork value;
  final ValueChanged<OpenToWork> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Open to Work', style: TrType.label),
            const SizedBox(width: 7),
            Text('Optional', style: TrType.itemMeta.copyWith(fontSize: 11)),
          ],
        ),
        const SizedBox(height: 10),
        for (final status in OpenToWork.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: OptionTile(
              title: status.label,
              subtitle: status.description,
              selected: status == value,
              onTap: () => onChanged(status),
            ),
          ),
        if (value == OpenToWork.notLooking)
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: TrColors.plumSurface,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.shield_outlined, size: 17, color: TrColors.plumInk),
                const SizedBox(width: 9),
                Expanded(
                  child: Text(
                    'Ninja mode will be switched on, so recruiters will not see you as available. You can change this any time.',
                    style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.45),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Who can discover this profile. Defaults to "Recruiters only" — the
/// privacy-conscious choice that still lets the product work.
class VisibilitySelector extends StatelessWidget {
  const VisibilitySelector({super.key, required this.value, required this.onChanged});

  final ProfileVisibility value;
  final ValueChanged<ProfileVisibility> onChanged;

  static const Map<ProfileVisibility, IconData> _icons = {
    ProfileVisibility.everyone: Icons.public_rounded,
    ProfileVisibility.recruitersOnly: Icons.work_outline_rounded,
    ProfileVisibility.connectionsOnly: Icons.people_alt_outlined,
    ProfileVisibility.private: Icons.lock_outline_rounded,
  };

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Profile Visibility', style: TrType.label),
        const SizedBox(height: 4),
        Text(
          'You control who can discover your professional profile.',
          style: TrType.itemMeta.copyWith(fontSize: 11.5),
        ),
        const SizedBox(height: 10),
        for (final visibility in ProfileVisibility.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: OptionTile(
              title: visibility.label,
              subtitle: visibility.description,
              icon: _icons[visibility],
              selected: visibility == value,
              onTap: () => onChanged(visibility),
            ),
          ),
      ],
    );
  }
}
