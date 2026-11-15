import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../data/models/prescription_scan.dart';
import '../../data/repositories/prescription_scan_repository.dart';

/// AI Extracted Medicines / OCR Review (MedGuardian AI CORE feature):
/// "Extracted medicine cards + Edit + Confirm — prevent incorrect OCR/AI
/// data from being saved."
///
/// The real pipeline here is Google ML Kit OCR -> Gemini structuring,
/// which is the deferred AI/API work — so the fields below start blank
/// instead of pre-filled, and the patient fills them in directly. The
/// screen's actual job (review before it's saved anywhere, never trust
/// extraction blindly) is fully real: nothing is written to
/// `prescription_scans` until the patient explicitly confirms here.
///
/// Confirming does **not** create a live `medicines`/
/// `medication_schedules` document — see [PrescriptionScan]'s doc comment
/// for why (only a linked Doctor can, by Firestore Security Rules). It
/// saves a reviewed draft that shows up on the patient's own scan list and
/// on their linked Doctor's dashboard as something to act on.
class OcrReviewScreen extends StatefulWidget {
  final String scanId;
  const OcrReviewScreen({super.key, required this.scanId});

  @override
  State<OcrReviewScreen> createState() => _OcrReviewScreenState();
}

class _OcrReviewScreenState extends State<OcrReviewScreen> {
  final _repo = PrescriptionScanRepository();
  late Future<PrescriptionScan> _future;

  final _name = TextEditingController();
  final _dose = TextEditingController();
  final _frequency = TextEditingController();
  final _duration = TextEditingController(text: '30');
  final _instructions = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<PrescriptionScan> _load() async {
    final scan = await _repo.fetchScan(widget.scanId);
    _name.text = scan.extractedName;
    _dose.text = scan.extractedDose;
    _frequency.text = scan.extractedFrequency;
    _duration.text = scan.extractedDurationDays > 0 ? '${scan.extractedDurationDays}' : '30';
    _instructions.text = scan.extractedInstructions;
    return scan;
  }

  Future<void> _confirm() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Enter at least the medicine name.')));
      return;
    }
    setState(() => _saving = true);
    try {
      await _repo.confirmReview(
        scanId: widget.scanId,
        name: _name.text.trim(),
        dose: _dose.text.trim(),
        frequency: _frequency.text.trim(),
        durationDays: int.tryParse(_duration.text.trim()) ?? 30,
        instructions: _instructions.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
            'Saved. Your doctor can see this scan and prescribe it formally.',
          ),
        ));
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _dose.dispose();
    _frequency.dispose();
    _duration.dispose();
    _instructions.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Extracted Medicines')),
      body: FutureBuilder<PrescriptionScan>(
        future: _future,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppTheme.pending.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppTheme.pending.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.info_outline, color: AppTheme.pending),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text('Enter the medicine details below',
                              style: TextStyle(fontWeight: FontWeight.w600)),
                          SizedBox(height: 2),
                          Text(
                            'Automatic reading isn\'t connected in this build yet — please '
                            'review your prescription photo and fill this in, then confirm.',
                            style: TextStyle(fontSize: 12.5),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 12,
                            backgroundColor: AppTheme.primary,
                            child: const Text('1',
                                style: TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                          ),
                          const SizedBox(width: 10),
                          const Expanded(
                            child: Text('Medicine', style: TextStyle(fontWeight: FontWeight.bold)),
                          ),
                          Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                        ],
                      ),
                      const Divider(height: 24),
                      TextField(
                        controller: _name,
                        decoration: const InputDecoration(labelText: 'Medicine name'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _dose,
                        decoration: const InputDecoration(labelText: 'Dose (e.g. 500 mg)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _frequency,
                        decoration:
                            const InputDecoration(labelText: 'Frequency (e.g. once a day)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _duration,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Duration (days)'),
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _instructions,
                        decoration: const InputDecoration(
                          labelText: 'Instructions (e.g. after food)',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _saving ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Text('Confirm & Save'),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Need to log more than one medicine? Scan again for each one.',
                  style: Theme.of(context).textTheme.bodySmall,
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
