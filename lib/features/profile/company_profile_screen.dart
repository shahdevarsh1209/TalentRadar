import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/network/api_exception.dart';
import '../../core/theme/tr_colors.dart';
import '../../core/theme/tr_typography.dart';
import '../../data/models/people.dart';
import '../../state/home_providers.dart';
import '../../state/session_controller.dart';
import '../../widgets/error_message.dart';
import '../../widgets/option_selectors.dart';
import '../../widgets/primary_cta.dart';
import '../../widgets/registration_text_field.dart';
import '../../widgets/tr_components.dart';
import '../../widgets/tr_scaffold.dart';

final _companyProvider = FutureProvider.autoDispose<CompanyDetails>(
  (ref) => ref.watch(peopleRepositoryProvider).myCompany(),
);

/// Company profile completion — the fields deliberately left out of registration.
class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final company = ref.watch(_companyProvider);
    return company.hasValue
        ? _CompanyForm(company: company.requireValue)
        : Scaffold(
            backgroundColor: TrColors.canvas,
            appBar: AppBar(title: const Text('Company profile')),
            body: AsyncSection<CompanyDetails>(
              value: company,
              onRetry: () => ref.invalidate(_companyProvider),
              builder: (_) => const SizedBox.shrink(),
              loading: const Center(child: CircularProgressIndicator(color: TrColors.plumInk)),
            ),
          );
  }
}

class _CompanyForm extends ConsumerStatefulWidget {
  const _CompanyForm({required this.company});

  final CompanyDetails company;

  @override
  ConsumerState<_CompanyForm> createState() => _CompanyFormState();
}

class _CompanyFormState extends ConsumerState<_CompanyForm> {
  static const _sizes = ['1-10', '11-50', '51-200', '201-500', '501-1000', '1000+'];
  static const _industries = [
    'Software', 'Customer Experience', 'Financial Services', 'Retail & E-commerce',
    'Manufacturing', 'Healthcare', 'Education', 'Logistics', 'Hospitality', 'Other',
  ];

  late final _description = TextEditingController(text: widget.company.description);
  late final _website = TextEditingController(text: widget.company.website);
  late final _linkedin = TextEditingController(text: widget.company.linkedinUrl);
  late String _industry = widget.company.industry;
  late String _size = widget.company.size;

  bool _saving = false;
  ApiException? _error;

  @override
  void dispose() {
    _description.dispose();
    _website.dispose();
    _linkedin.dispose();
    super.dispose();
  }

  static String? _url(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return null;
    return RegExp(r'^https?://\S+\.\S+').hasMatch(text) ? null : 'Enter a full address, like https://abc.com';
  }

  Future<void> _save() async {
    if (_saving || _url(_website.text) != null || _url(_linkedin.text) != null) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final result = await ref.read(peopleRepositoryProvider).updateCompany(
            description: _description.text.trim(),
            industry: _industry,
            size: _size,
            website: _website.text.trim(),
            linkedinUrl: _linkedin.text.trim(),
          );
      ref.read(sessionProvider.notifier).update(result.session);
      if (!mounted) return;
      showTrSnack(context, 'Company profile saved.');
      context.pop();
    } on ApiException catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return TrScaffold(
      title: widget.company.name,
      subtitle: 'Candidates see this when they open one of your roles. A complete profile earns more replies.',
      footer: PrimaryCta(label: 'Save company profile', loadingLabel: 'Saving…', isLoading: _saving, onPressed: _save),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            ErrorMessage(error: _error!, onDismiss: () => setState(() => _error = null)),
            const SizedBox(height: 18),
          ],
          Text('About the company', style: TrType.label),
          const SizedBox(height: 7),
          TextField(
            controller: _description,
            maxLines: 4,
            maxLength: 1000,
            decoration: const InputDecoration(hintText: 'What you do, and what it is like to work with you.'),
          ),
          const SizedBox(height: 18),
          Text('Industry', style: TrType.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final industry in {..._industries, if (_industry.isNotEmpty) _industry})
                ChoicePill(label: industry, selected: _industry == industry, onTap: () => setState(() => _industry = industry)),
            ],
          ),
          const SizedBox(height: 22),
          Text('Company size', style: TrType.label),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final size in _sizes)
                ChoicePill(label: '$size people', selected: _size == size, onTap: () => setState(() => _size = size)),
            ],
          ),
          const SizedBox(height: 22),
          RegistrationTextField(
            label: 'Website',
            hint: 'https://yourcompany.com',
            controller: _website,
            keyboardType: TextInputType.url,
            validator: _url,
            prefixIcon: Icons.language_rounded,
          ),
          const SizedBox(height: 18),
          RegistrationTextField(
            label: 'LinkedIn page',
            hint: 'https://linkedin.com/company/…',
            controller: _linkedin,
            keyboardType: TextInputType.url,
            validator: _url,
            prefixIcon: Icons.link_rounded,
          ),
          const SizedBox(height: 18),
          InfoNote(
            icon: widget.company.verificationStatus == 'verified' ? Icons.verified_outlined : Icons.shield_outlined,
            text: widget.company.verificationStatus == 'verified'
                ? 'Your company is verified.'
                : 'Company verification is reviewed by the TalentRadar team. A company email address and a complete profile speed it up.',
          ),
        ],
      ),
    );
  }
}
