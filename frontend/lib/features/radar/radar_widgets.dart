import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../widgets/tr_components.dart';

/// Header from the design: eyebrow line, big title, avatar with live dot.
class RadarHeader extends StatelessWidget {
  const RadarHeader({
    super.key,
    required this.eyebrow,
    required this.title,
    required this.initials,
    required this.seed,
    this.live = false,
    this.onAvatarTap,
  });

  final String eyebrow;
  final String title;
  final String initials;
  final String seed;
  final bool live;
  final VoidCallback? onAvatarTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(eyebrow, style: TrType.itemMeta, maxLines: 1, overflow: TextOverflow.ellipsis),
              const SizedBox(height: 2),
              Text(title, style: TrType.screenTitle.copyWith(fontSize: 25)),
            ],
          ),
        ),
        GestureDetector(
          onTap: onAvatarTap,
          child: TrAvatar(initials: initials, seed: seed, size: 40, live: live, ringColor: TrColors.canvas),
        ),
      ],
    );
  }
}

/// Search pill that opens the search screen, plus the filter button.
class RadarSearchBar extends StatelessWidget {
  const RadarSearchBar({super.key, required this.hint, required this.onTap, this.onFilters});

  final String hint;
  final VoidCallback onTap;
  final VoidCallback? onFilters;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Semantics(
            button: true,
            label: 'Search: $hint',
            child: InkWell(
              onTap: onTap,
              borderRadius: TrRadius.pillR,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
                decoration: BoxDecoration(
                  color: TrColors.card,
                  borderRadius: TrRadius.pillR,
                  border: Border.all(color: TrColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search_rounded, size: 17, color: TrColors.icon),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Text(
                        hint,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TrType.bodySmall.copyWith(color: TrColors.icon),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 9),
        Semantics(
          button: true,
          label: 'Filters',
          child: InkWell(
            onTap: onFilters ?? onTap,
            customBorder: const CircleBorder(),
            child: Container(
              width: 46,
              height: 46,
              decoration: const BoxDecoration(color: TrColors.plumInk, shape: BoxShape.circle),
              child: const Icon(Icons.tune_rounded, size: 19, color: Colors.white),
            ),
          ),
        ),
      ],
    );
  }
}

class RadarBanner extends StatelessWidget {
  const RadarBanner({super.key, required this.icon, required this.text, this.actionLabel, this.onAction});

  final IconData icon;
  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(15, 10, 6, 10),
      decoration: BoxDecoration(color: TrColors.plumSurface, borderRadius: BorderRadius.circular(18)),
      child: Row(
        children: [
          Icon(icon, size: 18, color: TrColors.plumInk),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.4)),
          ),
          if (actionLabel != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!, style: TrType.chip.copyWith(color: TrColors.plumInk)),
            ),
        ],
      ),
    );
  }
}

enum MarkerKind { opening, walkIn, person, livePerson }

class RadarMarker {
  const RadarMarker({required this.id, required this.label, required this.kind, this.distanceKm});

  final String id;
  final String label;
  final MarkerKind kind;
  final double? distanceKm;
}

/// The hatched area map. A marker's distance from centre follows its rounded
/// distance; its direction is derived from its id. The API never sends a
/// bearing, so the picture cannot be used to pinpoint anyone.
class RadarMap extends StatelessWidget {
  const RadarMap({
    super.key,
    required this.markers,
    required this.radiusKm,
    required this.caption,
    required this.liveLabel,
    this.height = 240,
    this.onMarkerTap,
  });

  final List<RadarMarker> markers;
  final double radiusKm;
  final String caption;
  final String liveLabel;
  final double height;
  final ValueChanged<RadarMarker>? onMarkerTap;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: TrRadius.largeCardR,
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final centre = Offset(width / 2, height / 2 + 6);
            final maxRadius = math.min(width, height) / 2 - 30;

