import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import '../core/utils/debouncer.dart';
import '../data/models/registration_draft.dart';
import '../state/providers.dart';
import 'primary_cta.dart';

/// The two ways to ask for location, side by side. Neither is the "wrong"
/// choice: denying the permission is a supported path, not an error state.
class LocationPermissionCard extends StatelessWidget {
  const LocationPermissionCard({
    super.key,
    required this.title,
    required this.body,
    required this.icon,
    required this.onTap,
    this.isPrimary = false,
    this.isBusy = false,
  });

  final String title;
  final String body;
  final IconData icon;
  final VoidCallback onTap;
  final bool isPrimary;
  final bool isBusy;

  @override
  Widget build(BuildContext context) {
    final Color background = isPrimary ? TrColors.plumInk : TrColors.card;
    final Color titleColor = isPrimary ? Colors.white : TrColors.plumInk;
    final Color bodyColor =
        isPrimary ? Colors.white.withValues(alpha: 0.72) : TrColors.bodyMuted;

    return Semantics(
      button: true,
      label: '$title. $body',
      child: InkWell(
        onTap: isBusy ? null : onTap,
        borderRadius: TrRadius.cardR,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: background,
            borderRadius: TrRadius.cardR,
            border: Border.all(color: isPrimary ? TrColors.plumInk : TrColors.border),
            boxShadow: isPrimary ? TrColors.raisedShadow : TrColors.cardShadow,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isPrimary ? TrColors.lime : TrColors.plumSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: isBusy
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: TrColors.plumInk,
                        ),
                      )
                    : Icon(icon, size: 21, color: TrColors.plumInk),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TrType.itemTitle.copyWith(color: titleColor, fontSize: 15)),
                    const SizedBox(height: 3),
                    Text(body, style: TrType.itemMeta.copyWith(color: bodyColor, height: 1.4)),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: isPrimary ? TrColors.lime : TrColors.icon,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Searchable city / area list — the fallback whenever the device fix is
/// unavailable, declined, or simply not what the user wants to share.
class ManualLocationSheet extends ConsumerStatefulWidget {
  const ManualLocationSheet({
    super.key,
    this.title = 'Choose your area',
    this.askForPincode = true,
  });

  final String title;
  final bool askForPincode;

  @override
  ConsumerState<ManualLocationSheet> createState() => _ManualLocationSheetState();
}

class _ManualLocationSheetState extends ConsumerState<ManualLocationSheet> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _pincodeController = TextEditingController();
  final Debouncer _debouncer = Debouncer(AppConfig.searchDebounce);

  List<LocationChoice> _results = const [];
  LocationChoice? _selected;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _searchController.dispose();
    _pincodeController.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await ref.read(locationRepositoryProvider).search(query);
      if (!mounted) return;
      setState(() {
        _results = results;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: DraggableScrollableSheet(
        initialChildSize: 0.9,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: TrColors.borderStrong,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(22, 18, 22, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.title, style: TrType.sectionTitle),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _searchController,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    style: TrType.bodyText.copyWith(fontSize: 14.5),
                    cursorColor: TrColors.plumInk,
                    onChanged: (value) => _debouncer.run(() => _load(value)),
                    decoration: InputDecoration(
                      hintText: 'Search city or area',
                      prefixIcon:
                          const Icon(Icons.search_rounded, size: 19, color: TrColors.icon),
                      border: OutlineInputBorder(
                        borderRadius: TrRadius.pillR,
                        borderSide: const BorderSide(color: TrColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: TrRadius.pillR,
                        borderSide: const BorderSide(color: TrColors.border),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: TrRadius.pillR,
                        borderSide: const BorderSide(color: TrColors.plumInk, width: 1.6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(child: _buildList(scrollController)),
            if (widget.askForPincode && _selected != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 0),
                child: TextField(
                  controller: _pincodeController,
                  keyboardType: TextInputType.number,
                  style: TrType.bodyText.copyWith(fontSize: 14.5),
                  decoration: const InputDecoration(
                    hintText: 'PIN code (optional)',
                    prefixIcon: Icon(Icons.markunread_mailbox_outlined,
                        size: 18, color: TrColors.icon),
                  ),
                ),
              ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                child: PrimaryCta(
                  label: _selected == null ? 'Select an area' : 'Use ${_selected!.display}',
                  enabled: _selected != null,
                  onPressed: () => Navigator.of(context).pop(
                    _selected!.copyWith(pincode: _pincodeController.text.trim()),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildList(ScrollController scrollController) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: TrColors.plumInk));
    }

    if (_error != null && _results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.location_off_outlined, size: 32, color: TrColors.icon),
              const SizedBox(height: 12),
              Text(_error!, style: TrType.bodySmall, textAlign: TextAlign.center),
              const SizedBox(height: 10),
              TrTextAction(
                label: 'Try again',
                onPressed: () => _load(_searchController.text),
              ),
            ],
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Text(
            'No places match "${_searchController.text.trim()}". Try a city name such as Bengaluru or Ahmedabad.',
            style: TrType.bodySmall,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final choice = _results[index];
        final selected = _selected?.display == choice.display;

        return InkWell(
          onTap: () => setState(() => _selected = choice),
          borderRadius: TrRadius.inputR,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
            decoration: BoxDecoration(
              color: selected ? TrColors.plumSurface : Colors.transparent,
              borderRadius: TrRadius.inputR,
            ),
            child: Row(
              children: [
                Icon(
                  choice.area.isEmpty
                      ? Icons.location_city_rounded
                      : Icons.place_outlined,
                  size: 19,
                  color: TrColors.icon,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        choice.area.isEmpty ? choice.city : choice.area,
                        style: TrType.itemTitle.copyWith(fontSize: 14.5),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        choice.area.isEmpty
                            ? choice.state
                            : '${choice.city}, ${choice.state}',
                        style: TrType.itemMeta.copyWith(fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                if (selected)
                  const Icon(Icons.check_circle_rounded,
                      size: 21, color: TrColors.plumInk),
              ],
            ),
          ),
        );
      },
    );
  }
}
