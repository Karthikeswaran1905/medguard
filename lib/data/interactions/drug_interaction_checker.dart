/// Drug Interaction Checker (MedGuardian AI SUPPORT feature): "Check the
/// active medication list for potential interactions and display safety
/// warnings."
///
/// This is a small, local, reference-only lookup — **not** a clinical
/// decision tool, not exhaustive, and not a substitute for a pharmacist or
/// doctor (the UI says this plainly, matching the spec's own design
/// principle: "show AI output as explanations and recommendations, not as
/// a substitute for a clinician"). It matches on well-known, widely
/// published interacting pairs by matching medicine names loosely — brand
/// names and dose strengths aren't normalized, so it can both miss real
/// interactions and flag unrelated medicines that happen to share a
/// substring. Always err toward showing the caveat, not toward hiding it.
///
/// A more capable version of this (checking real drug databases via an
/// API) is exactly the kind of thing the deferred AI/API work could
/// replace this with later — [DrugInteractionChecker.check] is the single
/// seam that call would go behind.
class InteractionWarning {
  final String medicineA;
  final String medicineB;
  final String severity; // moderate | high
  final String note;

  const InteractionWarning({
    required this.medicineA,
    required this.medicineB,
    required this.severity,
    required this.note,
  });
}

class DrugInteractionChecker {
  DrugInteractionChecker._();

  /// Each entry: two keyword groups (either name in group A with either
  /// name in group B triggers the warning) plus a severity and a short,
  /// plain-language note. Keep this list small and well-established rather
  /// than exhaustive — a wrong "no interactions found" is worse than a
  /// missed edge case being covered by the "not exhaustive" disclaimer.
  static final List<_Rule> _rules = [
    _Rule(
      ['warfarin'],
      ['aspirin', 'ibuprofen', 'naproxen', 'diclofenac'],
      'high',
      'Combining a blood thinner with an NSAID/aspirin can raise bleeding '
          'risk. This combination is usually only used under close medical '
          'supervision.',
    ),
    _Rule(
      ['aspirin'],
      ['clopidogrel', 'ibuprofen', 'naproxen'],
      'moderate',
      'Combining these can increase the risk of stomach or other bleeding.',
    ),
    _Rule(
      ['lisinopril', 'enalapril', 'ramipril'],
      ['spironolactone', 'potassium'],
      'moderate',
      'ACE inhibitors combined with potassium-sparing diuretics or '
          'potassium supplements can raise blood potassium to unsafe '
          'levels — this is usually monitored with blood tests.',
    ),
    _Rule(
      ['metformin'],
      ['contrast dye', 'iodinated contrast'],
      'moderate',
      'Metformin is often paused around imaging that uses iodinated '
          'contrast dye, on medical advice, due to kidney-function risk.',
    ),
    _Rule(
      ['sertraline', 'fluoxetine', 'escitalopram', 'paroxetine'],
      ['tramadol', 'phenelzine', 'selegiline'],
      'high',
      'Combining these can raise the risk of serotonin syndrome, a rare '
          'but serious reaction.',
    ),
    _Rule(
      ['digoxin'],
      ['amiodarone', 'verapamil'],
      'moderate',
      'These can raise digoxin levels in the blood — dose adjustment and '
          'monitoring is typically needed.',
    ),
    _Rule(
      ['sildenafil', 'tadalafil'],
      ['nitroglycerin', 'isosorbide', 'nitrate'],
      'high',
      'This combination can cause a dangerous drop in blood pressure and '
          'is generally avoided.',
    ),
    _Rule(
      ['methotrexate'],
      ['ibuprofen', 'naproxen', 'trimethoprim'],
      'moderate',
      'These can raise methotrexate levels and its side-effect risk.',
    ),
    _Rule(
      ['simvastatin', 'atorvastatin'],
      ['clarithromycin', 'erythromycin', 'itraconazole'],
      'moderate',
      'These can raise statin levels in the blood, increasing the risk of '
          'muscle-related side effects.',
    ),
  ];

  static List<InteractionWarning> check(List<String> medicineNames) {
    final names = medicineNames.map((n) => n.toLowerCase().trim()).toList();
    final warnings = <InteractionWarning>[];

    for (final rule in _rules) {
      for (final a in names) {
        if (!rule.groupA.any(a.contains)) continue;
        for (final b in names) {
          if (a == b) continue;
          if (!rule.groupB.any(b.contains)) continue;
          warnings.add(InteractionWarning(
            medicineA: a,
            medicineB: b,
            severity: rule.severity,
            note: rule.note,
          ));
        }
      }
    }
    return warnings;
  }
}

class _Rule {
  final List<String> groupA;
  final List<String> groupB;
  final String severity;
  final String note;
  const _Rule(this.groupA, this.groupB, this.severity, this.note);
}
