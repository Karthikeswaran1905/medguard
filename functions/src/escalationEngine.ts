// escalationEngine (Section 15, 40, 48)
//
// Runs every minute on Cloud Scheduler. Walks open medication_events and
// advances escalationLevel once the response window for the current level
// has elapsed (escalation_policies), calling sendNotification at each step:
//
//   patient (no response) -> caretaker (no response) -> incharge
//   (no response) -> critical_unresolved: family_contacts + Admin/Dean,
//   requiring manual acknowledgement (ackBy/ackAt) — Section 40.

import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";
import { sendNotificationInternal } from "./sendNotification";

const DEFAULT_WINDOWS: Record<string, number> = {
  patient: 15,
  caretaker: 20,
  incharge: 30,
};

/// escalation_policies documents are keyed `{orgId|| 'default'}_{level}`
/// so an org override and the global default are both a direct get, same
/// as every other Admin-SDK lookup in this codebase — no query needed.
async function windowFor(orgId: string | null, level: string): Promise<number> {
  if (orgId) {
    const orgDoc = await db.collection("escalation_policies").doc(`${orgId}_${level}`).get();
    if (orgDoc.exists) return orgDoc.data()!.windowMinutes as number;
  }
  const defaultDoc = await db.collection("escalation_policies").doc(`default_${level}`).get();
  if (defaultDoc.exists) return defaultDoc.data()!.windowMinutes as number;
  return DEFAULT_WINDOWS[level] ?? 30;
}

export const escalationEngine = onSchedule("every 1 minutes", async () => {
  const now = new Date();

  const eventsSnap = await db
    .collection("medication_events")
    .where("finalStatus", "==", "pending")
    .where("scheduledAt", "<=", Timestamp.fromDate(now))
    .get();

  let escalated = 0;

  for (const eventDoc of eventsSnap.docs) {
    const event = eventDoc.data();
    const patientSnap = await db.collection("profiles").doc(event.patientId).get();
    const orgId = (patientSnap.data()?.orgId as string | undefined) ?? null;

    const level = event.escalationLevel as string;
    const windowLevel = level === "critical_unresolved" ? "incharge" : level;
    const minutes = await windowFor(orgId, windowLevel);
    const elapsedMinutes = (now.getTime() - event.scheduledAt.toDate().getTime()) / 60000;

    if (elapsedMinutes < minutes) continue;

    if (level === "patient") {
      await eventDoc.ref.update({ escalationLevel: "caretaker" });
      await sendNotificationInternal("caretaker_alert", eventDoc.id);
      escalated++;
    } else if (level === "caretaker") {
      await eventDoc.ref.update({ escalationLevel: "incharge" });
      await sendNotificationInternal("incharge_alert", eventDoc.id);
      escalated++;
    } else if (level === "incharge") {
      // Final parallel escalation (Section 40): family contacts + Admin/Dean.
      await eventDoc.ref.update({ escalationLevel: "critical_unresolved", finalStatus: "missed" });
      await sendNotificationInternal("critical_unresolved", eventDoc.id);
      await db.collection("audit_logs").add({
        action: "escalation_critical_unresolved",
        details: { eventId: eventDoc.id },
        createdAt: new Date(),
      });
      escalated++;
    }
    // 'critical_unresolved' events wait for a human to set ackBy/ackAt —
    // the engine does not advance them further.
  }

  console.log(`escalationEngine: escalated ${escalated} event(s)`);
});
