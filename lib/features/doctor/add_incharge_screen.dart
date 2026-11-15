import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Add Incharge (MedGuardian screen spec D9) — the Doctor's counterpart to
/// Admin's Add Doctor screen, provisioning the next role down the
/// management chain (Section 11: Admin -> Doctor -> Incharge). Same
/// `PeopleRepository.createStaffAccount` client-side flow, gated by
/// `canCreateStaffRole()` in firestore.rules requiring the caller's own
/// role to be `doctor`.
///
/// Like Admin's Add Doctor screen, the Doctor sets the incharge's password
/// directly here rather than relying on a Firebase password-reset email —
/// so the new incharge can sign in with exactly the email and password
/// the Doctor gives them.
class DoctorAddInchargeScreen extends StatefulWidget {
  final Profile profile;
  const DoctorAddInchargeScreen({super.key, required this.profile});

  @override
  State<DoctorAddInchargeScreen> createState() => _DoctorAddInchargeScreenState();
}

class _DoctorAddInchargeScreenState extends State<DoctorAddInchargeScreen> {
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
        role: AppRole.incharge,
        orgId: widget.profile.orgId,
        password: _password.text,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => StaffAccountCreatedDialog(
          roleLabel: 'Incharge',
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
          SnackBar(content: Text(staffAccountErrorMessage(e, 'incharge'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add incharge')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          const SizedBox(height: 12),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _password,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Password',
              helperText: 'The incharge signs in with this email and password.',
              helperMaxLines: 2,
              suffixIcon: IconButton(
                icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _saving ? null : _create,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Create incharge account'),
            ),
          ),
        ],
      ),
    );
  }
}
