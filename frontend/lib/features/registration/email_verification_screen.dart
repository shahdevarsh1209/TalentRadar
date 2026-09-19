import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/validators.dart';
import '../../data/models/enums.dart';
import '../../state/registration_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/otp_input.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/tr_scaffold.dart';

/// "Verify Your Email" — six digits, a resend countdown and a way back to the
/// email field. The API is real; only mail delivery is stubbed, so swapping in
/// a provider needs no change here.
class EmailVerificationScreen extends ConsumerStatefulWidget {
  const EmailVerificationScreen({super.key});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends ConsumerState<EmailVerificationScreen> {
  final TextEditingController _codeController = TextEditingController();

  Timer? _ticker;
  int _secondsLeft = 0;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    final challenge = ref.read(registrationProvider).challenge;
    _startCountdown(challenge?.resendAfterSeconds ?? 45);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _codeController.dispose();
    super.dispose();
  }

  void _startCountdown(int seconds) {
    _ticker?.cancel();
    setState(() => _secondsLeft = seconds);
    _ticker = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft <= 1) {
        timer.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft -= 1);
      }
    });
  }

  Future<void> _verify() async {
    final code = _codeController.text.trim();
    if (Validators.otp(code) != null) {
      setState(() => _hasError = true);
      return;
    }

    setState(() => _hasError = false);
    final ok = await ref.read(registrationProvider.notifier).verifyEmail(code);
    if (!mounted) return;

    if (!ok) {
      setState(() => _hasError = true);
      _codeController.clear();
      return;
    }

    final role = ref.read(registrationProvider).role;
    context.push(
      role == UserRole.recruiter ? Routes.hiringLocation : Routes.candidateLocation,
    );
  }

  Future<void> _resend() async {
    final ok = await ref.read(registrationProvider.notifier).resendCode();
    if (!mounted) return;

    final challenge = ref.read(registrationProvider).challenge;
    _startCountdown(challenge?.resendAfterSeconds ?? 45);

    if (ok) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('We sent a new code to your email.')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(registrationProvider);
    final session = ref.watch(sessionProvider);
    final email = session?.user.email ?? '';
    final devCode = state.challenge?.devCode;

    return TrScaffold(
      title: 'Verify Your Email',
      subtitle: 'Enter the verification code sent to your email.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TrCard(
            color: TrColors.plumSurface,
            borderColor: TrColors.plumSurface,
            child: Row(
              children: [
                const Icon(Icons.mark_email_unread_outlined,
                    size: 19, color: TrColors.plumInk),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Code sent to', style: TrType.itemMeta.copyWith(fontSize: 11.5)),
                      const SizedBox(height: 2),
                      Text(email, style: TrType.itemTitle.copyWith(fontSize: 14)),
                    ],
                  ),
                ),
                TrTextAction(
                  label: 'Change',
                  onPressed: () {
                    ref.read(registrationProvider.notifier).changeEmail();
                    context.pop();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 26),
          OtpInput(
            controller: _codeController,
            hasError: _hasError,
            enabled: !state.isSubmitting,
            // Rebuilds so the CTA enables the moment six digits are in.
            onChanged: (_) => setState(() => _hasError = false),
            onCompleted: (_) => _verify(),
          ),
          const SizedBox(height: 18),
          if (state.error != null)
            ErrorMessage(
              error: state.error!,
              onRetry: _verify,
              onDismiss: () => ref.read(registrationProvider.notifier).clearError(),
            ),
          if (devCode != null) ...[
            const SizedBox(height: 14),
            TrCard(
              color: TrColors.limeSurface,
              borderColor: TrColors.limeSurface,
              padding: const EdgeInsets.all(13),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded, size: 17, color: TrColors.limeText),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Development build — your code is $devCode.',
                      style: TrType.itemMeta.copyWith(color: TrColors.limeText),
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 24),
          PrimaryCta(
            label: 'Verify & Continue',
            loadingLabel: 'Verifying...',
            isLoading: state.isSubmitting,
            enabled: _codeController.text.trim().length == 6,
            onPressed: _verify,
          ),
          const SizedBox(height: 16),
          Center(
            child: _secondsLeft > 0
                ? Text(
                    'Resend code in ${_secondsLeft}s',
                    style: TrType.bodySmall.copyWith(fontSize: 13),
                  )
                : Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text("Didn't get it?", style: TrType.bodySmall.copyWith(fontSize: 13)),
                      TrTextAction(label: 'Resend code', onPressed: _resend),
                    ],
                  ),
          ),
          const SizedBox(height: 22),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.schedule_rounded, size: 16, color: TrColors.icon),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  'Codes expire after 10 minutes. Check your spam folder if it has not arrived.',
                  style: TrType.itemMeta.copyWith(fontSize: 11.5, height: 1.45),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
