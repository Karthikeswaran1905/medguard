// schedule-generator (Section 41, 48)
//
// Runs every minute on Supabase Cron. For each active medication_schedule,
// computes the next local dose time in the patient's own timezone
// (profiles.timezone) and materializes a medication_events row once that
// time has arrived — this is what keeps scheduling correct across
// timezones (Section 41) instead of assuming a single fixed offset.
//
// Deploy + schedule (see SETUP.md):
//   supabase functions deploy schedule-generator
//   select cron.schedule('schedule-generator', '* * * * *',
//     $$ select net.http_post(url := '<function-url>') $$);

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async () => {
  const admin = createClient(supabaseUrl, serviceRoleKey);
  const now = new Date();

  const { data: schedules, error } = await admin
    .from("medication_schedules")
    .select("id, medicine_id, patient_id, time_of_day, patients(id, profiles(timezone))");

  if (error) {
    return new Response(JSON.stringify({ error: error.message }), { status: 500 });
  }

  let created = 0;

  for (const schedule of schedules ?? []) {
    // deno-lint-ignore no-explicit-any
    const timezone = (schedule as any).patients?.profiles?.timezone ?? "Asia/Kolkata";
    const [hh, mm] = (schedule.time_of_day as string).split(":").map(Number);

    // Compute "today, at hh:mm, in the patient's timezone" as a UTC instant.
    const localNowStr = now.toLocaleString("en-US", { timeZone: timezone });
    const localNow = new Date(localNowStr);
    const scheduledLocal = new Date(localNow);
    scheduledLocal.setHours(hh, mm, 0, 0);
    const offsetMs = now.getTime() - localNow.getTime();
    const scheduledAtUtc = new Date(scheduledLocal.getTime() + offsetMs);

    // Only materialize once the scheduled minute has arrived.
    if (scheduledAtUtc > now) continue;

    const dayStartUtc = new Date(scheduledAtUtc);
    dayStartUtc.setUTCHours(0, 0, 0, 0);

    const { data: existing } = await admin
      .from("medication_events")
      .select("id")
      .eq("schedule_id", schedule.id)
      .gte("scheduled_at", dayStartUtc.toISOString())
      .maybeSingle();
    if (existing) continue;

    const { error: insertError } = await admin.from("medication_events").insert({
      patient_id: schedule.patient_id,
      medicine_id: schedule.medicine_id,
      schedule_id: schedule.id,
      scheduled_at: scheduledAtUtc.toISOString(),
      patient_status: "pending",
      caretaker_status: "pending",
      final_status: "pending",
      escalation_level: "patient",
    });
    if (!insertError) created++;
  }

  return new Response(JSON.stringify({ ok: true, created }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
