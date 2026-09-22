import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../data/models/job_title.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/job_title_chip.dart';
import '../../widgets/job_title_selector.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_text_field.dart';
import '../../widgets/tr_scaffold.dart';

/// Profile completion after registration. Candidates edit their professional
/// profile; recruiters edit what they hire for.
class EditProfileScreen extends ConsumerWidget {
  const EditProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCandidate = ref.watch(sessionProvider)?.isCandidate ?? true;
    return isCandidate ? const _CandidateEditor() : const _RecruiterEditor();
  }
}

class _CandidateEditor extends ConsumerStatefulWidget {
  const _CandidateEditor();

  @override
  ConsumerState<_CandidateEditor> createState() => _CandidateEditorState();
}

class _CandidateEditorState extends ConsumerState<_CandidateEditor> {
  late final _profile = ref.read(sessionProvider)!.candidate!;
  late final _name = TextEditingController(text: _profile.name);
  late final _headline = TextEditingController(text: _profile.headline);
  final _skillInput = TextEditingController();
  late List<String> _skills = List.of(_profile.skills);
  late List<JobTitle> _titles = List.of(_profile.jobTitles);
  late ExperienceLevel _experience = _profile.experienceLevel;
  late List<WorkMode> _modes = List.of(_profile.workModes);

  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _headline.dispose();
    _skillInput.dispose();
    super.dispose();
  }

  bool get _valid => Validators.name(_name.text) == null && _titles.isNotEmpty && _modes.isNotEmpty;

  void _addSkill() {
    final skill = Validators.tidy(_skillInput.text);
    if (skill.isEmpty) return;
    if (_skills.length >= 20) {
      setState(() => _error = ApiException(code: 'LIMIT', message: 'You can add up to 20 skills.'));
      return;
    }
    if (!_skills.any((item) => item.toLowerCase() == skill.toLowerCase())) {
      setState(() => _skills = [..._skills, skill]);
    }
    _skillInput.clear();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = await ref.read(peopleRepositoryProvider).updateCandidateProfile(
            name: Validators.tidy(_name.text),
            headline: _headline.text.trim(),
            skills: _skills,
            jobTitles: _titles,
            experienceLevel: _experience,
            workModes: _modes,
          );
      ref.read(sessionProvider.notifier).update(session);
      ref.refreshHome();
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrScaffold(
      title: 'Edit profile',
      subtitle: 'A clear headline and a few skills help recruiters understand you at a glance.',
      footer: PrimaryCta(
        label: 'Save changes',
        loadingLabel: 'Saving…',
        isLoading: _saving,
        enabled: _valid,
        onPressed: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorMessage(error: _error!, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 18),
          ],
          RegistrationTextField(
            label: 'Full Name',
            controller: _name,
            isRequired: true,
            validator: Validators.name,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          RegistrationTextField(
            label: 'Headline',
            hint: 'e.g. Support specialist · Zendesk & Freshdesk',
            controller: _headline,
            maxLength: 120,
            helper: 'One line recruiters see under your name.',
          ),
          const SizedBox(height: 22),
          JobTitleSelector(
            selected: _titles,
            maxSelection: 5,
            onChanged: (titles) => setState(() => _titles = titles),
            errorText: _titles.isEmpty ? 'Please keep at least one job title.' : null,
          ),
          const SizedBox(height: 22),
          Text('Skills', style: TrType.label),
          const SizedBox(height: 7),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _skillInput,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addSkill(),
                  decoration: const InputDecoration(hintText: 'Add a skill, e.g. Excel'),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Add skill',
                style: IconButton.styleFrom(backgroundColor: TrColors.plumInk),
                onPressed: _addSkill,
                icon: const Icon(Icons.add_rounded, color: Colors.white),
              ),
            ],
          ),
          if (_skills.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final skill in _skills)
                  JobTitleChip(
                    label: skill,
                    onRemove: () => setState(() => _skills = _skills.where((item) => item != skill).toList()),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          ExperienceSelector(value: _experience, onChanged: (level) => setState(() => _experience = level)),
          const SizedBox(height: 24),
          WorkModeSelector(
            selected: _modes,
            errorText: _modes.isEmpty ? 'Please choose at least one work mode.' : null,
            onChanged: (modes) => setState(() => _modes = modes),
          ),
        ],
      ),
    );
  }
}

class _RecruiterEditor extends ConsumerStatefulWidget {
  const _RecruiterEditor();

  @override
  ConsumerState<_RecruiterEditor> createState() => _RecruiterEditorState();
}

class _RecruiterEditorState extends ConsumerState<_RecruiterEditor> {
  late final _profile = ref.read(sessionProvider)!.recruiter!;
  late final _name = TextEditingController(text: _profile.hrName);
  late final _designation = TextEditingController(text: _profile.designation);
  late List<JobTitle> _titles = List.of(_profile.hiringProfiles);
  late List<WorkMode> _modes = List.of(_profile.hiringWorkModes);

  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _name.dispose();
    _designation.dispose();
    super.dispose();
  }

  bool get _valid => Validators.name(_name.text) == null && _titles.isNotEmpty;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final session = await ref.read(peopleRepositoryProvider).updateRecruiterProfile(
            hrName: Validators.tidy(_name.text),
            designation: _designation.text.trim(),
            hiringProfiles: _titles,
            hiringWorkModes: _modes,
          );
      ref.read(sessionProvider.notifier).update(session);
      ref.refreshHome();
      if (mounted) context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrScaffold(
      title: 'Edit hiring profile',
      subtitle: 'Candidates matching these roles are highlighted on your radar.',
      footer: PrimaryCta(
        label: 'Save changes',
        loadingLabel: 'Saving…',
        isLoading: _saving,
        enabled: _valid,
        onPressed: _save,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorMessage(error: _error!, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 18),
          ],
          RegistrationTextField(
            label: 'HR / Recruiter Name',
            controller: _name,
            isRequired: true,
            validator: Validators.name,
            textCapitalization: TextCapitalization.words,
            maxLength: 80,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 18),
          RegistrationTextField(
            label: 'Your Designation',
            hint: 'e.g. Talent Acquisition Manager',
            controller: _designation,
            maxLength: 80,
          ),
          const SizedBox(height: 22),
          JobTitleSelector(
            label: 'Hiring Profiles',
            hint: 'Search roles you are hiring for...',
            selected: _titles,
            maxSelection: 10,
            onChanged: (titles) => setState(() => _titles = titles),
            errorText: _titles.isEmpty ? 'Please keep at least one hiring profile.' : null,
          ),
          const SizedBox(height: 24),
          WorkModeSelector(
            label: 'Work Mode You Offer',
            isRequired: false,
            helper: 'Optional — helps us show you candidates who want the same.',
            selected: _modes,
            onChanged: (modes) => setState(() => _modes = modes),
          ),
        ],
      ),
    );
  }
}
