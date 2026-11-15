import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import '../../core/roles.dart';
import '../../data/models/health_record.dart';
import '../../data/repositories/health_records_repository.dart';
import '../../shared/widgets.dart';

/// Health Record Vault (MedGuardian AI SUPPORT feature): "Store
/// prescriptions and selected health documents using Firebase Storage +
/// Firestore metadata." Fully functional — this one doesn't depend on
/// OCR/Gemini, just Firebase Storage, which is already wired up.
///
/// Used by the Patient (upload/view/delete their own) and, read-only, by
/// whoever is monitoring them (Doctor/Incharge/Caretaker) via [readOnly].
class HealthRecordsScreen extends StatefulWidget {
  final String patientId;
  final String patientLabel;
  final AppRole viewerRole;
  final bool readOnly;

  /// true (default) = standalone screen with its own `AppBar` and upload
  /// `FloatingActionButton`, for when this is pushed with `Navigator`.
  /// false = bare content only (a header row + inline upload button
  /// instead of a FAB) for embedding as a tab body inside [PatientShell],
  /// which supplies its own `Scaffold`/bottom nav.
  final bool showChrome;

  const HealthRecordsScreen({
    super.key,
    required this.patientId,
    required this.patientLabel,
    required this.viewerRole,
    this.readOnly = false,
    this.showChrome = true,
  });

  @override
  State<HealthRecordsScreen> createState() => _HealthRecordsScreenState();
}

class _HealthRecordsScreenState extends State<HealthRecordsScreen> {
  final _repo = HealthRecordsRepository();
  late Future<List<HealthRecord>> _future;

  @override
  void initState() {
    super.initState();
    _future = _repo.fetchForPatient(widget.patientId);
  }

  Future<void> _refresh() async {
    setState(() => _future = _repo.fetchForPatient(widget.patientId));
    await _future;
  }

  Future<void> _uploadFlow() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery, imageQuality: 90);
    if (picked == null) return;
    if (!mounted) return;

    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (_) => const _UploadDetailsDialog(),
    );
    if (result == null) return;

    try {
      await _repo.upload(
        patientId: widget.patientId,
        file: File(picked.path),
        title: result['title']!,
        type: result['type']!,
        uploaderRole: widget.viewerRole,
      );
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    }
  }

  Future<void> _delete(HealthRecord record) async {
    await _repo.delete(record);
    await _refresh();
  }

  IconData _iconFor(String type) {
    switch (type) {
      case HealthRecordType.prescription:
        return Icons.receipt_long_outlined;
      case HealthRecordType.labReport:
        return Icons.science_outlined;
      case HealthRecordType.scan:
        return Icons.image_outlined;
      default:
        return Icons.description_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showChrome) {
      return Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text('Health records', style: Theme.of(context).textTheme.titleLarge),
                ),
                if (!widget.readOnly)
                  IconButton.filledTonal(
                    tooltip: 'Upload',
                    onPressed: _uploadFlow,
                    icon: const Icon(Icons.upload_file_outlined),
                  ),
              ],
            ),
          ),
          Expanded(child: _list()),
        ],
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text('Health records · ${widget.patientLabel}')),
      floatingActionButton: widget.readOnly
          ? null
          : FloatingActionButton.extended(
              onPressed: _uploadFlow,
              icon: const Icon(Icons.upload_file_outlined),
              label: const Text('Upload'),
            ),
      body: _list(),
    );
  }

  Widget _list() {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<HealthRecord>>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final records = snapshot.data!;
          if (records.isEmpty) {
            return ListView(
              children: const [
                EmptyState(
                  message: 'No documents yet.',
                  icon: Icons.folder_open_outlined,
                ),
              ],
            );
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: records.map((r) {
              return Card(
                child: ListTile(
                  leading: CircleAvatar(child: Icon(_iconFor(r.type))),
                  title: Text(r.title),
                  subtitle: Text(
                    '${HealthRecordType.label(r.type)} · '
                    '${DateFormat.MMMd().add_jm().format(r.uploadedAt)}',
                  ),
                  trailing: widget.readOnly
                      ? const Icon(Icons.chevron_right)
                      : IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _delete(r),
                        ),
                  onTap: () => _openViewer(r),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }

  void _openViewer(HealthRecord record) {
    showDialog(
      context: context,
      builder: (_) => Dialog(
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              record.downloadUrl,
              errorBuilder: (_, _, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not preview "${record.title}".'),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _UploadDetailsDialog extends StatefulWidget {
  const _UploadDetailsDialog();

  @override
  State<_UploadDetailsDialog> createState() => _UploadDetailsDialogState();
}

class _UploadDetailsDialogState extends State<_UploadDetailsDialog> {
  final _title = TextEditingController();
  String _type = HealthRecordType.other;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add document'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Title (e.g. "Blood test — June")'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: HealthRecordType.all
                .map((t) => DropdownMenuItem(value: t, child: Text(HealthRecordType.label(t))))
                .toList(),
            onChanged: (v) => setState(() => _type = v ?? HealthRecordType.other),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        FilledButton(
          onPressed: () {
            final title = _title.text.trim();
            if (title.isEmpty) return;
            Navigator.of(context).pop({'title': title, 'type': _type});
          },
          child: const Text('Upload'),
        ),
      ],
    );
  }
}
