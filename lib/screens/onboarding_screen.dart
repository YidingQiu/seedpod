library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:solidpod/solidpod.dart';
import 'package:solidui/solidui.dart';

import 'package:seedpod/constants/app.dart' show appServerUri;
import 'package:seedpod/constants/theme.dart';
import 'package:seedpod/models/baby_profile.dart';
import 'package:seedpod/providers/app_state.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key})
      : initialProfile = null,
        isEditing = false;

  const OnboardingScreen.editing({super.key, required this.initialProfile})
      : isEditing = true;

  final BabyProfile? initialProfile;
  final bool isEditing;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _webIdController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedGender;
  bool _isSaving = false;
  bool _podCreated = false;

  @override
  void initState() {
    super.initState();
    if (widget.initialProfile != null) {
      _nameController.text = widget.initialProfile!.name;
      _selectedDate = widget.initialProfile!.dateOfBirth;
      _selectedGender = widget.initialProfile!.gender;
      _webIdController.text = widget.initialProfile!.webId ?? '';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _webIdController.dispose();
    super.dispose();
  }

  Future<void> _createPod() async {
    final created = await createAccountPopup(
      context,
      widget,
      serverUrl: appServerUri,
    );
    if (created && mounted) {
      setState(() => _podCreated = true);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year, now.month, now.day - 30),
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'Select date of birth',
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select the date of birth')),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      if (!await isUserLoggedIn()) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please log in first'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (!mounted) return;
      await getKeyFromUserIfRequired(context, widget);

      final webId = _webIdController.text.trim();
      final profile = BabyProfile(
        id: widget.initialProfile?.id ?? BabyProfile.generateId(),
        name: _nameController.text.trim(),
        dateOfBirth: _selectedDate!,
        gender: _selectedGender,
        webId: webId.isEmpty ? null : webId,
      );

      if (!mounted) return;
      final appState = context.read<AppState>();
      final ok = widget.isEditing
          ? await appState.updateBaby(profile)
          : await appState.addBaby(profile);

      if (!mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to save profile. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      if (widget.isEditing || Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    } on NotLoggedInException {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please log in to save your baby profile'),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showCreateAppBar =
        !widget.isEditing && Navigator.of(context).canPop();

    return Scaffold(
      backgroundColor: colorBg,
      appBar: showCreateAppBar
          ? AppBar(
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              ),
              title: const Text('Create Baby Profile'),
            )
          : null,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 32),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: const BoxDecoration(
                          color: colorPrimary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.child_care,
                          size: 44,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      widget.isEditing
                          ? 'Edit Baby Profile'
                          : 'Welcome to SeedPod',
                      style: Theme.of(context).textTheme.headlineLarge,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      widget.isEditing
                          ? 'Update your baby details below.'
                          : 'Your private baby tracker. All data stays on your Solid POD.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    if (!widget.isEditing) ...[
                      _PodSetupCard(
                        podCreated: _podCreated,
                        onCreatePod: _createPod,
                      ),
                      const SizedBox(height: 24),
                    ],
                    Text(
                      "Baby's name",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        hintText: 'Enter your baby\'s name',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Name is required'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Date of birth',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(radiusMedium),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 14,
                        ),
                        decoration: BoxDecoration(
                          color: colorCard,
                          border: Border.all(color: colorDivider),
                          borderRadius: BorderRadius.circular(radiusMedium),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              color: colorSecondary,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              _selectedDate == null
                                  ? 'Select date'
                                  : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
                              style: TextStyle(
                                color: _selectedDate == null
                                    ? colorSecondary
                                    : colorText,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Gender (optional)',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final g in ['Boy', 'Girl', 'Other'])
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: ChoiceChip(
                              label: Text(g),
                              selected: _selectedGender == g,
                              selectedColor:
                                  colorPrimary.withValues(alpha: 0.15),
                              onSelected: (selected) {
                                setState(() {
                                  _selectedGender = selected ? g : null;
                                });
                              },
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      "Baby's Solid WebID (optional)",
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _webIdController,
                      decoration: const InputDecoration(
                        hintText:
                            'https://pods.d01.solidcommunity.au/babyname/profile/card#me',
                        prefixIcon: Icon(Icons.link),
                      ),
                      keyboardType: TextInputType.url,
                    ),
                    const SizedBox(height: 40),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _save,
                        child: _isSaving
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.isEditing
                                    ? 'Save Changes'
                                    : 'Create Baby Profile',
                              ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PodSetupCard extends StatelessWidget {
  final bool podCreated;
  final VoidCallback onCreatePod;

  const _PodSetupCard({required this.podCreated, required this.onCreatePod});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: podCreated
            ? Colors.green.withValues(alpha: 0.08)
            : colorPrimary.withValues(alpha: 0.06),
        border: Border.all(
          color: podCreated ? Colors.green : colorPrimary.withValues(alpha: 0.3),
        ),
        borderRadius: BorderRadius.circular(radiusMedium),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                podCreated ? Icons.check_circle : Icons.cloud_outlined,
                color: podCreated ? Colors.green : colorPrimary,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                podCreated ? 'Solid POD created' : 'Create a Solid POD for your baby',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: podCreated ? Colors.green : colorPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            podCreated
                ? 'Account created on $appServerUri. Enter the baby\'s WebID below.'
                : 'Give your baby their own private Solid POD — a personal data store they\'ll own forever.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          if (!podCreated) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onCreatePod,
              icon: const Icon(Icons.add_circle_outline, size: 18),
              label: const Text('Create Solid POD'),
            ),
          ],
        ],
      ),
    );
  }
}
