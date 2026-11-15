import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/roles.dart';
import '../core/theme.dart';
import '../data/models/ai_insight.dart';
import '../data/models/medication_models.dart';
import '../data/models/profile.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/notifications_repository.dart';

/// Common scaffold for every role dashboard: title, role badge, sign-out.
/// Keeps the five dashboards (Section 27) visually consistent.
class RoleScaffold extends StatelessWidget {
  final String title;
  final Profile profile;
  final Widget body;
  final List<Widget>? actions;
  final Widget? floatingActionButton;

  const RoleScaffold({
    super.key,
    required this.title,
    required this.profile,
    required this.body,
    this.actions,
    this.floatingActionButton,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          ...?actions,
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Center(child: RoleBadge(role: profile.role)),
          ),
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout),
            // Unregister this device's push token first — otherwise the
            // next signed-in account on this device would silently keep
            // receiving alerts meant for whoever just signed out.
            onPressed: () async {
              await NotificationsRepository().unregisterCurrentDevice(profile.id);
              await AuthRepository().signOut();
            },
          ),
        ],
      ),
      body: SafeArea(child: body),
      floatingActionButton: floatingActionButton,
    );
  }
}

class RoleBadge extends StatelessWidget {
  final AppRole role;
  const RoleBadge({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: scheme.primaryContainer,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        role.label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: scheme.onPrimaryContainer,
        ),
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;
  const SectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          ?trailing,
        ],
      ),
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        status.replaceAll('_', ' '),
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

/// A single dose row, used on Patient, Caretaker and Incharge screens alike
/// (Section 27) so a "missed dose" looks the same everywhere.
class MedicineEventTile extends StatelessWidget {
  final MedicationEvent event;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const MedicineEventTile({
    super.key,
    required this.event,
    this.subtitle,
    this.trailing,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(event.scheduledAt);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor(event.finalStatus).withValues(alpha: 0.15),
          child: Icon(Icons.medication_outlined, color: statusColor(event.finalStatus)),
        ),
        title: Text('${event.medicineName ?? 'Medicine'} · ${event.medicineDose ?? ''}'),
        subtitle: Text(subtitle ?? 'Scheduled $time'),
        trailing: trailing ?? StatusChip(status: event.finalStatus),
        onTap: onTap,
      ),
    );
  }
}

/// One patient's latest nightly adherence insight (Section 44), shown on
/// the Doctor/Incharge/Caretaker dashboards — whoever is actually
/// monitoring that patient day to day, rather than Admin/Dean, who works
/// at the org level (see `AnalyticsRepository.latestInsightsForPatients`).
class InsightTile extends StatelessWidget {
  final String patientLabel;
  final AiInsight insight;

  const InsightTile({super.key, required this.patientLabel, required this.insight});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
          child: Icon(Icons.auto_awesome_outlined,
              color: Theme.of(context).colorScheme.onSecondaryContainer),
        ),
        title: Text(patientLabel),
        subtitle: Text(insight.insightText),
        isThreeLine: insight.insightText.length > 40,
        trailing: Text(
          DateFormat.MMMd().add_jm().format(insight.generatedAt),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final String message;
  final IconData icon;
  const EmptyState({super.key, required this.message, this.icon = Icons.inbox_outlined});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}

/// Small "add a person" form reused wherever one role provisions the next
/// one in the management chain (Admin->Doctor, Doctor->Incharge,
/// Incharge->Caretaker — Section 11), collecting exactly the fields
/// `create-staff-user` needs (Section 39/48).
class AddPersonDialog extends StatefulWidget {
  final String title;
  const AddPersonDialog({super.key, required this.title});

  @override
  State<AddPersonDialog> createState() => _AddPersonDialogState();
}

class _AddPersonDialogState extends State<AddPersonDialog> {
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _phone = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(controller: _name, decoration: const InputDecoration(labelText: 'Full name')),
          TextField(controller: _email, decoration: const InputDecoration(labelText: 'Email')),
          TextField(controller: _phone, decoration: const InputDecoration(labelText: 'Phone')),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () => Navigator.of(context).pop({
            'name': _name.text.trim(),
            'email': _email.text.trim(),
            'phone': _phone.text.trim(),
          }),
          child: const Text('Add'),
        ),
      ],
    );
  }
}

