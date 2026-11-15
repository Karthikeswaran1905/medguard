// escalation-engine (Section 15, 40, 48)
//
// Runs every minute on Supabase Cron. Walks open medication_events and
// advances escalation_level once the response window for the current
// level has elapsed (escalation_policies), calling send-notification at
// each step:
//
//   patient (no response) -> caretaker (no response) -> incharge
//   (no response) -> critical_unresolved: family_contacts + Admin/Dean,
//   requiring manual acknowledgement (ack_by/ack_at) — Section 40.

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const DEFAULT_WINDOWS: Record<string, number> = {
  patient: 15,
  caretaker: 20,
  incharge: 30,
};

async function windowFor(admin: ReturnType<typeof createClient>, orgId: string | null, level: string) {
  const { data } = await admin
    .from("escalation_policies")
    .select("window_minutes")
    .eq("level", level)
    .eq("org_id", orgId)
    .maybeSingle();
  if (data) return data.window_minutes as number;

  const { data: fallback } = await admin
    .from("escalation_policies")
    .select("window_minutes")
    .eq("level", level)
    .is("org_id", null)
    .maybeSingle();
  return (fallback?.window_minutes as number) ?? DEFAULT_WINDOWS[level];
}

Deno.serve(async () => {
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date();

  const { data: events, error } = await admin
    .from("medication_events")
    .select("*, patients(id, profiles(org_id))")
    .eq("final_status", "pending")
    .lte("scheduled_at", now.toISOString());

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let escalated = 0;

  for (const event of events ?? []) {
    // deno-lint-ignore no-explicit-any
    const orgId = (event as any).patients?.profiles?.org_id ?? null;
    const level = event.escalation_level as string;
    const minutes = await windowFor(admin, orgId, level === "critical_unresolved" ? "incharge" : level);
    const elapsedMinutes = (now.getTime() - new Date(event.scheduled_at).getTime()) / 60000;

    if (elapsedMinutes < minutes) continue;

    if (level === "patient") {
      await admin.from("medication_events").update({ escalation_level: "caretaker" }).eq("id", event.id);
      await admin.functions.invoke("send-notification", {
        body: { type: "caretaker_alert", event_id: event.id },
      });
      escalated++;
    } else if (level === "caretaker") {
      await admin.from("medication_events").update({ escalation_level: "incharge" }).eq("id", event.id);
      await admin.functions.invoke("send-notification", {
        body: { type: "incharge_alert", event_id: event.id },
      });
      escalated++;
    } else if (level === "incharge") {
      // Final parallel escalation (Section 40): family contacts + Admin/Dean.
      await admin
        .from("medication_events")
        .update({ escalation_level: "critical_unresolved", final_status: "missed" })
        .eq("id", event.id);
      await admin.functions.invoke("send-notification", {
        body: { type: "critical_unresolved", event_id: event.id },
      });
      await admin.from("audit_logs").insert({
        action: "escalation_critical_unresolved",
        details: { event_id: event.id },
      });
      escalated++;
    }
    // 'critical_unresolved' events wait for a human to set ack_by/ack_at —
    // the engine does not advance them further.
  }

  return new Response(JSON.stringify({ ok: true, escalated }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
