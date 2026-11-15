import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/people_repository.dart';
import '../../shared/widgets.dart';

/// Add Caretaker (MedGuardian screen spec I5) — the Incharge's counterpart
/// to Admin's Add Doctor and Doctor's Add Incharge screens, provisioning
/// the last role down the management chain (Section 11: Incharge ->
/// Caretaker). Same `PeopleRepository.createStaffAccount` client-side
/// flow, gated by `canCreateStaffRole()` in firestore.rules requiring the
/// caller's own role to be `incharge`.
class InchargeAddCaretakerScreen extends StatefulWidget {
  final Profile profile;
  const InchargeAddCaretakerScreen({super.key, required this.profile});

  @override
  State<InchargeAddCaretakerScreen> createState() => _InchargeAddCaretakerScreenState();
}

class _InchargeAddCaretakerScreenState extends State<InchargeAddCaretakerScreen> {
  final _peopleRepo = PeopleRepository();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    if (_name.text.trim().isEmpty || _email.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter at least a name and email.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final created = await _peopleRepo.createStaffAccount(
        email: _email.text.trim(),
        fullName: _name.text.trim(),
        phone: _phone.text.trim(),
        role: AppRole.caretaker,
        orgId: widget.profile.orgId,
      );
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (_) => StaffAccountCreatedDialog(
          roleLabel: 'Caretaker',
          fullName: _name.text.trim(),
          email: _email.text.trim(),
          resetEmailSent: created.resetEmailSent,
        ),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(staffAccountErrorMessage(e, 'caretaker'))),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add caretaker')),
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
                  : const Text('Create caretaker account'),
            ),
          ),
        ],
      ),
    );
  }
}
