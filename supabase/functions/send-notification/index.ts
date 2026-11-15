// send-notification (Section 43, 48)
//
// The single place that owns outbound delivery — the Flutter client never
// calls FCM directly. Looks up the right recipients for the event/type,
// sends a push via Firebase Cloud Messaging, and logs every attempt to
// `notifications` regardless of outcome so delivery failures are visible
// (Section 43, 49 "Observability").
//
// Requires the FCM_SERVER_KEY secret:
//   supabase secrets set FCM_SERVER_KEY=...

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const fcmServerKey = Deno.env.get("FCM_SERVER_KEY");

type NotificationType =
  | "patient_reminder"
  | "caretaker_alert"
  | "incharge_alert"
  | "critical_unresolved";

async function sendPush(token: string, title: string, body: string) {
  if (!fcmServerKey) return { ok: false, reason: "FCM_SERVER_KEY not configured" };
  const res = await fetch("https://fcm.googleapis.com/fcm/send", {
    method: "POST",
    headers: {
      Authorization: `key=${fcmServerKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({ to: token, notification: { title, body } }),
  });
  return { ok: res.ok };
}

Deno.serve(async (req) => {
  const { type, event_id } = (await req.json()) as {
    type: NotificationType;
    event_id: string;
  };

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: event } = await admin
    .from("medication_events")
    .select("*, medicines(name), patients(id)")
    .eq("id", event_id)
    .single();

  if (!event) {
    return new Response(JSON.stringify({ error: "event not found" }), { status: 404 });
  }

  const targets: string[] = [];
  let title = "MedGuard";
  let body = "A medication event needs attention.";

  if (type === "patient_reminder") {
    targets.push(event.patient_id);
    title = "Time for your medicine";
    // deno-lint-ignore no-explicit-any
    body = `${(event as any).medicines?.name ?? "Your medicine"} is due now.`;
  } else if (type === "caretaker_alert") {
    const { data: assignment } = await admin
      .from("assignments")
      .select("caretaker_id")
      .eq("patient_id", event.patient_id)
      .maybeSingle();
    if (assignment?.caretaker_id) targets.push(assignment.caretaker_id);
    title = "Patient has not confirmed a dose";
    body = "Please check in and verify.";
  } else if (type === "incharge_alert") {
    const { data: assignment } = await admin
      .from("assignments")
      .select("incharge_id")
      .eq("patient_id", event.patient_id)
      .maybeSingle();
    if (assignment?.incharge_id) targets.push(assignment.incharge_id);
    title = "Escalated: no caretaker response";
    body = "A medication event needs your review.";
  } else if (type === "critical_unresolved") {
    title = "Critical: unresolved medication event";
    body = "No response at any level. Family contacts and Admin/Dean notified.";
    const { data: admins } = await admin.from("profiles").select("id").eq("role", "admin");
    for (const a of admins ?? []) targets.push(a.id);
    // Family contacts don't have app accounts, so they're logged separately
    // below rather than pushed via FCM (an SMS/voice provider would plug in
    // here in a full deployment).
    const { data: contacts } = await admin
      .from("family_contacts")
      .select("id, phone")
      .eq("patient_id", event.patient_id);
    for (const c of contacts ?? []) {
      await admin.from("notifications").insert({
        channel: "sms",
        event_id,
        status: "queued",
      });
    }
  }

  for (const userId of targets) {
    const { data: tokens } = await admin
      .from("device_tokens")
      .select("token")
      .eq("user_id", userId);

    let status = "failed";
    for (const t of tokens ?? []) {
      const result = await sendPush(t.token as string, title, body);
      if (result.ok) status = "sent";
    }
    await admin.from("notifications").insert({
      channel: "push",
      target_user_id: userId,
      event_id,
      status,
      sent_at: status === "sent" ? new Date().toISOString() : null,
    });
  }

  return new Response(JSON.stringify({ ok: true, targets: targets.length }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
