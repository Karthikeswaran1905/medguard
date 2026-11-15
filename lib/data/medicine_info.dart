/// A small, local "About this medicine" reference lookup for the
/// Medication Details screen — the same reference-only, non-exhaustive
/// spirit as `lib/data/interactions/drug_interaction_checker.dart`, not a
/// clinical information service. Matches loosely by substring on the
/// medicine name; falls back to a plain "ask your doctor/pharmacist"
/// message rather than guessing.
class MedicineInfo {
  MedicineInfo._();

  static final Map<String, String> _blurbs = {
    'paracetamol': 'Paracetamol (acetaminophen) is commonly used to relieve '
        'pain and reduce fever. Take it as directed by your doctor.',
    'acetaminophen': 'Acetaminophen (paracetamol) is commonly used to '
        'relieve pain and reduce fever. Take it as directed by your doctor.',
    'ibuprofen': 'Ibuprofen is a pain and fever reducer that also reduces '
        'inflammation. Usually taken with food to reduce stomach upset.',
    'amlodipine': 'Amlodipine relaxes blood vessels and is commonly used to '
        'treat high blood pressure.',
    'metformin': 'Metformin helps control blood sugar levels and is '
        'commonly used to manage type 2 diabetes.',
    'atorvastatin': 'Atorvastatin (a statin) helps lower cholesterol and '
        'reduce the risk of heart disease.',
    'simvastatin': 'Simvastatin (a statin) helps lower cholesterol and '
        'reduce the risk of heart disease.',
    'aspirin': 'Low-dose aspirin is commonly used to help prevent blood '
        'clots; higher doses relieve pain and fever.',
    'warfarin': 'Warfarin is a blood thinner used to prevent and treat '
        'blood clots. Regular blood tests are usually needed while taking it.',
    'lisinopril': 'Lisinopril (an ACE inhibitor) relaxes blood vessels and '
        'is commonly used to treat high blood pressure and heart failure.',
    'omeprazole': 'Omeprazole reduces stomach acid and is commonly used for '
        'acid reflux and stomach ulcers.',
    'sertraline': 'Sertraline (an SSRI) is commonly used to treat '
        'depression and anxiety-related conditions.',
    'amoxicillin': 'Amoxicillin is an antibiotic used to treat certain '
        'bacterial infections. Finish the full course even if you feel better.',
    'insulin': 'Insulin helps control blood sugar levels. Dosing is highly '
        'individual — always follow your doctor\'s exact instructions.',
    'levothyroxine': 'Levothyroxine replaces or supplements a hormone that '
        'is normally produced by the thyroid gland.',
  };

  static String describe(String medicineName) {
    final q = medicineName.toLowerCase();
    for (final entry in _blurbs.entries) {
      if (q.contains(entry.key)) return entry.value;
    }
    return 'No reference information is available for this medicine yet. '
        'Ask your doctor or pharmacist if you have questions about what '
        'it\'s for or how it works.';
  }
}
