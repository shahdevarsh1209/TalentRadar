import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/enums.dart';
import '../../data/models/job.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/job_title_selector.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_text_field.dart';
import '../../widgets/tr_components.dart';
import '../../widgets/tr_scaffold.dart';

/// The recruiter's centre action: post a role, optionally as a walk-in drive.
/// Location comes from the company hiring location, never from the device.
class PostJobScreen extends ConsumerStatefulWidget {
  const PostJobScreen({super.key});

  @override
  ConsumerState<PostJobScreen> createState() => _PostJobScreenState();
}

class _PostJobScreenState extends ConsumerState<PostJobScreen> {
  JobDraft _draft = const JobDraft();
  final _openings = TextEditingController(text: '1');
  final _salaryMin = TextEditingController();
  final _salaryMax = TextEditingController();
  final _description = TextEditingController();
  final _address = TextEditingController();

  bool _submitting = false;
  bool _submitted = false;
  ApiException? _error;

  @override
  void dispose() {
    _openings.dispose();
    _salaryMin.dispose();
    _salaryMax.dispose();
    _description.dispose();
    _address.dispose();
    super.dispose();
  }

  String? get _salaryError {
    final min = int.tryParse(_salaryMin.text);
    final max = int.tryParse(_salaryMax.text);
    if (min != null && max != null && min > max) return 'Minimum is higher than maximum.';
    return null;
  }

