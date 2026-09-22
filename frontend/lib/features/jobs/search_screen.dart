import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/debouncer.dart';
import '../../data/models/enums.dart';
import '../../data/models/hiring.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';
import '../people/hiring_widgets.dart';
import '../people/people_widgets.dart';
import 'job_widgets.dart';
import 'search_filters_sheet.dart';

/// Search, shaped by who is asking.
///
/// A candidate is looking for roles, the companies hiring for them and the
/// recruiters behind those roles; a recruiter is looking for people. Both use
/// the same endpoint and the same [SearchQuery], so a filter cannot be shown
/// on screen without being part of the request that runs.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
  final Debouncer _debouncer = Debouncer(AppConfig.searchDebounce);
  late SearchQuery _query;

  /// The tabs this role gets, in order. Set once — a session cannot change role.
  late final List<String> _tabs;

  @override
  void initState() {
    super.initState();
    final isCandidate = ref.read(sessionProvider)?.isCandidate ?? true;
    _tabs = isCandidate
        ? const ['jobs', 'companies', 'recruiters']
        : const ['candidates', 'jobs'];
    _query = SearchQuery(q: widget.initialQuery, type: _tabs.first);
  }

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  /// Typing is debounced so a five-letter word is one request, not five.
  void _onChanged(String value) =>
      _debouncer.run(() => _apply(_query.copyWith(q: value)));

  void _submit(String value) {
    _debouncer.cancel();
    _apply(_query.copyWith(q: value));
  }

  void _apply(SearchQuery next) {
    if (!mounted || next == _query) return;
    setState(() => _query = next);
  }

  Future<void> _openFilters() async {
    final next = await showSearchFilters(context, _query);
    if (next != null) _apply(next);
  }

  @override
  Widget build(BuildContext context) {
    final results = ref.watch(searchProvider(_query));
    final counts = results.valueOrNull?.counts ?? const {};

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _SearchField(
                  controller: _controller,
                  autofocus: widget.initialQuery.isEmpty,
                  hint: _hintFor(_query.type),
                  onChanged: _onChanged,
                  onSubmitted: _submit,
                  onClear: () {
                    _controller.clear();
                    _apply(_query.copyWith(q: ''));
                  },
                ),
                const SizedBox(height: 14),
                // What am I looking for? — the tabs from section 9.
                ChipRow(
                  children: [
                    for (final tab in _tabs)
                      TrFilterChip(
                        label: _labelFor(tab, counts[tab]),
                        selected: _query.type == tab,
                        onTap: () => _apply(_query.copyWith(type: tab)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                _QuickFilters(query: _query, onChanged: _apply),
                const SizedBox(height: 10),
                _ResultBar(
                  query: _query,
                  count: counts[_query.type],
                  onFilters: _openFilters,
                  onSort: (sort) => _apply(_query.copyWith(sort: sort)),
                  onClearFilters: () => _apply(_query.cleared()),
                ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => ref.refresh(searchProvider(_query).future),
              child: ListView(
                keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(22, 6, 22, 28),
                children: [
                  AsyncSection<SearchResults>(
                    value: results,
                    onRetry: () => ref.invalidate(searchProvider(_query)),
                    loading: const LoadingCards(count: 4, height: 96),
                    builder: (data) => _Results(
                      query: _query,
                      data: data,
                      onChanged: () => ref.invalidate(searchProvider(_query)),
                      onClearFilters: () => _apply(_query.cleared()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _labelFor(String tab, int? count) {
    final name = switch (tab) {
      'jobs' => 'Jobs',
      'companies' => 'Companies',
      'recruiters' => 'Recruiters',
      'candidates' => 'Candidates',
      _ => tab,
    };
    // Counts only appear for the tab that ran; the others fill in as visited.
    return count == null ? name : '$name · $count';
  }

  String _hintFor(String tab) => switch (tab) {
        'companies' => 'Company or industry',
        'recruiters' => 'Recruiter, company or role',
        'candidates' => 'Role, skill or name',
        _ => 'Roles, skills, companies',
      };
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.autofocus,
    required this.hint,
    required this.onChanged,
    required this.onSubmitted,
    required this.onClear,
  });

  final TextEditingController controller;
  final bool autofocus;
  final String hint;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: TrType.bodyText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: TrColors.plumInk),
        suffixIcon: ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => value.text.isEmpty
              ? const SizedBox.shrink()
              : IconButton(
                  tooltip: 'Clear',
                  icon: const Icon(Icons.close_rounded, size: 18),
                  onPressed: onClear,
                ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: TrRadius.pillR,
          borderSide: const BorderSide(color: TrColors.plumInk),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: TrRadius.pillR,
          borderSide: const BorderSide(color: TrColors.plumInk, width: 1.6),
        ),
      ),
    );
  }
}

/// The one or two filters worth a tap rather than a trip to the sheet.
class _QuickFilters extends StatelessWidget {
  const _QuickFilters({required this.query, required this.onChanged});

  final SearchQuery query;
  final ValueChanged<SearchQuery> onChanged;

  @override
  Widget build(BuildContext context) {
    final chips = <Widget>[];

    switch (query.type) {
      case 'jobs':
        chips.addAll([
          TrFilterChip(
            label: 'Walk-ins',
            selected: query.walkIn,
            onTap: () => onChanged(query.copyWith(walkIn: !query.walkIn, remote: false)),
          ),
          TrFilterChip(
            label: 'Remote',
            selected: query.remote,
            onTap: () => onChanged(query.copyWith(remote: !query.remote, walkIn: false)),
          ),
          TrFilterChip(
            label: 'Freshers',
            selected: query.openToFreshers,
            onTap: () => onChanged(query.copyWith(openToFreshers: !query.openToFreshers)),
          ),
        ]);
      case 'companies':
      case 'recruiters':
        chips.add(
          TrFilterChip(
            label: 'Hiring now',
            selected: query.hiringNow,
            onTap: () => onChanged(query.copyWith(hiringNow: !query.hiringNow)),
          ),
        );
      case 'candidates':
        chips.addAll([
          TrFilterChip(
            label: 'Available today',
            selected: query.availableToday,
            onTap: () => onChanged(query.copyWith(availableToday: !query.availableToday)),
          ),
          TrFilterChip(
            label: 'Actively looking',
            selected: query.openToWork == OpenToWork.activelyLooking,
            onTap: () => onChanged(
              query.openToWork == OpenToWork.activelyLooking
                  ? query.copyWith(clearOpenToWork: true)
                  : query.copyWith(openToWork: OpenToWork.activelyLooking),
            ),
          ),
        ]);
    }

    return ChipRow(children: chips);
  }
}

class _ResultBar extends StatelessWidget {
  const _ResultBar({
    required this.query,
    required this.count,
    required this.onFilters,
    required this.onSort,
    required this.onClearFilters,
  });

  final SearchQuery query;
  final int? count;
  final VoidCallback onFilters;
  final ValueChanged<String> onSort;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final active = query.activeFilterCount;

    return Row(
      children: [
        Expanded(
          child: Text.rich(
            TextSpan(
              children: [
                TextSpan(text: '${count ?? '–'}', style: TrType.stat.copyWith(fontSize: 13)),
                TextSpan(text: count == 1 ? ' match' : ' matches', style: TrType.itemMeta),
              ],
            ),
          ),
        ),
        if (active > 0)
          TextButton(
            onPressed: onClearFilters,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text('Clear', style: TrType.itemMeta.copyWith(color: TrColors.clayText)),
          ),
        IconButton(
          tooltip: 'Filters',
          onPressed: onFilters,
          // The default 48 px target plus the sort label does not fit a 320 px
          // phone at 1.3× text, and this row must not scroll.
          constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
          padding: EdgeInsets.zero,
          icon: Badge(
            isLabelVisible: active > 0,
            label: Text('$active'),
            backgroundColor: TrColors.plumInk,
            child: const Icon(Icons.tune_rounded, size: 20, color: TrColors.plumInk),
          ),
        ),
        const SizedBox(width: 6),
        PopupMenuButton<String>(
          tooltip: 'Sort',
          initialValue: query.sort,
          onSelected: onSort,
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'nearest', child: Text('Nearest first')),
            PopupMenuItem(value: 'newest', child: Text('Newest first')),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              '${query.sort == 'nearest' ? 'Nearest' : 'Newest'} ▾',
              style: TrType.label,
            ),
          ),
        ),
      ],
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    required this.query,
    required this.data,
    required this.onChanged,
    required this.onClearFilters,
  });

  final SearchQuery query;
  final SearchResults data;
  final VoidCallback onChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    final items = switch (query.type) {
      'companies' => [
          for (final company in data.companies) CompanyCardView(company: company),
        ],
      'recruiters' => [
          for (final recruiter in data.recruiters)
            RecruiterCardView(recruiter: recruiter, onChanged: onChanged),
        ],
      'candidates' => [
          for (final candidate in data.candidates) CandidateCardView(candidate: candidate),
        ],
      _ => [
          for (final job in data.jobs) JobCard(job: job),
        ],
    };

    if (items.isEmpty) {
      final filtered = query.activeFilterCount > 0;
      return EmptyState(
        icon: Icons.search_off_rounded,
        title: query.q.isEmpty
            ? 'Nothing here yet'
            : 'No ${_noun(query.type)} match "${query.q}"',
        message: filtered
            ? 'Your filters may be too narrow. Clearing them often brings results back.'
            : 'Try a shorter word such as "support", "sales" or "developer".',
        actionLabel: filtered ? 'Clear filters' : null,
        onAction: filtered ? onClearFilters : null,
      );
    }

    return Column(
      children: [
        if (!data.hasLocation)
          const Padding(
            padding: EdgeInsets.only(bottom: 14),
            child: InfoNote(
              text: 'Add your area to sort these by how close they are to you.',
            ),
          ),
        for (final item in items) ...[item, const SizedBox(height: 12)],
      ],
    );
  }

  String _noun(String type) => switch (type) {
        'companies' => 'companies',
        'recruiters' => 'recruiters',
        'candidates' => 'candidates',
        _ => 'roles',
      };
}
