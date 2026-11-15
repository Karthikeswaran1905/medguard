import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Add Doctor (MedGuardian screen spec A3) — a dedicated screen rather
/// than the small dialog Doctor/Incharge still use for provisioning the
/// next role down, per the finalized spec's explicit "Add Doctor" screen.
/// Creates the account with `PeopleRepository.createStaffAccount`
/// (entirely client-side on the Spark plan — see that method's doc
/// comment for why), then shows [StaffAccountCreatedDialog] and pops back
/// to [AdminDoctorListScreen] with `true` so it refreshes.
///
/// Unlike Doctor's Add Incharge and Incharge's Add Caretaker screens, the
/// Admin sets the doctor's password directly here rather than relying on
/// a Firebase password-reset email — so the new doctor can sign in with
/// exactly the email and password the Admin gives them.
class AdminAddDoctorScreen extends StatefulWidget {
  final Profile profile;
  const AdminAddDoctorScreen({super.key, required this.profile});

  @override
  State<AdminAddDoctorScreen> createState() => _AdminAddDoctorScreenState();
}

class _AdminAddDoctorScreenState extends State<AdminAddDoctorScreen> {
  final _peopleRepo = PeopleRepository();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  final _password = TextEditingController();
  bool _saving = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter at least a name and email.')));
      return;
    }
    if (_password.text.length < 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password must be at least 6 characters.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await _peopleRepo.createStaffAccount(
        email: _email.text.trim(),
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        role: AppRole.doctor,
        orgId: widget.profile.orgId,
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => StaffAccountCreatedDialog(
          roleLabel: 'Doctor',
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          resetEmailSent: created.resetEmailSent,
          passwordSetByCreator: created.passwordSetByCreator,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(staffAccountErrorMessage(e, 'doctor'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF7F9F9),
      appBar: AppBar(title: const Text('Add doctor')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(Icons.medical_information_outlined, color: AppTheme.primary),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Provision a new Doctor account for your organization.',
                  style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SectionCard(
            title: 'Doctor details',
            child: Column(
              children: [
                TextField(
                  controller: _name,
                  decoration: polishedFieldDecoration(label: 'Full name', icon: Icons.badge_outlined),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: polishedFieldDecoration(label: 'Email', icon: Icons.mail_outline),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _password,
                  obscureText: _obscurePassword,
                  decoration: polishedFieldDecoration(
                    label: 'Password',
                    icon: Icons.lock_outline,
                    helperText: 'The doctor signs in with this email and password.',
                    helperMaxLines: 2,
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                        color: const Color(0xFF9AA5A3),
                      ),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: polishedFieldDecoration(label: 'Phone', icon: Icons.call_outlined),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: _saving ? null : _create,
              icon: _saving
                  ? const SizedBox.shrink()
                  : const Icon(Icons.person_add_alt_1_outlined, size: 20),
              label: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create doctor account', style: TextStyle(fontWeight: FontWeight.w600)),
            ),
          ),
        ],
      ),
    );
  }
}
