import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';

/// Labelled input used by both registration forms.
///
/// Validation is deliberately late: a field reports a problem when it loses
/// focus or when the form is submitted, never while the first characters are
/// still being typed.
class RegistrationTextField extends StatefulWidget {
  const RegistrationTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.helper,
    this.validator,
    this.serverError,
    this.isRequired = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.next,
    this.textCapitalization = TextCapitalization.none,
    this.autofillHints,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.maxLength,
    this.prefixIcon,
    this.suffix,
    this.obscure = false,
  });

  final String label;
  final TextEditingController controller;
  final String? hint;
  final String? helper;
  final String? Function(String?)? validator;

  /// A message from the API for this field; outranks local validation.
  final String? serverError;
  final bool isRequired;
  final TextInputType? keyboardType;
  final TextInputAction textInputAction;
  final TextCapitalization textCapitalization;
  final Iterable<String>? autofillHints;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final int? maxLength;
  final IconData? prefixIcon;
  final Widget? suffix;
  final bool obscure;

  @override
  State<RegistrationTextField> createState() => _RegistrationTextFieldState();
}

class _RegistrationTextFieldState extends State<RegistrationTextField> {
  late final FocusNode _focusNode = widget.focusNode ?? FocusNode();
  bool _ownsFocusNode = false;
  bool _touched = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _ownsFocusNode = widget.focusNode == null;
    _focusNode.addListener(_onFocusChange);
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocusChange);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Validate on blur — the moment the user has finished with the field.
    if (!_focusNode.hasFocus && widget.controller.text.isNotEmpty) {
      setState(() {
        _touched = true;
        _error = widget.validator?.call(widget.controller.text);
      });
    }
  }

  void _handleChanged(String value) {
    widget.onChanged?.call(value);
    // Once a field has shown an error, correct it live so the fix is visible.
    if (_touched && _error != null) {
      final next = widget.validator?.call(value);
      if (next != _error) setState(() => _error = next);
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? shownError = widget.serverError ?? (_touched ? _error : null);
    final bool hasError = shownError != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 7),
          child: RichText(
            text: TextSpan(
              text: widget.label,
              style: TrType.label,
              children: [
                if (widget.isRequired)
                  TextSpan(
                    text: ' *',
                    style: TrType.label.copyWith(color: TrColors.clay),
                  ),
              ],
            ),
          ),
        ),
        TextField(
          controller: widget.controller,
          focusNode: _focusNode,
          enabled: widget.enabled,
          keyboardType: widget.keyboardType,
          textInputAction: widget.textInputAction,
          textCapitalization: widget.textCapitalization,
          autofillHints: widget.autofillHints,
          obscureText: widget.obscure,
          maxLength: widget.maxLength,
          style: TrType.bodyText.copyWith(fontSize: 14.5),
          cursorColor: TrColors.plumInk,
          inputFormatters: widget.maxLength != null
              ? [LengthLimitingTextInputFormatter(widget.maxLength)]
              : null,
          onChanged: _handleChanged,
          onSubmitted: (value) {
            setState(() {
              _touched = true;
              _error = widget.validator?.call(value);
            });
            widget.onSubmitted?.call(value);
          },
          decoration: InputDecoration(
            hintText: widget.hint,
            counterText: '',
            errorText: hasError ? shownError : null,
            prefixIcon: widget.prefixIcon == null
                ? null
                : Icon(widget.prefixIcon, size: 19, color: TrColors.icon),
            suffixIcon: widget.suffix,
          ),
        ),
        if (widget.helper != null && !hasError)
          Padding(
            padding: const EdgeInsets.only(top: 6, left: 4),
            child: Text(
              widget.helper!,
              style: TrType.itemMeta.copyWith(fontSize: 11.5),
            ),
          ),
      ],
    );
  }
}
