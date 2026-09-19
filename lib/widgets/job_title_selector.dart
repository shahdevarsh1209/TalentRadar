import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/config/app_config.dart';
import '../core/network/api_exception.dart';
import '../core/theme/tr_colors.dart';
import '../core/theme/tr_theme.dart';
import '../core/theme/tr_typography.dart';
import '../core/utils/debouncer.dart';
import '../data/models/job_title.dart';
import '../state/providers.dart';
import 'job_title_chip.dart';
import 'primary_cta.dart';

/// Searchable, multi-select job-title field backed by the job-title master.
///
/// Free text is deliberately not accepted: every selection is a master record,
/// which is what lets a candidate's "Software Support Executive" and a
/// recruiter's be matched later without fuzzy string work.
class JobTitleSelector extends StatelessWidget {
  const JobTitleSelector({
    super.key,
    required this.selected,
    required this.onChanged,
    required this.maxSelection,
    this.label = 'Job Title',
    this.hint = 'Search your job title...',
    this.emptyHint = 'Add the roles you want to be found for.',
    this.errorText,
    this.isRequired = true,
  });

  final List<JobTitle> selected;
  final ValueChanged<List<JobTitle>> onChanged;
  final int maxSelection;
  final String label;
  final String hint;
  final String emptyHint;
  final String? errorText;
  final bool isRequired;

