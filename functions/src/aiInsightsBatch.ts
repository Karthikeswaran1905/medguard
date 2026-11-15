// aiInsightsBatch (Section 44, 48)
//
// Runs nightly on Cloud Scheduler. Aggregates the day's medication_events
// per patient into a compact, minimally-identifying summary, sends it to
// an external AI provider, and stores the returned text in ai_insights.
// Dashboards read pre-generated insights — nothing in the Flutter app
// calls the AI provider directly, and this function's Admin SDK access has
// no write path to prescriptions/medicines/schedules, so AI cannot alter
// clinical data even if the response were malformed (Section 19, 44).
//
// Requires the AI_API_KEY secret — see SETUP.md:
//   firebase functions:secrets:set AI_API_KEY

import { onSchedule } from "firebase-functions/v2/scheduler";
import { defineSecret } from "firebase-functions/params";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

const AI_API_KEY = defineSecret("AI_API_KEY");
const AI_API_URL = "https://api.anthropic.com/v1/messages";

async function generateInsight(summary: string, apiKey: string | undefined): Promise<string> {
  if (!apiKey) {
    return "AI insight generation is not configured (AI_API_KEY missing).";
  }
  const res = await fetch(AI_API_URL, {
    method: "POST",
    headers: {
      "x-api-key": apiKey,
      "anthropic-version": "2023-06-01",
      "content-type": "application/json",
    },
    body: JSON.stringify({
      model: "claude-3-5-haiku-latest",
      max_tokens: 200,
      messages: [
        {
          role: "user",
          content:
            "You are generating a short, operational adherence insight for a " +
            "medication-monitoring dashboard. Do not suggest medical or " +
            "clinical decisions. Summarize the pattern in 1-2 sentences.\n\n" +
            summary,
        },
      ],
    }),
  });
  if (!res.ok) return "Insight generation failed for this period.";
  const json = (await res.json()) as { content?: { text?: string }[] };
  return json?.content?.[0]?.text ?? "No insight generated.";
}

export const aiInsightsBatch = onSchedule(
  { schedule: "0 2 * * *", secrets: [AI_API_KEY] },
  async () => {
    const since = new Date();
    since.setDate(since.getDate() - 1);

    const patientsSnap = await db.collection("patients").get();
    let generated = 0;

    for (const patientDoc of patientsSnap.docs) {
      const eventsSnap = await db
        .collection("medication_events")
        .where("patientId", "==", patientDoc.id)
        .where("scheduledAt", ">=", Timestamp.fromDate(since))
        .get();

      if (eventsSnap.empty) continue;

      const events = eventsSnap.docs.map((d) => d.data());
      const consumed = events.filter((e) => e.finalStatus === "consumed").length;
      const missed = events.filter(
        (e) => e.finalStatus === "missed" || e.finalStatus === "not_consumed",
      ).length;
      const summary =
        `Scheduled doses: ${events.length}. Consumed: ${consumed}. Missed: ${missed}. ` +
        `Adherence: ${Math.round((consumed / events.length) * 100)}%.`;

      const insightText = await generateInsight(summary, AI_API_KEY.value());

      await db.collection("ai_insights").add({
        scopeType: "patient",
        scopeId: patientDoc.id,
        insightText,
        generatedAt: new Date(),
      });
      generated++;
    }

    console.log(`aiInsightsBatch: generated ${generated} insight(s)`);
  },
);
