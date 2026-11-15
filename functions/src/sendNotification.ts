// sendNotification (Section 43, 48)
//
// The single place that owns outbound delivery — the Flutter client never
// calls FCM directly. Looks up the right recipients for the event/type,
// sends a push via Firebase Cloud Messaging (the same FCM the original
// Supabase version called over HTTP — here it's the native Admin SDK
// integration, so no FCM_SERVER_KEY secret is needed at all), and logs
// every attempt to `notifications` regardless of outcome so delivery
// failures are visible (Section 43, 49 "Observability").
//
// Exported twice: `sendNotificationInternal` is what `escalationEngine`
// calls directly (same process, no extra network hop); `sendNotification`
// is the onCall wrapper kept for parity with the original architecture,
// where send-notification was independently invocable.

import { onCall } from "firebase-functions/v2/https";
import { db, messaging } from "./admin";

type NotificationType =
  | "patient_reminder"
  | "caretaker_alert"
  | "incharge_alert"
  | "critical_unresolved";

async function sendPush(token: string, title: string, body: string): Promise<boolean> {
  try {
    await messaging.send({ token, notification: { title, body } });
    return true;
  } catch (err) {
    console.error("sendPush failed", err);
    return false;
  }
}

export async function sendNotificationInternal(
  type: NotificationType,
  eventId: string,
): Promise<{ ok: true; targets: number }> {
  const eventSnap = await db.collection("medication_events").doc(eventId).get();
  const event = eventSnap.data();
  if (!event) {
    return { ok: true, targets: 0 };
  }

  const targets: string[] = [];
  let title = "MedGuard";
  let body = "A medication event needs attention.";

  if (type === "patient_reminder") {
    targets.push(event.patientId);
    title = "Time for your medicine";
    body = `${event.medicineName ?? "Your medicine"} is due now.`;
  } else if (type === "caretaker_alert") {
    const assignment = await db.collection("assignments").doc(event.patientId).get();
    const caretakerId = assignment.data()?.caretakerId as string | undefined;
    if (caretakerId) targets.push(caretakerId);
    title = "Patient has not confirmed a dose";
    body = "Please check in and verify.";
  } else if (type === "incharge_alert") {
    const assignment = await db.collection("assignments").doc(event.patientId).get();
    const inchargeId = assignment.data()?.inchargeId as string | undefined;
    if (inchargeId) targets.push(inchargeId);
    title = "Escalated: no caretaker response";
    body = "A medication event needs your review.";
  } else if (type === "critical_unresolved") {
    title = "Critical: unresolved medication event";
    body = "No response at any level. Family contacts and Admin/Dean notified.";
    const admins = await db.collection("profiles").where("role", "==", "admin").get();
    for (const a of admins.docs) targets.push(a.id);

    // Family contacts don't have app accounts, so they're logged separately
    // below rather than pushed via FCM (an SMS/voice provider would plug in
    // here in a full deployment).
    const contacts = await db
      .collection("family_contacts")
      .where("patientId", "==", event.patientId)
      .get();
    for (const _c of contacts.docs) {
      await db.collection("notifications").add({
        channel: "sms",
        eventId,
        status: "queued",
        sentAt: null,
      });
    }
  }

  for (const userId of targets) {
    const tokensSnap = await db.collection("device_tokens").where("userId", "==", userId).get();

    let status = "failed";
    for (const t of tokensSnap.docs) {
      const ok = await sendPush(t.data().token as string, title, body);
      if (ok) status = "sent";
    }
    await db.collection("notifications").add({
      channel: "push",
      targetUserId: userId,
      eventId,
      status,
      sentAt: status === "sent" ? new Date() : null,
    });
  }

  return { ok: true, targets: targets.length };
}

interface SendNotificationRequest {
  type: NotificationType;
  eventId: string;
}

export const sendNotification = onCall<SendNotificationRequest>(async (request) => {
  const { type, eventId } = request.data;
  return sendNotificationInternal(type, eventId);
});