  Future<void> _openSearch(BuildContext context) async {
    final result = await showModalBottomSheet<List<JobTitle>>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: TrColors.canvas,
      builder: (_) => _JobTitleSearchSheet(
        initialSelection: selected,
        maxSelection: maxSelection,
        title: label,
        hint: hint,
      ),
    );
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final bool hasError = errorText != null;
    final bool atLimit = selected.length >= maxSelection;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
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
            const Spacer(),
            Text(
              '${selected.length}/$maxSelection',
              style: TrType.itemMeta.copyWith(
                fontSize: 11.5,
                color: atLimit ? TrColors.clayText : TrColors.icon,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        Semantics(
          button: true,
          label: '$label, ${selected.length} selected. Opens search.',
          child: InkWell(
            onTap: () => _openSearch(context),
            borderRadius: TrRadius.inputR,
            child: Container(
              width: double.infinity,
              constraints: const BoxConstraints(minHeight: 54),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: TrColors.card,
                borderRadius: TrRadius.inputR,
                border: Border.all(
                  color: hasError ? TrColors.error : TrColors.border,
                  width: hasError ? 1.4 : 1,
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.search_rounded, size: 19, color: TrColors.icon),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Text(
                      selected.isEmpty ? hint : 'Add another title',
                      style: TrType.bodyText.copyWith(
                        fontSize: 14.5,
                        color: TrColors.icon,
                      ),
                    ),
                  ),
                  const Icon(Icons.expand_more_rounded, size: 20, color: TrColors.icon),
                ],
              ),
            ),
          ),
        ),
        if (selected.isNotEmpty) ...[
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final title in selected)
                JobTitleChip(
                  label: title.name,
                  category: title.category,
                  onRemove: () =>
                      onChanged(selected.where((item) => item.code != title.code).toList()),
                ),
            ],
          ),
        ],
        Padding(
          padding: const EdgeInsets.only(top: 8, left: 4),
          child: Text(
            hasError ? errorText! : (selected.isEmpty ? emptyHint : 'Tap a title to remove it.'),
            style: TrType.itemMeta.copyWith(
              fontSize: 11.5,
              color: hasError ? TrColors.error : TrColors.icon,
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-height search sheet. Kept separate so the field itself stays cheap and
/// the sheet can own its own search state.
class _JobTitleSearchSheet extends ConsumerStatefulWidget {
  const _JobTitleSearchSheet({
    required this.initialSelection,
    required this.maxSelection,
    required this.title,
    required this.hint,
  });

  final List<JobTitle> initialSelection;
  final int maxSelection;
  final String title;
  final String hint;

  @override
  ConsumerState<_JobTitleSearchSheet> createState() => _JobTitleSearchSheetState();
}

class _JobTitleSearchSheetState extends ConsumerState<_JobTitleSearchSheet> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Debouncer _debouncer = Debouncer(AppConfig.searchDebounce);

  late List<JobTitle> _selected = List.of(widget.initialSelection);
  List<JobTitle> _results = const [];
  bool _loading = true;
  String? _error;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _load(String query) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await ref.read(jobTitleRepositoryProvider).search(query, limit: 30);
      if (!mounted || query != _query) return; // A newer keystroke won the race.
      setState(() {
        _results = results;
        _loading = false;
      });
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = error.isNetwork
            ? 'You appear to be offline. Job titles will load when you reconnect.'
            : 'We could not load job titles just now.';
      });
    }
  }

  void _onQueryChanged(String value) {
    _query = value;
    _debouncer.run(() => _load(value));
  }

  void _toggle(JobTitle title) {
    final exists = _selected.any((item) => item.code == title.code);
    if (exists) {
      setState(() => _selected = _selected.where((item) => item.code != title.code).toList());
      return;
    }
    if (_selected.length >= widget.maxSelection) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'You can select up to ${widget.maxSelection} titles. Remove one to add another.',
            ),
          ),
        );
      return;
    }
    setState(() => _selected = [..._selected, title]);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      // Lifts the sheet above the keyboard so results stay visible while typing.
      padding: EdgeInsets.only(bottom: viewInsets),
      child: DraggableScrollableSheet(
        initialChildSize: 0.92,
        minChildSize: 0.5,
        maxChildSize: 0.96,
        expand: false,
        builder: (context, scrollController) {
          return Column(
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
                    Row(
                      children: [
                        Expanded(child: Text(widget.title, style: TrType.sectionTitle)),
                        Text(
                          '${_selected.length}/${widget.maxSelection}',
                          style: TrType.itemMeta,
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _controller,
                      focusNode: _focusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.search,
                      style: TrType.bodyText.copyWith(fontSize: 14.5),
                      cursorColor: TrColors.plumInk,
                      onChanged: _onQueryChanged,
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        prefixIcon:
                            const Icon(Icons.search_rounded, size: 19, color: TrColors.icon),
                        suffixIcon: _controller.text.isEmpty
                            ? null
                            : IconButton(
                                icon: const Icon(Icons.close_rounded, size: 18),
                                color: TrColors.icon,
                                onPressed: () {
                                  _controller.clear();
                                  _onQueryChanged('');
                                },
                              ),
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
              if (_selected.isNotEmpty)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(22, 0, 22, 12),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final title in _selected)
                        JobTitleChip(label: title.name, onRemove: () => _toggle(title)),
                    ],
                  ),
                ),
              const Divider(height: 1),
              Expanded(child: _buildResults(scrollController)),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(22, 12, 22, 12),
                  child: PrimaryCta(
                    label: _selected.isEmpty
                        ? 'Select at least one'
                        : 'Done · ${_selected.length} selected',
                    enabled: _selected.isNotEmpty,
                    onPressed: () => Navigator.of(context).pop(_selected),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildResults(ScrollController scrollController) {
    if (_loading && _results.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: TrColors.plumInk));
    }

    if (_error != null && _results.isEmpty) {
      return _SheetMessage(
        icon: Icons.cloud_off_rounded,
        title: 'Job titles unavailable',
        body: _error!,
        action: TrTextAction(label: 'Try again', onPressed: () => _load(_query)),
      );
    }

    if (_results.isEmpty) {
      return _SheetMessage(
        icon: Icons.search_off_rounded,
        title: 'No titles match "${_controller.text.trim()}"',
        body: 'Try a shorter word, such as "support", "developer" or "accounts".',
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 10),
      itemCount: _results.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (context, index) {
        final title = _results[index];
        final isSelected = _selected.any((item) => item.code == title.code);
        final alias = title.matchedAlias(_controller.text);

        return Semantics(
          selected: isSelected,
          button: true,
          child: InkWell(
            onTap: () => _toggle(title),
            borderRadius: TrRadius.inputR,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              decoration: BoxDecoration(
                color: isSelected ? TrColors.plumSurface : Colors.transparent,
                borderRadius: TrRadius.inputR,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title.name, style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                        const SizedBox(height: 3),
                        Text(
                          alias != null ? '${title.category} · also $alias' : title.category,
                          style: TrType.itemMeta.copyWith(fontSize: 11.5),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected ? TrColors.plumInk : Colors.transparent,
                      border: isSelected
                          ? null
                          : Border.all(color: TrColors.borderStrong, width: 1.5),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check_rounded, size: 15, color: TrColors.lime)
                        : null,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _SheetMessage extends StatelessWidget {
  const _SheetMessage({
    required this.icon,
    required this.title,
    required this.body,
    this.action,
  });

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 34, color: TrColors.icon),
            const SizedBox(height: 14),
            Text(title, style: TrType.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(body, style: TrType.bodySmall, textAlign: TextAlign.center),
            if (action != null) ...[const SizedBox(height: 10), action!],
          ],
        ),
      ),
    );
  }
}
