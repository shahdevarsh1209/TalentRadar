import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/network/api_exception.dart';
import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';
import '../core/utils/debouncer.dart';
import '../core/utils/validators.dart';
import '../data/models/enums.dart';
import '../state/providers.dart';
import 'registration_text_field.dart';

enum _EmailStatus { idle, checking, available, taken, takenOtherRole }

/// Email input that asks the API whether the address is free while the user is
/// still on the form, so "an account already exists" arrives before the CTA is
/// pressed rather than after. The check is advisory — the server re-checks on
/// submit, and a failed check never blocks registration.
class EmailField extends ConsumerStatefulWidget {
  const EmailField({
    super.key,
    required this.controller,
    required this.role,
    this.label = 'Email Address',
    this.hint = 'you@example.com',
    this.helper,
    this.serverError,
    this.onChanged,
    this.onSubmitted,
    this.onLoginRequested,
    this.textInputAction = TextInputAction.next,
  });

  final TextEditingController controller;
  final UserRole role;
  final String label;
  final String hint;
  final String? helper;
  final String? serverError;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Offered when the address already has an account.
  final VoidCallback? onLoginRequested;
  final TextInputAction textInputAction;

  @override
  ConsumerState<EmailField> createState() => _EmailFieldState();
}

class _EmailFieldState extends ConsumerState<EmailField> {
  final Debouncer _debouncer = Debouncer(const Duration(milliseconds: 500));
  _EmailStatus _status = _EmailStatus.idle;
  String? _message;
  String _lastChecked = '';

  @override
  void dispose() {
    _debouncer.dispose();
    super.dispose();
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    final trimmed = value.trim();

    if (_status != _EmailStatus.idle) {
      setState(() {
        _status = _EmailStatus.idle;
        _message = null;
      });
    }

    // Only worth a round trip once it could actually be an address.
    if (Validators.email(trimmed) != null) {
      _debouncer.cancel();
      return;
    }
    _debouncer.run(() => _check(trimmed));
  }

  Future<void> _check(String email) async {
    if (!mounted || email == _lastChecked) return;
    _lastChecked = email;
    setState(() => _status = _EmailStatus.checking);

    try {
      final result = await ref.read(authRepositoryProvider).checkEmail(email);
      if (!mounted) return;

      if (result.available) {
        setState(() {
          _status = _EmailStatus.available;
          // Advisory nudge for recruiters on a free mail domain — never a block.
          _message = widget.role == UserRole.recruiter && !result.isOfficialDomain
              ? 'A company email helps recruiters get verified faster. Personal addresses still work.'
              : null;
        });
      } else {
        final sameRole = result.existingRole == widget.role.wire;
        setState(() {
          _status = sameRole ? _EmailStatus.taken : _EmailStatus.takenOtherRole;
          _message = sameRole
              ? 'An account already exists with this email.'
              : 'This email is already registered as ${result.existingRole == 'candidate' ? 'a candidate' : 'an HR / recruiter'} account.';
        });
      }
    } on ApiException {
      // Availability is a convenience; staying quiet is better than a scare.
      if (mounted) setState(() => _status = _EmailStatus.idle);
    }
  }

  Widget? get _suffix => switch (_status) {
        _EmailStatus.checking => const Padding(
            padding: EdgeInsets.all(15),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2, color: TrColors.icon),
            ),
          ),
        _EmailStatus.available =>
          const Icon(Icons.check_circle_rounded, color: TrColors.limeText, size: 20),
        _EmailStatus.taken || _EmailStatus.takenOtherRole =>
          const Icon(Icons.error_rounded, color: TrColors.clay, size: 20),
        _EmailStatus.idle => null,
      };

  @override
  Widget build(BuildContext context) {
    final bool isTaken =
        _status == _EmailStatus.taken || _status == _EmailStatus.takenOtherRole;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        RegistrationTextField(
          label: widget.label,
          controller: widget.controller,
          hint: widget.hint,
          helper: widget.helper,
          isRequired: true,
          validator: Validators.email,
          serverError: widget.serverError,
          keyboardType: TextInputType.emailAddress,
          textInputAction: widget.textInputAction,
          autofillHints: const [AutofillHints.email],
          prefixIcon: Icons.alternate_email_rounded,
          suffix: _suffix,
          onChanged: _handleChanged,
          onSubmitted: widget.onSubmitted,
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isTaken ? TrColors.claySurface : TrColors.plumSurface,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isTaken ? Icons.info_rounded : Icons.lightbulb_outline_rounded,
                        size: 17,
                        color: isTaken ? TrColors.clayText : TrColors.plumInk,
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          _message!,
                          style: TrType.itemMeta.copyWith(
                            color: isTaken ? TrColors.clayText : TrColors.plumInk,
                            height: 1.45,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (isTaken && widget.onLoginRequested != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Row(
                        children: [
                          TextButton(
                            onPressed: widget.onLoginRequested,
                            style: TextButton.styleFrom(
                              foregroundColor: TrColors.clayText,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(
                              'Log in',
                              style: TrType.chip.copyWith(color: TrColors.clayText),
                            ),
                          ),
                          TextButton(
                            onPressed: widget.onLoginRequested,
                            style: TextButton.styleFrom(
                              foregroundColor: TrColors.clayText,
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: const Size(0, 40),
                            ),
                            child: Text(
                              'Forgot password?',
                              style: TrType.chip.copyWith(color: TrColors.clayText),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

