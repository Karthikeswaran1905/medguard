/// Backs the AI Assistant screen (MedGuardian AI: "Chat/voice input +
/// answer cards — ask medicine-related questions in simple language").
///
/// **Stubbed by design.** The real answer engine is Gemini, called from a
/// Cloud Function (matching the architecture's "Flutter UI must not
/// directly depend on Firebase" rule and keeping the API key server-side,
/// the same pattern `aiInsightsBatch` already uses for `AI_API_KEY`) — that
/// wiring is exactly the "API" work already deferred. This repository is
/// the seam where that call goes: the screen only ever talks to [ask],
/// so swapping the body of this method for a
/// `FirebaseService.functions.httpsCallable('askAiAssistant').call(...)`
/// call is the entire migration, with zero UI changes.
///
/// In the meantime, [ask] answers a small set of common, safe medication
/// questions from a local FAQ so the screen is genuinely useful today, and
/// says so plainly for anything outside that set rather than inventing an
/// answer.
class AiAssistantRepository {
  static final List<_Faq> _faqs = [
    _Faq(
      const ['before food', 'after food', 'with food', 'empty stomach'],
      'Whether to take a medicine before or after food is set by the '
          'prescribing doctor for that specific medicine — check the '
          'instructions on the Medication Details screen for it. If none '
          'are given, ask your doctor rather than guessing.',
    ),
    _Faq(
      const ['missed dose', 'forgot', 'skip'],
      'If you missed a dose, mark it honestly as Missed rather than '
          'Taken — your adherence history and your caregiver\'s alerts '
          'depend on it being accurate. Don\'t take a double dose to '
          '"catch up" without checking with your doctor first.',
    ),
    _Faq(
      const ['side effect', 'reaction', 'feel unwell', 'feel sick'],
      'I can\'t assess symptoms or side effects — if something feels '
          'wrong after taking a medicine, contact your doctor or a '
          'caregiver directly, or seek urgent care if it feels serious.',
    ),
    _Faq(
      const ['interaction', 'together', 'combine'],
      'For a check of your current medicines against each other, use the '
          'Drug Interaction Checker from your home screen — it looks at '
          'exactly what you\'re taking. I can\'t reliably judge that in '
          'chat.',
    ),
    _Faq(
      const ['adherence', 'percentage', 'streak'],
      'Your adherence percentage is on the Adherence dashboard — it\'s the '
          'share of scheduled doses you\'ve confirmed as taken over the '
          'selected period.',
    ),
  ];

  Future<String> ask(String question) async {
    // Small, deliberate delay so the chat UI's loading state is visible —
    // this goes away once a real network call replaces it.
    await Future.delayed(const Duration(milliseconds: 400));

    final q = question.toLowerCase();
    for (final faq in _faqs) {
      if (faq.keywords.any(q.contains)) {
        return faq.answer;
      }
    }

    return "I don't have a reliable answer for that yet — the full AI "
        "assistant (powered by Gemini) isn't connected in this build. For "
        "anything about your specific medicines or symptoms, please check "
        "with your doctor or caregiver.";
  }
}

class _Faq {
  final List<String> keywords;
  final String answer;
  const _Faq(this.keywords, this.answer);
}
