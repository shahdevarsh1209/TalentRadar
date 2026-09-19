import 'package:flutter/material.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';

/// Screen shell for the onboarding flow.
///
/// It solves the keyboard problem once: the body scrolls, the sticky footer
/// rides above the keyboard, and nothing the user is typing into can end up
/// hidden behind it.
class TrScaffold extends StatelessWidget {
  const TrScaffold({
    super.key,
    required this.child,
    this.title,
    this.subtitle,
    this.onBack,
    this.footer,
    this.header,
    this.backgroundColor = TrColors.canvas,
    this.padding = const EdgeInsets.fromLTRB(22, 4, 22, 26),
    this.showBack = true,
    this.trailing,
  });

  final Widget child;
  final String? title;
  final String? subtitle;

  /// Called instead of popping, so a screen can warn before losing a draft.
  final VoidCallback? onBack;
  final Widget? footer;

  /// Sits under the app bar and above the scroll area (progress bar, tabs).
  final Widget? header;
  final Color backgroundColor;
  final EdgeInsets padding;
  final bool showBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final bool canPop = Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: backgroundColor,
      // The footer is positioned manually so it tracks the keyboard.
      resizeToAvoidBottomInset: true,
      appBar: (showBack && (canPop || onBack != null)) || trailing != null
          ? AppBar(
              backgroundColor: backgroundColor,
              leading: showBack && (canPop || onBack != null)
                  ? IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
                      tooltip: 'Back',
                      onPressed: onBack ?? () => Navigator.of(context).maybePop(),
                    )
                  : null,
              actions: trailing == null
                  ? null
                  : [Padding(padding: const EdgeInsets.only(right: 12), child: trailing!)],
            )
          : null,
      body: SafeArea(
        top: false,
        child: Column(
          children: [
            if (header != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 0, 22, 14),
                child: header!,
              ),
            Expanded(
              child: CustomScrollView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                slivers: [
                  SliverPadding(
                    padding: padding,
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        if (title != null) ...[
                          Text(title!, style: TrType.screenTitle),
                          const SizedBox(height: 8),
                        ],
                        if (subtitle != null) ...[
                          Text(subtitle!, style: TrType.bodyLarge.copyWith(fontSize: 14.5)),
                          const SizedBox(height: 22),
                        ],
                        child,
                      ]),
                    ),
                  ),
                ],
              ),
            ),
            if (footer != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                decoration: BoxDecoration(
                  color: backgroundColor,
                  border: const Border(top: BorderSide(color: TrColors.border)),
                ),
                child: footer!,
              ),
          ],
        ),
      ),
    );
  }
}

/// Small headed group of fields inside a form.
class FormSection extends StatelessWidget {
  const FormSection({super.key, required this.label, required this.children, this.note});

  final String label;
  final List<Widget> children;
  final String? note;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: TrType.eyebrow),
        if (note != null) ...[
          const SizedBox(height: 5),
          Text(note!, style: TrType.itemMeta.copyWith(fontSize: 11.5)),
        ],
        const SizedBox(height: 14),
        ...children,
      ],
    );
  }
}

/// Rounded white container used for grouped content across the app.
class TrCard extends StatelessWidget {
  const TrCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = TrColors.card,
    this.borderColor,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: TrRadius.cardR,
        border: borderColor != null ? Border.all(color: borderColor!) : null,
        boxShadow: borderColor == null ? TrColors.cardShadow : null,
      ),
      child: child,
    );
  }
}