/// Shown right after `PeopleRepository.createStaffAccount` succeeds (Add
/// doctor/incharge/caretaker). The account already exists in Firebase and
/// can sign in — this just confirms that, and says how it gets a
/// password: either whoever created it typed one directly
/// (`passwordSetByCreator == true` — e.g. Admin's Add Doctor screen), in
/// which case they're expected to pass it on themselves; or Firebase
/// emailed the new person a password-reset link directly (no Cloud
/// Function involved, since MedGuard runs on the Spark plan), so there's
/// nothing to copy or relay by hand. If that email happened to fail to
/// send (`resetEmailSent == false`), it says so and points at "Forgot
/// password?" on the sign-in screen as the fallback.
class StaffAccountCreatedDialog extends StatelessWidget {
  final String roleLabel; // e.g. "Doctor"
  final String fullName;
  final String email;
  final bool resetEmailSent;
  final bool passwordSetByCreator;

  const StaffAccountCreatedDialog({
    super.key,
    required this.roleLabel,
    required this.fullName,
    required this.email,
    required this.resetEmailSent,
    this.passwordSetByCreator = false,
  });

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('$roleLabel account created'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$fullName is stored in Firebase and can sign in with:'),
          const SizedBox(height: 4),
          SelectableText(email, style: const TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 14),
          Text(
            passwordSetByCreator
                ? 'They can sign in right away with that email and the '
                    'password you just set for them — make sure they know it.'
                : resetEmailSent
                    ? 'Firebase just emailed them a link to set their password. '
                        "Once they've done that, they sign in with the email above."
                    : "Firebase couldn't send the password-reset email just now. "
                        'They can still get in using "Forgot password?" on the sign-in '
                        'screen with the email above.',
          ),
        ],
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Done'),
        ),
      ],
    );
  }
}

/// A small labeled icon button used in the Patient home screen's "Quick
/// actions" row (Scan prescription, AI Assistant, Health records, Drug
/// interactions, Emergency QR) — one shared shape so adding another quick
/// action later is a one-line call, not a bespoke widget.
class QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const QuickActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: 84,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 6),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Shown at the top of every AI-output or reference-data screen (AI
/// Assistant, Drug Interaction Checker) so the caution the MedGuardian AI
/// spec calls for — "show AI output as explanations and recommendations,
/// not as a substitute for a clinician" — is visible every time, not just
/// mentioned once in a doc nobody using the app will read.
class DisclaimerBanner extends StatelessWidget {
  final String message;
  const DisclaimerBanner({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 18, color: scheme.onTertiaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 12.5),
            ),
          ),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final Color? color;

  const StatTile({super.key, required this.label, required this.value, this.color});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: color ?? scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

/// Turns whatever `PeopleRepository.createStaffAccount` throws into a
/// message worth showing on the "Add Doctor"/"Add Incharge"/"Add
/// Caretaker" screens, all three of which share the same try/catch
/// around that call. Two cases are worth calling out specifically:
///  - `email-already-in-use`: as of the rollback fix in
///    `createStaffAccount`, this cleans up after itself when its
///    Firestore writes fail, so a *fresh* failure here means that email
///    is genuinely already registered to someone — but an account
///    created before that fix existed could still be an orphaned
///    leftover with no matching profile, which only an admin can clear
///    from the Firebase Console's Authentication tab.
///  - `permission-denied`: this is Firestore Security Rules
///    (`firestore.rules`, `canCreateStaffRole()`) refusing the write, not
///    a bug in this screen — it means either the rules deployed on the
///    live Firebase project don't allow this caller to create that role,
///    or the caller's own `profiles/{uid}` document doesn't have the
///    role Firestore expects (e.g. an Admin's profile missing
///    `role: 'admin'`, or the rules file having never been deployed at
///    all with `firebase deploy --only firestore:rules`).
/// Anything else falls back to the exception's own message.
String staffAccountErrorMessage(Object error, String roleLabel) {
  if (error is FirebaseAuthException && error.code == 'email-already-in-use') {
    return 'That email is already registered to an account. Use a '
        'different email, or ask an admin to check the Firebase Console\'s '
        'Authentication tab in case it\'s a leftover from a previous '
        'failed attempt.';
  }
  if (error is FirebaseException && error.code == 'permission-denied') {
    return "Firestore rejected this — your account isn't authorized to "
        'add a $roleLabel. Check that your own profile document has the '
        'right role, and that firestore.rules has actually been deployed '
        '(`firebase deploy --only firestore:rules`).';
  }
  return 'Could not add $roleLabel: $error';
}

// ---------------------------------------------------------------------
// Polished, soft-shadow building blocks used by Admin's screens
// (dashboard, Doctors, Doctor Details, Add Doctor, Patients, System
// Analytics, Alert Analytics). These sit alongside the plainer originals
// above (RoleScaffold, SectionHeader, StatTile, …) rather than replacing
// them — Doctor/Incharge/Caretaker screens still use those, unchanged.
// ---------------------------------------------------------------------

/// A small fixed palette used to give each person a consistent, distinct
/// avatar color based on their name — so the same person shows up the
/// same shade everywhere they appear, without storing a color anywhere.
const _avatarPalette = [
  Color(0xFF2563EB), // blue
  Color(0xFF7C3AED), // violet
  Color(0xFFEA580C), // orange
  Color(0xFF16A34A), // green
  Color(0xFFDB2777), // pink
  Color(0xFF0891B2), // cyan
  Color(0xFFCA8A04), // amber
];

Color avatarColorFor(String name) {
  if (name.isEmpty) return _avatarPalette.first;
  final hash = name.codeUnits.fold<int>(0, (sum, c) => sum + c);
  return _avatarPalette[hash % _avatarPalette.length];
}

/// A colored circular initials avatar — the polished alternative to a
/// plain grey [CircleAvatar] with a generic icon, used across Admin's
/// people-listing screens so every row reads as a distinct person rather
/// than an interchangeable placeholder.
class PersonAvatar extends StatelessWidget {
  final String name;
  final double radius;
  const PersonAvatar({super.key, required this.name, this.radius = 22});

  @override
  Widget build(BuildContext context) {
    final color = avatarColorFor(name);
    final trimmed = name.trim();
    final initial = trimmed.isNotEmpty ? trimmed[0].toUpperCase() : '?';
    return CircleAvatar(
      radius: radius,
      backgroundColor: color.withValues(alpha: 0.15),
      child: Text(
        initial,
        style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: radius * 0.75),
      ),
    );
  }
}

