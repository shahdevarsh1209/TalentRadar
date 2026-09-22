import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../state/registration_controller.dart';
import '../../widgets/email_field.dart';
import '../../widgets/error_message.dart';
import '../../widgets/job_title_selector.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_progress.dart';
import '../../widgets/registration_text_field.dart';
import '../../widgets/tr_scaffold.dart';

/// Candidate registration — one screen, four required answers.
///
/// Anything that can wait (skills, salary, résumé, exact experience) belongs to
/// profile completion after the radar opens, not here.
class CandidateRegistrationScreen extends ConsumerStatefulWidget {
  const CandidateRegistrationScreen({super.key});

  static const int maxJobTitles = 5;

  @override
  ConsumerState<CandidateRegistrationScreen> createState() =>
      _CandidateRegistrationScreenState();
}

class _CandidateRegistrationScreenState
    extends ConsumerState<CandidateRegistrationScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _showPassword = false;

  /// Set when the CTA is pressed, so required-field errors appear then rather
  /// than while the form is still being filled in.
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    // Restores anything typed before the user stepped back a screen.
    final draft = ref.read(registrationProvider).candidate;
    _nameController.text = draft.name;
    _emailController.text = draft.email;
    _passwordController.text = draft.password;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    FocusScope.of(context).unfocus();

    final controller = ref.read(registrationProvider.notifier);
    final draft = ref.read(registrationProvider).candidate;

    final nameError = Validators.name(draft.name);
    final emailError = Validators.email(draft.email);
    final passwordError = Validators.password(draft.password);

    if (nameError != null || emailError != null || passwordError != null) return;
    if (draft.jobTitles.isEmpty || draft.workModes.isEmpty) return;

    final ok = await controller.submitCandidate();
    if (!mounted || !ok) return;
    context.push(Routes.verifyEmail);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final draft = state.candidate;
    final controller = ref.read(registrationProvider.notifier);
    final fieldErrors = state.error?.fieldErrors ?? const <String, String>{};

    return TrScaffold(
      title: 'Create Your Candidate Profile',
      subtitle:
          'Tell us a little about yourself so we can connect you with relevant opportunities.',
      header: const RegistrationProgress(
        step: 1,
        totalSteps: 1,
        label: 'Professional Profile',
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryCta(
            label: 'Create Candidate Profile',
            loadingLabel: 'Creating Profile...',
            isLoading: state.isSubmitting,
            enabled: draft.isSubmittable,
            onPressed: _submit,
          ),
          const SizedBox(height: 6),
          Text(
            draft.isSubmittable
                ? 'Next: verify your email, then set your area.'
                : 'Name, email, job title and work mode are needed to continue.',
            style: TrType.itemMeta.copyWith(fontSize: 11.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (state.error != null) ...[
            ErrorMessage(
              error: state.error!,
              onRetry: _submit,
              onLogin: () => context.push(Routes.login),
              onDismiss: controller.clearError,
            ),
            const SizedBox(height: 20),
          ],

          // ── Identity ────────────────────────────────────────────────────
          FormSection(
            label: 'About you',
            children: [
              RegistrationTextField(
                label: 'Full Name',
                hint: 'Enter your full name',
                controller: _nameController,
                focusNode: _nameFocus,
                isRequired: true,
                validator: Validators.name,
                serverError: fieldErrors['name'],
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                prefixIcon: Icons.person_outline_rounded,
                maxLength: 80,
                onChanged: (value) =>
                    controller.updateCandidate(draft.copyWith(name: value)),
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: 18),
              EmailField(
                controller: _emailController,
                role: UserRole.candidate,
                serverError: fieldErrors['email'],
                onChanged: (value) =>
                    controller.updateCandidate(draft.copyWith(email: value)),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
                onLoginRequested: () => context.push(Routes.login),
              ),
              const SizedBox(height: 18),
              RegistrationTextField(
                label: 'Password',
                hint: 'At least 8 characters',
                helper: 'Optional — you can also sign in with a one-time email code.',
                controller: _passwordController,
                focusNode: _passwordFocus,
                validator: (value) => Validators.password(value),
                serverError: fieldErrors['password'],
                obscure: !_showPassword,
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.newPassword],
                prefixIcon: Icons.lock_outline_rounded,
                suffix: IconButton(
                  icon: Icon(
                    _showPassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 19,
                    color: TrColors.icon,
                  ),
                  tooltip: _showPassword ? 'Hide password' : 'Show password',
                  onPressed: () => setState(() => _showPassword = !_showPassword),
                ),
                onChanged: (value) =>
                    controller.updateCandidate(draft.copyWith(password: value)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Professional identity ───────────────────────────────────────
          FormSection(
            label: 'Your professional profile',
            note: 'Pick every title you would take a call about — it widens what we can match you to.',
            children: [
              JobTitleSelector(
                selected: draft.jobTitles,
                maxSelection: CandidateRegistrationScreen.maxJobTitles,
                errorText: _submitted && draft.jobTitles.isEmpty
                    ? 'Please select at least one job title.'
                    : fieldErrors['jobTitles'],
                onChanged: (titles) =>
                    controller.updateCandidate(draft.copyWith(jobTitles: titles)),
              ),
              const SizedBox(height: 24),
              ExperienceSelector(
                value: draft.experienceLevel,
                onChanged: (level) =>
                    controller.updateCandidate(draft.copyWith(experienceLevel: level)),
              ),
              const SizedBox(height: 24),
              WorkModeSelector(
                selected: draft.workModes,
                errorText: _submitted && draft.workModes.isEmpty
                    ? 'Please choose at least one work mode.'
                    : fieldErrors['workModes'],
                onChanged: (modes) =>
                    controller.updateCandidate(draft.copyWith(workModes: modes)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          // ── Privacy ─────────────────────────────────────────────────────
          FormSection(
            label: 'Discovery & privacy',
            children: [
              OpenToWorkSelector(
                value: draft.openToWork,
                onChanged: (status) =>
                    controller.updateCandidate(draft.copyWith(openToWork: status)),
              ),
              const SizedBox(height: 24),
              VisibilitySelector(
                value: draft.visibility,
                onChanged: (visibility) =>
                    controller.updateCandidate(draft.copyWith(visibility: visibility)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TrCard(
            color: TrColors.plumSurface,
            borderColor: TrColors.plumSurface,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.location_on_outlined, size: 18, color: TrColors.plumInk),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'We ask for your area after registration, and only ever show it as an approximate neighbourhood — never an exact pin.',
                    style: TrType.itemMeta.copyWith(color: TrColors.plumInk, height: 1.5),
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