  bool get _valid =>
      _draft.title != null &&
      (int.tryParse(_openings.text) ?? 0) >= 1 &&
      _salaryError == null &&
      (!_draft.isWalkIn || (_draft.walkInDate != null && _draft.startTime.compareTo(_draft.endTime) < 0));

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _draft.walkInDate ?? today,
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: today.add(const Duration(days: 90)),
      helpText: 'Walk-in date',
    );
    if (picked != null) setState(() => _draft = _copy(walkInDate: picked));
  }

  Future<void> _pickTime({required bool start}) async {
    final current = (start ? _draft.startTime : _draft.endTime).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(current[0]), minute: int.parse(current[1])),
      helpText: start ? 'Walk-in starts' : 'Walk-in ends',
    );
    if (picked == null) return;
    final value = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    setState(() => _draft = start ? _copy(startTime: value) : _copy(endTime: value));
  }

  JobDraft _copy({
    WorkMode? workMode,
    ExperienceLevel? experienceLevel,
    bool? isWalkIn,
    DateTime? walkInDate,
    String? startTime,
    String? endTime,
  }) =>
      JobDraft(
        title: _draft.title,
        workMode: workMode ?? _draft.workMode,
        experienceLevel: experienceLevel ?? _draft.experienceLevel,
        isWalkIn: isWalkIn ?? _draft.isWalkIn,
        walkInDate: walkInDate ?? _draft.walkInDate,
        startTime: startTime ?? _draft.startTime,
        endTime: endTime ?? _draft.endTime,
      );

  Future<void> _submit() async {
    setState(() => _submitted = true);
    if (!_valid || _submitting) return;
    FocusScope.of(context).unfocus();

    final draft = JobDraft(
      title: _draft.title,
      workMode: _draft.isWalkIn ? WorkMode.onsite : _draft.workMode,
      experienceLevel: _draft.experienceLevel,
      openings: int.parse(_openings.text),
      salaryMin: int.tryParse(_salaryMin.text),
      salaryMax: int.tryParse(_salaryMax.text),
      description: _description.text,
      isWalkIn: _draft.isWalkIn,
      walkInDate: _draft.walkInDate,
      startTime: _draft.startTime,
      endTime: _draft.endTime,
      address: _address.text,
    );

    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await ref.read(jobsRepositoryProvider).create(draft);
      ref.refreshHome();
      if (!mounted) return;
      showTrSnack(context, 'Posted. Candidates near your hiring location can see it now.');
      context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recruiter = ref.watch(sessionProvider)?.recruiter;
    final location = recruiter?.primaryHiringLocation;
    final digits = [FilteringTextInputFormatter.digitsOnly];

    return TrScaffold(
      title: 'Post a role',
      subtitle: location == null
          ? 'Set your hiring location first so nearby candidates can see this role.'
          : 'Candidates near ${location.display} will see this on their radar.',
      footer: PrimaryCta(
        label: _draft.isWalkIn ? 'Post walk-in' : 'Post role',
        loadingLabel: 'Posting…',
        isLoading: _submitting,
        enabled: _valid && location != null,
        onPressed: _submit,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (location == null) ...[
            InfoNote(
              icon: Icons.apartment_rounded,
              text: 'You have not set a company hiring location yet.',
            ),
            const SizedBox(height: 10),
            PrimaryCta(
              label: 'Set hiring location',
              variant: CtaVariant.outline,
              onPressed: () => context.push(Routes.changeLocation(recruiter: true)),
            ),
            const SizedBox(height: 22),
          ],
          if (_error != null) ...[
            ErrorMessage(error: _error!, onRetry: _submit, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 18),
          ],
          JobTitleSelector(
            label: 'Role',
            hint: 'Search the role you are hiring for...',
            emptyHint: 'Pick from the standard titles so candidates can be matched.',
            maxSelection: 1,
            selected: [if (_draft.title != null) _draft.title!],
            errorText: _submitted && _draft.title == null ? 'Please choose the role.' : null,
            onChanged: (titles) => setState(() {
              _draft = JobDraft(
                title: titles.isEmpty ? null : titles.first,
                workMode: _draft.workMode,
                experienceLevel: _draft.experienceLevel,
                isWalkIn: _draft.isWalkIn,
                walkInDate: _draft.walkInDate,
                startTime: _draft.startTime,
                endTime: _draft.endTime,
              );
            }),
          ),
          const SizedBox(height: 22),
          // Walk-in switch — the product's signature listing.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _draft.isWalkIn ? TrColors.claySurface : TrColors.card,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _draft.isWalkIn ? TrColors.claySurface : TrColors.border),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(Icons.storefront_outlined, color: _draft.isWalkIn ? TrColors.clayText : TrColors.plumInk),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Walk-in interview', style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                          Text('Candidates nearby can just turn up', style: TrType.itemMeta),
                        ],
                      ),
                    ),
                    TrToggle(
                      value: _draft.isWalkIn,
                      label: 'Walk-in interview',
                      onChanged: (value) => setState(() {
                        _draft = _copy(isWalkIn: value, walkInDate: value ? (_draft.walkInDate ?? DateTime.now()) : null);
                      }),
                    ),
                  ],
                ),
                if (_draft.isWalkIn) ...[
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerField(
                          label: 'Date',
                          value: _draft.walkInDate == null ? 'Pick a date' : Fmt.day(_draft.walkInDate!),
                          icon: Icons.calendar_today_rounded,
                          onTap: _pickDate,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: _PickerField(
                          label: 'From',
                          value: Fmt.clock(_draft.startTime),
                          icon: Icons.schedule_rounded,
                          onTap: () => _pickTime(start: true),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _PickerField(
                          label: 'Until',
                          value: Fmt.clock(_draft.endTime),
                          icon: Icons.schedule_rounded,
                          onTap: () => _pickTime(start: false),
                        ),
                      ),
                    ],
                  ),
                  if (_draft.startTime.compareTo(_draft.endTime) >= 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        'The end time must be after the start time.',
                        style: TrType.itemMeta.copyWith(color: TrColors.error),
                      ),
                    ),
                  const SizedBox(height: 10),
                  RegistrationTextField(
                    label: 'Venue address',
                    hint: location == null ? 'Street, landmark' : 'Defaults to ${location.display}',
                    controller: _address,
                    maxLength: 200,
                    prefixIcon: Icons.place_outlined,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 22),
          if (!_draft.isWalkIn) ...[
            Text('Work mode', style: TrType.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in WorkMode.values)
                  ChoicePill(
                    label: switch (mode) {
                      WorkMode.remote => 'Remote',
                      WorkMode.onsite => 'On-site',
                      WorkMode.hybrid => 'Hybrid',
                    },
                    selected: _draft.workMode == mode,
                    onTap: () => setState(() => _draft = _copy(workMode: mode)),
                  ),
              ],
            ),
            const SizedBox(height: 22),
          ],
          Text('Experience needed', style: TrType.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final level in ExperienceLevel.values)
                ChoicePill(
                  label: level.label,
                  selected: _draft.experienceLevel == level,
                  onTap: () => setState(() => _draft = _copy(experienceLevel: level)),
                ),
            ],
          ),
          const SizedBox(height: 22),
          RegistrationTextField(
            label: 'Openings',
            controller: _openings,
            isRequired: true,
            keyboardType: TextInputType.number,
            maxLength: 3,
            prefixIcon: Icons.group_add_outlined,
            validator: (value) => (int.tryParse(value ?? '') ?? 0) < 1 ? 'At least one opening.' : null,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          Text('Monthly salary (₹, optional)', style: TrType.label),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _salaryMin,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Min, e.g. 22000'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _salaryMax,
                  keyboardType: TextInputType.number,
                  inputFormatters: digits,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(hintText: 'Max, e.g. 28000'),
                ),
              ),
            ],
          ),
          if (_salaryError != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(_salaryError!, style: TrType.itemMeta.copyWith(color: TrColors.error)),
            ),
          const SizedBox(height: 18),
          Text('About the role (optional)', style: TrType.label),
          const SizedBox(height: 7),
          TextField(
            controller: _description,
            maxLines: 5,
            maxLength: 2000,
            decoration: const InputDecoration(
              hintText: 'What the day looks like, who you are looking for, what to bring.',
            ),
          ),
        ],
      ),
    );
  }
}

class _PickerField extends StatelessWidget {
  const _PickerField({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: TrColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, size: 17, color: TrColors.icon),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label, style: TrType.itemMeta.copyWith(fontSize: 11)),
                    Text(value, style: TrType.itemTitle.copyWith(fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