/// A soft-shadow white card used to group related content — the shared
/// building block behind Admin's dashboard sections, reused across its
/// other screens (profile headers, stat groupings, list containers) for
/// a consistent "elevated card" look instead of the flatter default
/// [Card].
class SectionCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    this.title,
    this.subtitle,
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.045), blurRadius: 18, offset: const Offset(0, 6)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF111827)),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(subtitle!, style: const TextStyle(fontSize: 11.5, color: Color(0xFF9CA3AF))),
            ],
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}

/// A colored icon-chip metric card — big number, label, optional "View
/// all" link — the shared version of the stat cards on Admin's
/// dashboard, reused on Doctor Details / System Analytics / Alert
/// Analytics so every count across Admin's screens looks the same.
class MetricCard extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String value;
  final String label;
  final VoidCallback? onViewAll;

  const MetricCard({
    super.key,
    required this.icon,
    required this.color,
    required this.value,
    required this.label,
    this.onViewAll,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 14, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(value, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold, color: Color(0xFF111827))),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
          if (onViewAll != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: onViewAll,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('View all', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
                  const SizedBox(width: 2),
                  Icon(Icons.arrow_forward, size: 11, color: color),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A tappable soft-shadow row card for a person (Doctor, Patient, …) —
/// avatar + name + subtitle + chevron — replacing the flatter
/// `Card(child: ListTile(...))` pattern on Admin's people-listing
/// screens.
class PersonListCard extends StatelessWidget {
  final String name;
  final String subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  const PersonListCard({
    super.key,
    required this.name,
    required this.subtitle,
    this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.04), blurRadius: 12, offset: const Offset(0, 3)),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                PersonAvatar(name: name),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: Color(0xFF111827)),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
                      ],
                    ],
                  ),
                ),
                trailing ?? const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A rounded, filled text field matching Admin's polished screens (Add
/// Doctor) — borderless fill instead of the app's default outlined
/// style, used only where a screen has explicitly opted into this look.
InputDecoration polishedFieldDecoration({
  required String label,
  IconData? icon,
  String? helperText,
  int? helperMaxLines,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    helperText: helperText,
    helperMaxLines: helperMaxLines,
    prefixIcon: icon == null ? null : Icon(icon, color: AppTheme.primary),
    suffixIcon: suffixIcon,
    filled: true,
    fillColor: const Color(0xFFF3F8F7),
    contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
    ),
  );
}
