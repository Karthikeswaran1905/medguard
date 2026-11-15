import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../data/models/prescription_scan.dart';
import '../../data/repositories/prescription_scan_repository.dart';
import '../../shared/widgets.dart';
import 'ocr_review_screen.dart';

/// Lists a patient's `prescription_scans`. Used two ways:
///  - by the Patient themselves (own scans; an unreviewed draft can be
///    reopened straight into [OcrReviewScreen]);
///  - read-only by their Doctor, from the patient's card on the Doctor
///    dashboard, so a scan a patient submitted is actually visible to
///    someone who can act on it instead of sitting unseen.
class ScannedPrescriptionsScreen extends StatefulWidget {
  final String patientId;
  final String patientLabel;
  final bool readOnly;

  const ScannedPrescriptionsScreen({
    super.key,
    required this.patientId,
    required this.patientLabel,
    this.readOnly = false,
  });

  @override
  State<ScannedPrescriptionsScreen> createState() => _ScannedPrescriptionsScreenState();
}

class _ScannedPrescriptionsScreenState extends State<ScannedPrescriptionsScreen> {
  final _repo = PrescriptionScanRepository();
  late Future<List<PrescriptionScan>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchForPatient(widget.patientId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.fetchForPatient(widget.patientId));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Scanned prescriptions · ${widget.patientLabel}')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<PrescriptionScan>>(
          future: _future,
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final scans = snapshot.data!;
            if (scans.isEmpty) {
              return ListView(
                children: const [
                  EmptyState(
                    message: 'No scanned prescriptions yet.',
                    icon: Icons.document_scanner_outlined,
                  ),
                ],
              );
            }
            return ListView(
              padding: const EdgeInsets.all(16),
              children: scans.map((s) {
                final reviewed = s.status == 'reviewed';
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: reviewed
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Icon(
                        reviewed ? Icons.check_circle_outline : Icons.edit_note_outlined,
                      ),
                    ),
                    title: Text(
                      s.extractedName.isEmpty ? 'Unreviewed scan' : s.extractedName,
                    ),
                    subtitle: Text(
                      reviewed
                          ? '${s.extractedDose} · ${s.extractedFrequency}'
                          : 'Scanned ${DateFormat.MMMd().add_jm().format(s.createdAt)} · '
                              'not reviewed yet',
                    ),
                    trailing: Chip(
                      label: Text(reviewed ? 'Reviewed' : 'Draft'),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: reviewed
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                    ),
                    onTap: widget.readOnly
                        ? null
                        : () async {
                            final changed = await Navigator.of(context).push<bool>(
                              MaterialPageRoute(
                                builder: (_) => OcrReviewScreen(scanId: s.id),
                              ),
                            );
                            if (changed == true) _refresh();
                          },
                  ),
                );
              }).toList(),
            );
          },
        ),
      ),
    );
  }
}
