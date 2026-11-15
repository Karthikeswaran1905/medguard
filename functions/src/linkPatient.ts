// linkPatient (Section 39, 48)
//
// Validates a patient_invites code and creates the authorized
// doctor_patient_links document. Called by the Flutter app right after a
// patient signs up with an invite code (AuthRepository.signUpPatient).
//
// Uses the Admin SDK so it can write doctor_patient_links regardless of
// the caller's own Firestore Security Rules grants — the validation logic
// below is what keeps this safe, not the database permissions.

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db } from "./admin";

interface LinkPatientRequest {
  code: string;
  patientId: string;
}

export const linkPatient = onCall<LinkPatientRequest>(async (request) => {
  const { code, patientId } = request.data;
  if (!code || !patientId) {
    throw new HttpsError("invalid-argument", "code and patientId are required");
  }

  // The invite document id *is* the code (see PeopleRepository.generateInviteCode).
  const inviteRef = db.collection("patient_invites").doc(code.toUpperCase());
  const invite = await inviteRef.get();

  if (!invite.exists) {
    throw new HttpsError("not-found", "Invalid invite code");
  }
  const inviteData = invite.data()!;
  if (inviteData.usedAt) {
    throw new HttpsError("failed-precondition", "This code has already been used");
  }
  if (inviteData.expiresAt.toDate() < new Date()) {
    throw new HttpsError("deadline-exceeded", "This code has expired");
  }

  const doctorId = inviteData.doctorId as string;
  const linkId = `${doctorId}_${patientId}`;

  await db.collection("doctor_patient_links").doc(linkId).set({
    doctorId,
    patientId,
    status: "active",
    linkedAt: new Date(),
  });

  await inviteRef.update({ usedAt: new Date() });

  // Copy the doctor's org onto the newly-linked patient (Section 38).
  if (inviteData.orgId) {
    await db.collection("profiles").doc(patientId).update({ orgId: inviteData.orgId });
  }

  await db.collection("audit_logs").add({
    actorId: patientId,
    action: "patient_linked_via_invite",
    details: { doctorId, code },
    createdAt: new Date(),
  });

  return { ok: true, doctorId };
});
