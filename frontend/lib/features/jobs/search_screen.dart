import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/config/app_config.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/debouncer.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../widgets/tr_components.dart';
import 'job_widgets.dart';

/// "Search & filters": free text over title, company and category, with the
/// design's chips and a nearest / newest sort.
class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key, this.initialQuery = ''});

  final String initialQuery;

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  late final TextEditingController _controller = TextEditingController(text: widget.initialQuery);
  final Debouncer _debouncer = Debouncer(AppConfig.searchDebounce);
  late JobQuery _query = JobQuery(q: widget.initialQuery);

  @override
  void dispose() {
    _debouncer.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debouncer.run(() {
      if (mounted) setState(() => _query = JobQuery(filter: _query.filter, q: value, sort: _query.sort));
    });
  }

  void _setFilter(String filter) => setState(
        () => _query = JobQuery(filter: _query.filter == filter ? 'all' : filter, q: _query.q, sort: _query.sort),
      );

  @override
  Widget build(BuildContext context) {
    final result = ref.watch(jobListProvider(_query));

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Search')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 22, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _controller,
                  autofocus: widget.initialQuery.isEmpty,
                  textInputAction: TextInputAction.search,
                  onChanged: _onChanged,
                  onSubmitted: (value) {
                    _debouncer.cancel();
                    setState(() => _query = JobQuery(filter: _query.filter, q: value, sort: _query.sort));
                  },
                  style: TrType.bodyText.copyWith(fontSize: 14, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Roles, skills, companies',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18, color: TrColors.plumInk),
                    suffixIcon: ValueListenableBuilder<TextEditingValue>(
                      valueListenable: _controller,
                      builder: (context, value, _) => value.text.isEmpty
                          ? const SizedBox.shrink()
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _controller.clear();
                                setState(() => _query = JobQuery(filter: _query.filter, sort: _query.sort));
                              },
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
                ),
                const SizedBox(height: 14),
                ChipRow(
                  children: [
                    TrFilterChip(
                      label: 'Nearby',
                      selected: _query.filter == 'all',
                      onTap: () => _setFilter('all'),
                    ),
                    TrFilterChip(
                      label: 'Walk-ins',
                      selected: _query.filter == 'walkins',
                      onTap: () => _setFilter('walkins'),
                    ),
                    TrFilterChip(
                      label: 'Remote',
                      selected: _query.filter == 'remote',
                      onTap: () => _setFilter('remote'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: '${result.valueOrNull?.jobs.length ?? '–'}',
                              style: TrType.stat.copyWith(fontSize: 13),
                            ),
                            TextSpan(text: ' matches', style: TrType.itemMeta),
                          ],
                        ),
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Sort',
                      initialValue: _query.sort,
                      onSelected: (sort) =>
                          setState(() => _query = JobQuery(filter: _query.filter, q: _query.q, sort: sort)),
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'nearest', child: Text('Nearest first')),
                        PopupMenuItem(value: 'newest', child: Text('Newest first')),
                      ],
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          '${_query.sort == 'nearest' ? 'Nearest' : 'Newest'} first ▾',
                          style: TrType.label,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
              children: [
                AsyncSection<JobList>(
                  value: result,
                  onRetry: () => ref.invalidate(jobListProvider(_query)),
                  loading: const LoadingCards(count: 4, height: 72),
                  builder: (list) => list.jobs.isEmpty
                      ? EmptyState(
                          icon: Icons.search_off_rounded,
                          title: _query.q.isEmpty ? 'Nothing here yet' : 'No roles match "${_query.q}"',
                          message: 'Try a shorter word such as "support", "sales" or "developer", or remove a filter.',
                        )
                      : Column(
                          children: [
                            for (final job in list.jobs) ...[
                              JobRow(job: job, highlighted: job.walkInToday),
                              const SizedBox(height: 12),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
