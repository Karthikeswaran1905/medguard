// scheduleGenerator (Section 41, 48)
//
// Runs every minute on Cloud Scheduler (wired automatically by `onSchedule`
// — no manual `gcloud scheduler` step needed, unlike the Supabase version
// which needed an explicit `cron.schedule(...)` SQL statement). For each
// active medication_schedule, computes the next local dose time in the
// patient's own timezone (profiles.timezone) and materializes a
// medication_events document once that time has arrived — this is what
// keeps scheduling correct across timezones (Section 41) instead of
// assuming a single fixed offset.
//
// Denormalizes medicineName/medicineDose onto the created event, since
// Firestore has no read-time join for the Flutter app to rely on (see
// lib/data/models/medication_models.dart).

import { onSchedule } from "firebase-functions/v2/scheduler";
import { Timestamp } from "firebase-admin/firestore";
import { db } from "./admin";

export const scheduleGenerator = onSchedule("every 1 minutes", async () => {
  const now = new Date();

  const schedulesSnap = await db.collection("medication_schedules").get();
  let created = 0;

  for (const scheduleDoc of schedulesSnap.docs) {
    const schedule = scheduleDoc.data();

    const patientSnap = await db.collection("profiles").doc(schedule.patientId).get();
    const timezone = (patientSnap.data()?.timezone as string) ?? "Asia/Kolkata";

    const [hh, mm] = (schedule.timeOfDay as string).split(":").map(Number);

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

    const existing = await db
      .collection("medication_events")
      .where("scheduleId", "==", scheduleDoc.id)
      .where("scheduledAt", ">=", Timestamp.fromDate(dayStartUtc))
      .limit(1)
      .get();
    if (!existing.empty) continue;

    const medicineSnap = await db.collection("medicines").doc(schedule.medicineId).get();
    const medicine = medicineSnap.data();

    await db.collection("medication_events").add({
      patientId: schedule.patientId,
      medicineId: schedule.medicineId,
      scheduleId: scheduleDoc.id,
      medicineName: medicine?.name ?? null,
      medicineDose: medicine?.dose ?? null,
      scheduledAt: Timestamp.fromDate(scheduledAtUtc),
      patientStatus: "pending",
      caretakerStatus: "pending",
      finalStatus: "pending",
      escalationLevel: "patient",
      createdAt: Timestamp.now(),
    });
    created++;
  }

  console.log(`scheduleGenerator: created ${created} event(s)`);
});
