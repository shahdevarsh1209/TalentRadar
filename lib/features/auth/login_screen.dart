import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../state/providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_text_field.dart';
import '../../widgets/tr_scaffold.dart';

/// Sign-in methods the screen can offer. Only [password] is wired today; the
/// others are listed so adding a provider is a new case here, not a redesign.
enum AuthMethod { password, emailOtp, google, phone }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();

  UserRole _role = UserRole.candidate;
  bool _showPassword = false;
  bool _loading = false;
  ApiException? _error;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  bool get _canSubmit =>
      Validators.email(_emailController.text) == null &&
      _passwordController.text.isNotEmpty;

  Future<void> _submit() async {
    if (!_canSubmit || _loading) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final session = await ref.read(authRepositoryProvider).login(
            email: _emailController.text.trim(),
            password: _passwordController.text,
            role: _role.wire,
          );
      await ref.read(sessionProvider.notifier).adopt(session);
      if (!mounted) return;
      context.go(Routes.radar);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _comingSoon(AuthMethod method) {
    final name = switch (method) {
      AuthMethod.google => 'Google sign-in',
      AuthMethod.phone => 'Phone OTP',
      AuthMethod.emailOtp => 'Email code sign-in',
      AuthMethod.password => 'Password sign-in',
    };
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('$name is coming soon. Use your email and password for now.')));
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    final roleConflictRole =
        error != null && error.isRoleConflict ? UserRole.fromWire(error.existingRole) : null;

    return TrScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Tab(label: 'Log in', active: true, onTap: () {}),
              const SizedBox(width: 26),
              _Tab(
                label: 'Sign up',
                active: false,
                onTap: () => context.pushReplacement(Routes.chooseRole),
              ),
            ],
          ),
          const Divider(height: 1),
          const SizedBox(height: 26),
          Text('CONTINUE AS', style: TrType.eyebrow),
          const SizedBox(height: 12),
          for (final role in UserRole.values) ...[
            _RoleRow(
              role: role,
              selected: _role == role,
              onTap: () => setState(() {
                _role = role;
                _error = null;
              }),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 16),
          if (error != null) ...[
            ErrorMessage(
              error: error,
              onRetry: _submit,
              onDismiss: () => setState(() => _error = null),
            ),
            if (roleConflictRole != null) ...[
              const SizedBox(height: 4),
              TrTextAction(
                label: 'Continue as ${roleConflictRole.label} instead',
                onPressed: () {
                  setState(() {
                    _role = roleConflictRole;
                    _error = null;
                  });
                  _submit();
                },
              ),
            ],
            const SizedBox(height: 16),
          ],
          RegistrationTextField(
            label: 'Email',
            hint: 'you@example.com',
            controller: _emailController,
            validator: Validators.email,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email, AutofillHints.username],
            prefixIcon: Icons.alternate_email_rounded,
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _passwordFocus.requestFocus(),
          ),
          const SizedBox(height: 16),
          RegistrationTextField(
            label: 'Password',
            hint: 'Your password',
            controller: _passwordController,
            focusNode: _passwordFocus,
            obscure: !_showPassword,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.password],
            prefixIcon: Icons.lock_outline_rounded,
            suffix: IconButton(
              icon: Icon(
                _showPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                size: 19,
                color: TrColors.icon,
              ),
              tooltip: _showPassword ? 'Hide password' : 'Show password',
              onPressed: () => setState(() => _showPassword = !_showPassword),
            ),
            onChanged: (_) => setState(() {}),
            onSubmitted: (_) => _submit(),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TrTextAction(
              label: 'Forgot password?',
              color: TrColors.clayText,
              onPressed: () => _comingSoon(AuthMethod.emailOtp),
            ),
          ),
          const SizedBox(height: 8),
          PrimaryCta(
            label: 'Continue as ${_role == UserRole.candidate ? 'candidate' : 'recruiter'}',
            loadingLabel: 'Signing in...',
            isLoading: _loading,
            enabled: _canSubmit,
            onPressed: _submit,
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              const Expanded(child: Divider()),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('or', style: TrType.itemMeta),
              ),
              const Expanded(child: Divider()),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: PrimaryCta(
                  label: 'Google',
                  variant: CtaVariant.outline,
                  onPressed: () => _comingSoon(AuthMethod.google),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PrimaryCta(
                  label: 'Phone OTP',
                  variant: CtaVariant.outline,
                  onPressed: () => _comingSoon(AuthMethod.phone),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.label, required this.active, required this.onTap});

  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: active ? TrColors.plumInk : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Text(
          label,
          style: TrType.sectionTitle.copyWith(
            fontSize: 19,
            color: active ? TrColors.plumInk : TrColors.icon,
          ),
        ),
      ),
    );
  }
}

class _RoleRow extends StatelessWidget {
  const _RoleRow({required this.role, required this.selected, required this.onTap});

  final UserRole role;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bool isCandidate = role == UserRole.candidate;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: TrColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? TrColors.plumInk : TrColors.border,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isCandidate ? TrColors.limeSurface : TrColors.plumSurface,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isCandidate ? Icons.person_outline_rounded : Icons.business_center_outlined,
                  size: 20,
                  color: isCandidate ? TrColors.limeText : TrColors.plumInk,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(role.label, style: TrType.itemTitle.copyWith(fontSize: 14.5)),
                    Text(
                      isCandidate ? 'Find work and events nearby' : 'Hire from your own area',
                      style: TrType.itemMeta,
                    ),
                  ],
                ),
              ),
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected ? TrColors.plumInk : Colors.transparent,
                  border: selected ? null : Border.all(color: TrColors.borderStrong, width: 1.5),
                ),
                child: selected
                    ? const Icon(Icons.check_rounded, size: 13, color: TrColors.lime)
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

