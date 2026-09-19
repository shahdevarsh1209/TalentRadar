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

/// HR / recruiter registration.
///
/// Company logo, industry, size, website and verification are all deliberately
/// absent — they belong to company profile completion, not to getting started.
class RecruiterRegistrationScreen extends ConsumerStatefulWidget {
  const RecruiterRegistrationScreen({super.key});

  static const int maxHiringProfiles = 10;

  @override
  ConsumerState<RecruiterRegistrationScreen> createState() =>
      _RecruiterRegistrationScreenState();
}

class _RecruiterRegistrationScreenState
    extends ConsumerState<RecruiterRegistrationScreen> {
  final TextEditingController _companyController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _designationController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  final FocusNode _companyFocus = FocusNode();
  final FocusNode _nameFocus = FocusNode();
  final FocusNode _emailFocus = FocusNode();
  final FocusNode _designationFocus = FocusNode();
  final FocusNode _passwordFocus = FocusNode();

  bool _showPassword = false;
  bool _submitted = false;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(registrationProvider).recruiter;
    _companyController.text = draft.companyName;
    _nameController.text = draft.hrName;
    _emailController.text = draft.email;
    _designationController.text = draft.designation;
    _passwordController.text = draft.password;
  }

  @override
  void dispose() {
    _companyController.dispose();
    _nameController.dispose();
    _emailController.dispose();
    _designationController.dispose();
    _passwordController.dispose();
    _companyFocus.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _designationFocus.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _submitted = true);
    FocusScope.of(context).unfocus();

    final controller = ref.read(registrationProvider.notifier);
    final draft = ref.read(registrationProvider).recruiter;

    if (Validators.companyName(draft.companyName) != null) return;
    if (Validators.name(draft.hrName) != null) return;
    if (Validators.email(draft.email) != null) return;
    if (Validators.password(draft.password) != null) return;
    if (draft.hiringProfiles.isEmpty) return;

    final ok = await controller.submitRecruiter();
    if (!mounted || !ok) return;
    context.push(Routes.verifyEmail);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final draft = state.recruiter;
    final controller = ref.read(registrationProvider.notifier);
    final fieldErrors = state.error?.fieldErrors ?? const <String, String>{};

    return TrScaffold(
      title: 'Create Your Hiring Profile',
      subtitle: 'Find relevant professionals around you and build your hiring network.',
      header: const RegistrationProgress(
        step: 1,
        totalSteps: 1,
        label: 'Hiring Profile',
      ),
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PrimaryCta(
            label: 'Create Hiring Profile',
            loadingLabel: 'Creating Profile...',
            isLoading: state.isSubmitting,
            enabled: draft.isSubmittable,
            onPressed: _submit,
          ),
          const SizedBox(height: 6),
          Text(
            draft.isSubmittable
                ? 'Next: verify your email, then set where you are hiring.'
                : 'Company, your name, email and hiring profiles are needed to continue.',
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

          FormSection(
            label: 'Company & contact',
            children: [
              RegistrationTextField(
                label: 'Company Name',
                hint: 'Enter company name',
                controller: _companyController,
                focusNode: _companyFocus,
                isRequired: true,
                validator: Validators.companyName,
                serverError: fieldErrors['companyName'],
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.organizationName],
                prefixIcon: Icons.business_outlined,
                maxLength: 120,
                onChanged: (value) =>
                    controller.updateRecruiter(draft.copyWith(companyName: value)),
                onSubmitted: (_) => _nameFocus.requestFocus(),
              ),
              const SizedBox(height: 18),
              RegistrationTextField(
                label: 'HR / Recruiter Name',
                hint: 'Enter your name',
                controller: _nameController,
                focusNode: _nameFocus,
                isRequired: true,
                validator: Validators.name,
                serverError: fieldErrors['hrName'],
                keyboardType: TextInputType.name,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                prefixIcon: Icons.person_outline_rounded,
                maxLength: 80,
                onChanged: (value) =>
                    controller.updateRecruiter(draft.copyWith(hrName: value)),
                onSubmitted: (_) => _emailFocus.requestFocus(),
              ),
              const SizedBox(height: 18),
              EmailField(
                controller: _emailController,
                role: UserRole.recruiter,
                label: 'Official Email Address',
                hint: 'hr@company.com',
                helper: 'A company address speeds up verification — any address works.',
                serverError: fieldErrors['email'],
                onChanged: (value) =>
                    controller.updateRecruiter(draft.copyWith(email: value)),
                onSubmitted: (_) => _designationFocus.requestFocus(),
                onLoginRequested: () => context.push(Routes.login),
              ),
              const SizedBox(height: 18),
              RegistrationTextField(
                label: 'Your Designation',
                hint: 'e.g. Talent Acquisition Manager',
                helper: 'Optional — shown to candidates you reach out to.',
                controller: _designationController,
                focusNode: _designationFocus,
                textCapitalization: TextCapitalization.words,
                prefixIcon: Icons.badge_outlined,
                maxLength: 80,
                onChanged: (value) =>
                    controller.updateRecruiter(draft.copyWith(designation: value)),
                onSubmitted: (_) => _passwordFocus.requestFocus(),
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
                    controller.updateRecruiter(draft.copyWith(password: value)),
              ),
            ],
          ),
          const SizedBox(height: 28),

          FormSection(
            label: 'What are you hiring for?',
            note: 'Add every role you are hiring for — candidates are matched against these.',
            children: [
              JobTitleSelector(
                label: 'Hiring Profiles',
                hint: 'Search roles you are hiring for...',
                emptyHint: 'Add the roles your company is hiring for.',
                selected: draft.hiringProfiles,
                maxSelection: RecruiterRegistrationScreen.maxHiringProfiles,
                errorText: _submitted && draft.hiringProfiles.isEmpty
                    ? 'Please select at least one hiring profile.'
                    : fieldErrors['jobTitles'],
                onChanged: (titles) =>
                    controller.updateRecruiter(draft.copyWith(hiringProfiles: titles)),
              ),
              const SizedBox(height: 24),
              WorkModeSelector(
                label: 'Work Mode You Offer',
                isRequired: false,
                helper: 'Optional — helps us show you candidates who want the same.',
                selected: draft.hiringWorkModes,
                onChanged: (modes) =>
                    controller.updateRecruiter(draft.copyWith(hiringWorkModes: modes)),
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
                const Icon(Icons.apartment_rounded, size: 18, color: TrColors.plumInk),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    'Next you will set your company hiring location. That is the address candidates see — never your personal whereabouts.',
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