            return Stack(
              children: [
                Positioned.fill(child: CustomPaint(painter: _MapBackgroundPainter(centre, maxRadius))),
                for (final marker in markers.take(8)) _positioned(marker, centre, maxRadius),
                Positioned(
                  left: centre.dx - 9,
                  top: centre.dy - 9,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: TrColors.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [BoxShadow(color: TrColors.lime.withValues(alpha: 0.35), spreadRadius: 8)],
                    ),
                  ),
                ),
                Positioned(
                  top: 14,
                  left: 18,
                  right: 18,
                  child: Text(
                    caption,
                    style: TrType.tag.copyWith(color: TrColors.bodyMuted, fontSize: 10.5, letterSpacing: 0.5),
                  ),
                ),
                Positioned(
                  bottom: 14,
                  left: 18,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: TrRadius.pillR,
                      boxShadow: TrColors.raisedShadow,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(color: TrColors.lime, shape: BoxShape.circle),
                        ),
                        const SizedBox(width: 7),
                        Text(liveLabel, style: TrType.tag.copyWith(fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _positioned(RadarMarker marker, Offset centre, double maxRadius) {
    final seed = marker.id.codeUnits.fold<int>(7, (sum, unit) => (sum * 31 + unit) & 0x7fffffff);
    final angle = (seed % 360) * math.pi / 180;
    final fraction = marker.distanceKm == null
        ? 0.55 + (seed % 30) / 100
        : (marker.distanceKm! / math.max(radiusKm, 1)).clamp(0.28, 1.0);
    final offset = centre + Offset(math.cos(angle), math.sin(angle)) * maxRadius * fraction;

    const size = 44.0;
    final isPerson = marker.kind == MarkerKind.person || marker.kind == MarkerKind.livePerson;
    final background = switch (marker.kind) {
      MarkerKind.walkIn => TrColors.clay,
      MarkerKind.opening => TrColors.plumInk,
      _ => TrColors.plumInk,
    };

    return Positioned(
      left: offset.dx - size / 2,
      top: offset.dy - size / 2,
      child: Semantics(
        button: onMarkerTap != null,
        label: marker.label,
        child: GestureDetector(
          onTap: onMarkerTap == null ? null : () => onMarkerTap!(marker),
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: size,
                height: size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: background,
                  shape: isPerson ? BoxShape.circle : BoxShape.rectangle,
                  borderRadius: isPerson ? null : BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(color: background.withValues(alpha: 0.3), blurRadius: 14, offset: const Offset(0, 6)),
                  ],
                ),
                child: isPerson
                    ? Text(marker.label, style: TrType.tag.copyWith(color: Colors.white, fontSize: 12))
                    : Icon(
                        marker.kind == MarkerKind.walkIn ? Icons.place_outlined : Icons.work_outline_rounded,
                        size: 20,
                        color: marker.kind == MarkerKind.walkIn ? Colors.white : TrColors.lime,
                      ),
              ),
              if (marker.kind == MarkerKind.livePerson)
                Positioned(
                  right: -1,
                  bottom: -1,
                  child: Container(
                    width: 13,
                    height: 13,
                    decoration: BoxDecoration(
                      color: TrColors.lime,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MapBackgroundPainter extends CustomPainter {
  const _MapBackgroundPainter(this.centre, this.maxRadius);

  final Offset centre;
  final double maxRadius;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = TrColors.pageCanvas);
    final stripe = Paint()
      ..color = const Color(0xFFE9E2DC)
      ..strokeWidth = 7;
    for (double x = -size.height; x < size.width; x += 20) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), stripe);
    }
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = TrColors.plumInk.withValues(alpha: 0.08);
    for (final fraction in [0.35, 0.7, 1.0]) {
      canvas.drawCircle(centre, maxRadius * fraction, ring);
    }
  }

  @override
  bool shouldRepaint(_MapBackgroundPainter oldDelegate) =>
      oldDelegate.centre != centre || oldDelegate.maxRadius != maxRadius;
}

/// Dark plum call-to-action row ("7 recruiters viewed you · In the last 3 days").
class PlumRow extends StatelessWidget {
  const PlumRow({super.key, required this.title, required this.subtitle, this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrColors.plumInk,
      borderRadius: TrRadius.cardR,
      child: InkWell(
        onTap: onTap,
        borderRadius: TrRadius.cardR,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TrType.itemTitle.copyWith(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 3),
                    Text(subtitle, style: TrType.itemMeta.copyWith(color: Colors.white.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded, color: TrColors.lime),
            ],
          ),
        ),
      ),
    );
  }
}
