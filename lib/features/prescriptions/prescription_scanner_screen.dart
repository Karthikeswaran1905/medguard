import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme.dart';
import '../../data/repositories/prescription_scan_repository.dart';
import 'ocr_review_screen.dart';

/// Add Prescription / Prescription Scanner (MedGuardian AI CORE feature):
/// "Capture/upload prescription" — camera or gallery, then hand off to
/// [OcrReviewScreen]. The OCR step itself is stubbed (see
/// [PrescriptionScanRepository] / [OcrReviewScreen] doc comments) — this
/// screen's job is purely image capture and upload.
class PrescriptionScannerScreen extends StatefulWidget {
  final String patientId;
  const PrescriptionScannerScreen({super.key, required this.patientId});

  @override
  State<PrescriptionScannerScreen> createState() => _PrescriptionScannerScreenState();
}

class _PrescriptionScannerScreenState extends State<PrescriptionScannerScreen> {
  final _repo = PrescriptionScanRepository();
  final _picker = ImagePicker();
  File? _picked;
  bool _uploading = false;

  Future<void> _pick(ImageSource source) async {
    final file = await _picker.pickImage(source: source, imageQuality: 85);
    if (file == null) return;
    setState(() => _picked = File(file.path));
  }

  Future<void> _upload() async {
    final picked = _picked;
    if (picked == null) return;
    setState(() => _uploading = true);
    try {
      final scanId = await _repo.uploadScan(
        patientId: widget.patientId,
        imageFile: picked,
      );
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => OcrReviewScreen(scanId: scanId)),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upload failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Prescription')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_picked != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: AspectRatio(
                aspectRatio: 4 / 3,
                child: Image.file(_picked!, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _uploading ? null : _upload,
                child: _uploading
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Continue'),
              ),
            ),
            TextButton(
              onPressed: _uploading ? null : () => setState(() => _picked = null),
              child: const Text('Retake / choose another'),
            ),
          ] else ...[
            Container(
              padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 20),
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.4),
                  width: 1.5,
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.center_focus_strong_outlined, size: 34, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 16),
                  const Text('Scan Prescription',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 4),
                  Text('Use camera to scan prescription',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () => _pick(ImageSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Scan Now'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('OR', style: Theme.of(context).textTheme.bodySmall),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 18),
            const Text('Upload from Gallery', style: TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Upload clear image of prescription', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _pick(ImageSource.gallery),
                icon: const Icon(Icons.image_outlined),
                label: const Text('Upload Image'),
              ),
            ),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.verified_user_outlined, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text('Your data is secure', style: TextStyle(fontWeight: FontWeight.w600)),
                        SizedBox(height: 2),
                        Text(
                          'Your prescription photo is stored privately and only you and '
                          'your care team can see it. Automatic reading of the text isn\'t '
                          'connected in this build yet — you\'ll enter the details yourself '
                          'on the next screen.',
                          style: TextStyle(fontSize: 12.5),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
