import 'package:flutter/material.dart';

import '../../core/roles.dart';
import '../../core/theme.dart';
import '../../data/models/profile.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/notifications_repository.dart';
import '../ai/ai_assistant_screen.dart';
import '../emergency_qr/emergency_qr_screen.dart';
import '../health_records/health_records_screen.dart';
import '../interactions/drug_interaction_screen.dart';
import '../prescriptions/scanned_prescriptions_screen.dart';

/// Profile tab: account info plus the quick links that don't have a
/// dedicated bottom-nav slot (AI Assistant, Drug Interaction Checker,
/// Emergency QR, Health Records, scanned prescriptions) and sign out.
/// Health Records lives here rather than as its own bottom-nav tab to
/// match the finalized MedGuardian screen spec's 4-tab patient nav (Home /
/// Medicines / Adherence / Profile).
class ProfileScreen extends StatelessWidget {
  final Profile profile;
  const ProfileScreen({super.key, required this.profile});

  Future<void> _signOut(BuildContext context) async {
    await NotificationsRepository().unregisterCurrentDevice(profile.id);
    await AuthRepository().signOut();
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Text('Profile', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                child: Text(
                  profile.fullName.isNotEmpty ? profile.fullName[0].toUpperCase() : '?',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppTheme.primary),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    if (profile.email != null && profile.email!.isNotEmpty)
                      Text(profile.email!, style: Theme.of(context).textTheme.bodySmall),
                    if (profile.phone != null && profile.phone!.isNotEmpty)
                      Text(profile.phone!, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        Text('Quick access', style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        _ProfileTile(
          icon: Icons.auto_awesome_outlined,
          label: 'AI Assistant',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => const AiAssistantScreen(),
          )),
        ),
        _ProfileTile(
          icon: Icons.health_and_safety_outlined,
          label: 'Drug Interaction Checker',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => DrugInteractionScreen(patientId: profile.id, patientLabel: profile.fullName),
          )),
        ),
        _ProfileTile(
          icon: Icons.qr_code_2_outlined,
          label: 'Emergency QR Card',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => EmergencyQrScreen(patient: profile),
          )),
        ),
        _ProfileTile(
          icon: Icons.folder_shared_outlined,
          label: 'Health Records',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => HealthRecordsScreen(
              patientId: profile.id,
              patientLabel: profile.fullName,
              viewerRole: AppRole.patient,
            ),
          )),
        ),
        _ProfileTile(
          icon: Icons.receipt_long_outlined,
          label: 'Scanned prescriptions',
          onTap: () => Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => ScannedPrescriptionsScreen(
              patientId: profile.id,
              patientLabel: profile.fullName,
            ),
          )),
        ),
        const SizedBox(height: 20),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: () => _signOut(context),
            icon: Icon(Icons.logout, color: AppTheme.critical),
            label: Text('Sign out', style: TextStyle(color: AppTheme.critical)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: AppTheme.critical)),
          ),
        ),
      ],
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ProfileTile({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
          child: Icon(icon, color: AppTheme.primary),
        ),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
