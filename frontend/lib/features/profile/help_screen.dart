import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_theme.dart';
import '../../core/theme/tr_typography.dart';
import '../../state/session_controller.dart';
import '../../widgets/tr_components.dart';

/// Help Center. The answers people actually ask us about — privacy, being
/// found, walk-ins — written out rather than linked to a website that does not
/// exist yet.
class HelpScreen extends ConsumerWidget {
  const HelpScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCandidate = ref.watch(sessionProvider)?.isCandidate ?? true;
    final entries = isCandidate ? _candidateHelp : _recruiterHelp;

    return Scaffold(
      backgroundColor: TrColors.canvas,
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(22, 8, 22, 28),
        children: [
          Text(
            isCandidate
                ? 'How being found on TalentRadar works'
                : 'How finding people on TalentRadar works',
            style: TrType.sectionTitle,
          ),
          const SizedBox(height: 16),
          for (final (question, answer) in entries) ...[
            _Faq(question: question, answer: answer),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 14),
          Text('SOMETHING WRONG?', style: TrType.eyebrow),
          const SizedBox(height: 10),
          const InfoNote(
            text:
                'Report a profile or a role from the ⋯ menu on it. Blocking someone is in Privacy → Blocked accounts, and can be undone at any time.',
          ),
        ],
      ),
    );
  }
}

const _candidateHelp = <(String, String)>[
  (
    'Who can see my profile?',
    'Only the audience you choose in Privacy. "Recruiters only" is the default: other candidates cannot browse you. '
        'Stealth mode hides you from discovery entirely, and setting "Not looking" switches it on for you.',
  ),
  (
    'Does anyone see where I live?',
    'No. Your exact location never leaves the app. What others see is an approximate point inside a 2 km privacy '
        'radius, the name of your area, and a distance rounded to the nearest half kilometre — never coordinates, '
        'and never an address.',
  ),
  (
    'What does "I\'m available today" do?',
    'It puts a lime dot on your card until midnight, so recruiters nearby know you can talk or attend a walk-in '
        'today. It clears itself — you never have to remember to switch it off.',
  ),
  (
    'Can recruiters message me without asking?',
    'A recruiter can message you only if you are discoverable to them and "Open to connect" is on. Turn that off '
        'and you can still be found, but only connections can write to you.',
  ),
  (
    'What is a walk-in?',
    'An open interview on a set day — no application first. The role card shows the date, times and address. '
        'Save it and you get a reminder two hours before.',
  ),
  (
    'How do I find who is hiring for my role?',
    'Search your role and switch to the Companies or Recruiters tab. Each result shows whether they are hiring '
        'right now and how many openings there are. "Hiring now" comes from live job posts, so it is never stale.',
  ),
];

const _recruiterHelp = <(String, String)>[
  (
    'Why can I not see some candidates?',
    'Candidates control their own visibility. Someone in stealth mode, set to "Not looking", or limited to '
        'connections will not appear in your search or radar. This is deliberate and cannot be overridden.',
  ),
  (
    'What location do candidates see for me?',
    'Your company hiring location, never your own whereabouts — TalentRadar does not collect them. Jobs you post '
        'carry that same business address.',
  ),
  (
    'How does "Hiring now" work?',
    'It is worked out from your open roles. Post a role and the title shows as hiring with its openings; close it '
        'and the title stops showing as active everywhere at once. There is no separate switch to forget.',
  ),
  (
    'A candidate does not reply — can I message again?',
    'You can, but consider a connection request with a note instead. Candidates who turn off "Open to connect" '
        'can only be reached that way.',
  ),
  (
    'How do interview invites work?',
    'Send one from a chat. The candidate can accept, ask to reschedule or decline, and the answer appears in the '
        'same conversation, so the arrangement stays in one place.',
  ),
];

class _Faq extends StatefulWidget {
  const _Faq({required this.question, required this.answer});

  final String question;
  final String answer;

  @override
  State<_Faq> createState() => _FaqState();
}

class _FaqState extends State<_Faq> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: TrColors.card,
      borderRadius: TrRadius.cardR,
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: TrRadius.cardR,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.question,
                      style: TrType.itemTitle.copyWith(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _open ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                    color: TrColors.icon,
                  ),
                ],
              ),
              if (_open) ...[
                const SizedBox(height: 10),
                Text(
                  widget.answer,
                  style: TrType.bodySmall.copyWith(color: TrColors.plumInk, height: 1.55),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
