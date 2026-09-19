import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/theme/tr_colors.dart';
import '../core/theme/tr_typography.dart';

/// Six-box verification code entry.
///
/// A single hidden field holds the value, so paste, SMS autofill and backspace
/// all behave normally; the boxes are painted from that value.
class OtpInput extends StatefulWidget {
  const OtpInput({
    super.key,
    required this.controller,
    this.length = 6,
    this.hasError = false,
    this.enabled = true,
    this.onCompleted,
    this.onChanged,
  });

  final TextEditingController controller;
  final int length;
  final bool hasError;
  final bool enabled;
  final ValueChanged<String>? onCompleted;
  final ValueChanged<String>? onChanged;

  @override
  State<OtpInput> createState() => _OtpInputState();
}

class _OtpInputState extends State<OtpInput> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onValueChanged);
    _focusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onValueChanged);
    _focusNode.dispose();
    super.dispose();
  }

  void _onValueChanged() {
    setState(() {});
    final value = widget.controller.text;
    widget.onChanged?.call(value);
    if (value.length == widget.length) {
      _focusNode.unfocus();
      widget.onCompleted?.call(value);
    }
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.controller.text;

    return Semantics(
      label: 'Verification code, ${widget.length} digits',
      textField: true,
      child: Stack(
        children: [
          // The real field sits behind the boxes, invisible but focusable.
          Opacity(
            opacity: 0,
            child: TextField(
              controller: widget.controller,
              focusNode: _focusNode,
              enabled: widget.enabled,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              maxLength: widget.length,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(widget.length),
              ],
            ),
          ),
          GestureDetector(
            onTap: widget.enabled ? () => _focusNode.requestFocus() : null,
            behavior: HitTestBehavior.opaque,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (index) {
                final bool filled = index < value.length;
                final bool isNext = index == value.length && _focusNode.hasFocus;

                return Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: index == widget.length - 1 ? 0 : 9),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 140),
                      height: 60,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: TrColors.card,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(
                          color: widget.hasError
                              ? TrColors.error
                              : isNext
                                  ? TrColors.plumInk
                                  : filled
                                      ? TrColors.plumInk
                                      : TrColors.border,
                          width: isNext || filled ? 1.9 : 1,
                        ),
                      ),
                      child: Text(
                        filled ? value[index] : '',
                        style: TrType.stat.copyWith(fontSize: 22),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}
