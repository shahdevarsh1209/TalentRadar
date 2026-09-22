import 'package:flutter/material.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../core/utils/formatters.dart';
import '../../data/models/chat.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_text_field.dart';

class InviteDraft {
  const InviteDraft({
    required this.title,
    required this.round,
    required this.scheduledAt,
    required this.mode,
    required this.location,
  });

  final String title;
  final String round;
  final DateTime scheduledAt;
  final InterviewMode mode;
  final String location;
}

/// Recruiter's interview-invite form, returned to the chat as an [InviteDraft].
class InviteComposerSheet extends StatefulWidget {
  const InviteComposerSheet({super.key});

  @override
  State<InviteComposerSheet> createState() => _InviteComposerSheetState();
}

class _InviteComposerSheetState extends State<InviteComposerSheet> {
  final _title = TextEditingController();
  final _round = TextEditingController(text: 'Round 1');
  final _location = TextEditingController();
  InterviewMode _mode = InterviewMode.inPerson;
  DateTime _when = _defaultTime();

  static DateTime _defaultTime() {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return DateTime(tomorrow.year, tomorrow.month, tomorrow.day, 11);
  }

  @override
  void dispose() {
    _title.dispose();
    _round.dispose();
    _location.dispose();
    super.dispose();
  }

  bool get _valid => _title.text.trim().length >= 2 && _when.isAfter(DateTime.now());

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _when,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: now.add(const Duration(days: 90)),
    );
    if (picked != null) {
      setState(() => _when = DateTime(picked.year, picked.month, picked.day, _when.hour, _when.minute));
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_when));
    if (picked != null) {
      setState(() => _when = DateTime(_when.year, _when.month, _when.day, picked.hour, picked.minute));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(color: TrColors.borderStrong, borderRadius: BorderRadius.circular(2)),
              ),
            ),
            const SizedBox(height: 20),
            Text('Interview invite', style: TrType.sectionTitle),
            const SizedBox(height: 6),
            Text('They can accept or ask to reschedule from the chat.', style: TrType.bodySmall),
            const SizedBox(height: 20),
            RegistrationTextField(
              label: 'Role',
              hint: 'e.g. Customer Support Executive',
              controller: _title,
              isRequired: true,
              maxLength: 120,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            RegistrationTextField(label: 'Round', controller: _round, maxLength: 60),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _Picker(label: 'Date', value: Fmt.day(_when), icon: Icons.calendar_today_rounded, onTap: _pickDate),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Picker(label: 'Time', value: Fmt.time(_when), icon: Icons.schedule_rounded, onTap: _pickTime),
                ),
              ],
            ),
            if (!_when.isAfter(DateTime.now()))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text('Pick a time in the future.', style: TrType.itemMeta.copyWith(color: TrColors.error)),
              ),
            const SizedBox(height: 16),
            Text('How', style: TrType.label),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final mode in InterviewMode.values)
                  ChoicePill(label: mode.label, selected: _mode == mode, onTap: () => setState(() => _mode = mode)),
              ],
            ),
            const SizedBox(height: 16),
            RegistrationTextField(
              label: _mode == InterviewMode.inPerson ? 'Where' : 'Link or number',
              hint: _mode == InterviewMode.inPerson ? 'e.g. Koramangala office, 3rd floor' : 'Shared closer to the time',
              controller: _location,
              maxLength: 200,
            ),
            const SizedBox(height: 24),
            PrimaryCta(
              label: 'Send invite',
              enabled: _valid,
              onPressed: () => Navigator.of(context).pop(
                InviteDraft(
                  title: _title.text.trim(),
                  round: _round.text.trim().isEmpty ? 'Round 1' : _round.text.trim(),
                  scheduledAt: _when,
                  mode: _mode,
                  location: _location.text.trim(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.label, required this.value, required this.icon, required this.onTap});

  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
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
    );
  }
}
