import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import '../core/utils/formatters.dart';
import 'primary_cta.dart';

/// Round initials avatar with the optional lime "live" dot from the design.
class TrAvatar extends StatelessWidget {
  const TrAvatar({
    super.key,
    required this.initials,
    required this.seed,
    this.size = 46,
    this.live = false,
    this.ringColor = Colors.white,
  });

  final String initials;
  final String seed;
  final double size;
  final bool live;
  final Color ringColor;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) = TrColors.tintFor(seed);
    return Semantics(
      label: live ? '$initials, available today' : initials,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(color: background, shape: BoxShape.circle),
            child: Text(
              initials,
              style: TrType.tag.copyWith(color: foreground, fontSize: size * 0.28),
            ),
          ),
          if (live)
            Positioned(
              right: -1,
              bottom: -1,
              child: Container(
                width: size * 0.3,
                height: size * 0.3,
                decoration: BoxDecoration(
                  color: TrColors.lime,
                  shape: BoxShape.circle,
                  border: Border.all(color: ringColor, width: 2.5),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Rounded-square company mark ("BRI") used on job cards.
class CompanyBadge extends StatelessWidget {
  const CompanyBadge({super.key, required this.name, this.size = 44, this.inverted = false});

  final String name;
  final double size;

  /// Lime on plum, for the highlighted row in the design's search list.
  final bool inverted;

  @override
  Widget build(BuildContext context) {
    final (background, foreground) =
        inverted ? (TrColors.lime, TrColors.plumInk) : TrColors.tintFor(name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(14)),
      child: Text(Fmt.companyCode(name), style: TrType.tag.copyWith(color: foreground, fontSize: 12)),
    );
  }
}

enum PillTone { neutral, live, alert, plum }

/// Small status pill: "Walk-in today", "0–2 yrs", "Closing soon".
class TrPill extends StatelessWidget {
  const TrPill({super.key, required this.label, this.tone = PillTone.neutral, this.icon});

  final String label;
  final PillTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = switch (tone) {
      PillTone.live => (TrColors.limeSurface, TrColors.limeText),
      PillTone.alert => (TrColors.claySurface, TrColors.clayText),
      PillTone.plum => (TrColors.plumSurface, TrColors.plumInk),
      PillTone.neutral => (TrColors.canvas, TrColors.bodyMuted),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(color: background, borderRadius: TrRadius.pillR),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[Icon(icon, size: 13, color: foreground), const SizedBox(width: 5)],
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: TrType.tag.copyWith(
                color: foreground,
                fontWeight: tone == PillTone.neutral ? FontWeight.w600 : FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Toggleable filter chip (plum when on), used in the chip rows.
class TrFilterChip extends StatelessWidget {
  const TrFilterChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.pillR,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 38),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            color: selected ? TrColors.plumInk : TrColors.card,
            borderRadius: TrRadius.pillR,
            border: selected ? null : Border.all(color: TrColors.border),
          ),
          child: Text(
            label,
            style: TrType.tag.copyWith(
              color: selected ? Colors.white : TrColors.bodyMuted,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

/// Horizontal chip row that scrolls rather than overflowing on small phones.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.children, this.padding = EdgeInsets.zero});

  final List<Widget> children;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: padding,
      child: Row(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(width: 7),
            children[i],
          ],
        ],
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({super.key, required this.title, this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Text(title, style: TrType.cardTitle.copyWith(fontSize: 16))),
        if (actionLabel != null)
          InkWell(
            onTap: onAction,
            borderRadius: TrRadius.pillR,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
              child: Text(actionLabel!, style: TrType.label),
            ),
          ),
      ],
    );
  }
}

/// Friendly nothing-here state with an optional next step.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 24, vertical: compact ? 18 : 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: const BoxDecoration(color: TrColors.plumSurface, shape: BoxShape.circle),
            child: Icon(icon, size: 26, color: TrColors.plumInk),
          ),
          const SizedBox(height: 14),
          Text(title, style: TrType.cardTitle, textAlign: TextAlign.center),
          const SizedBox(height: 6),
          Text(message, style: TrType.bodySmall, textAlign: TextAlign.center),
          if (actionLabel != null) ...[
            const SizedBox(height: 16),
            PrimaryCta(label: actionLabel!, onPressed: onAction, expand: false),
          ],
        ],
      ),
    );
  }
}

/// Renders the three states of an AsyncValue in the house style, so no screen
/// hand-rolls its own spinner or error copy. Data already on screen stays
/// visible while a refresh runs.
class AsyncSection<T> extends StatelessWidget {
  const AsyncSection({
    super.key,
    required this.value,
    required this.builder,
    required this.onRetry,
    this.loading,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final VoidCallback onRetry;
  final Widget? loading;

  @override
  Widget build(BuildContext context) {
    if (value.hasValue) return builder(value.requireValue);
    if (value.hasError) {
      final error = value.error;
      final offline = error is ApiException && error.isNetwork;
      return EmptyState(
        icon: offline ? Icons.wifi_off_rounded : Icons.cloud_off_rounded,
        title: offline ? 'You are offline' : 'Could not load this',
        message: errorText(error!),
        actionLabel: 'Try again',
        onAction: onRetry,
        compact: true,
      );
    }
    return loading ?? const LoadingCards();
  }
}

/// Placeholder cards while a list loads — steadier than a lone spinner.
class LoadingCards extends StatefulWidget {
  const LoadingCards({super.key, this.count = 3, this.height = 96});

  final int count;
  final double height;

  @override
  State<LoadingCards> createState() => _LoadingCardsState();
}

class _LoadingCardsState extends State<LoadingCards> with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Loading',
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.45, end: 1).animate(_pulse),
        child: Column(
          children: [
            for (var i = 0; i < widget.count; i++)
              Container(
                height: widget.height,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(color: TrColors.card, borderRadius: TrRadius.cardR),
              ),
          ],
        ),
      ),
    );
  }
}

/// The lime on/off switch from the Privacy screen.
class TrToggle extends StatelessWidget {
  const TrToggle({super.key, required this.value, required this.onChanged, this.label});

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      label: label,
      button: true,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 170),
          width: 48,
          height: 28,
          padding: const EdgeInsets.all(3),
          alignment: value ? Alignment.centerRight : Alignment.centerLeft,
          decoration: BoxDecoration(
            color: onChanged == null
                ? TrColors.border
                : (value ? TrColors.lime : TrColors.border),
            borderRadius: TrRadius.pillR,
          ),
          child: Container(
            width: 22,
            height: 22,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
          ),
        ),
      ),
    );
  }
}

/// Plum-surface note with an info icon ("Saved walk-ins send you a reminder…").
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.text, this.icon = Icons.info_outline_rounded});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: TrColors.plumSurface, borderRadius: BorderRadius.circular(20)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: TrColors.plumInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.45)),
          ),
        ],
      ),
    );
  }
}

void showTrSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Friendly copy for any error thrown from an action (save, send, post…).
String errorText(Object error) =>
    error is ApiException ? error.message : 'Something went wrong. Please try again.';
