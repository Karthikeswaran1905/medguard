// ai-insights-batch (Section 44, 48)
//
// Runs nightly on Supabase Cron. Aggregates the day's medication_events
// per patient into a compact, minimally-identifying summary, sends it to
// an external AI provider, and stores the returned text in ai_insights.
// Dashboards read pre-generated insights — nothing in the Flutter app
// calls the AI provider directly, and this function's service role has no
// write access to prescriptions/medicines/schedules, so AI cannot alter
// clinical data even if the response were malformed (Section 19, 44).
//
// Requires the AI_API_KEY secret:
//   supabase secrets set AI_API_KEY=...

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const aiApiKey = Deno.env.get("AI_API_KEY");
const aiApiUrl = Deno.env.get("AI_API_URL") ?? "https://api.anthropic.com/v1/messages";

async function generateInsight(summary: string): Promise<string> {
  if (!aiApiKey) {
    return "AI insight generation is not configured (AI_API_KEY missing).";
  }
  const res = await fetch(aiApiUrl, {
    method: "POST",
    headers: {
      "x-api-key": aiApiKey,
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
  const json = await res.json();
  return json?.content?.[0]?.text ?? "No insight generated.";
}

Deno.serve(async () => {
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const since = new Date();
  since.setDate(since.getDate() - 1);

  const { data: patients } = await admin.from("patients").select("id");
  let generated = 0;

  for (const patient of patients ?? []) {
    const { data: events } = await admin
      .from("medication_events")
      .select("final_status, scheduled_at")
      .eq("patient_id", patient.id)
      .gte("scheduled_at", since.toISOString());

    if (!events || events.length === 0) continue;

    const consumed = events.filter((e) => e.final_status === "consumed").length;
    const missed = events.filter((e) => e.final_status === "missed" || e.final_status === "not_consumed").length;
    const summary =
      `Scheduled doses: ${events.length}. Consumed: ${consumed}. Missed: ${missed}. ` +
      `Adherence: ${Math.round((consumed / events.length) * 100)}%.`;

    const insightText = await generateInsight(summary);

    await admin.from("ai_insights").insert({
      scope_type: "patient",
      scope_id: patient.id,
      insight_text: insightText,
    });
    generated++;
  }

  return new Response(JSON.stringify({ ok: true, generated }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
