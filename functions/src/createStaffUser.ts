// createStaffUser (Section 39, 48)
//
// NOT CURRENTLY CALLED — Cloud Functions need Firebase's Blaze plan to
// deploy at all, and this project runs on Spark, so `PeopleRepository
// .createStaffAccount` was rewritten to do staff-account creation
// entirely client-side (secondary FirebaseApp + firestore.rules'
// canCreateStaffRole(), see that method's doc comment) instead of calling
// this function. This file is left in place, unchanged, for anyone who
// upgrades to Blaze and would rather do this the server-side way again —
// it's simpler and doesn't have the client version's "orphan Auth user
// with no profile" edge case.
//
// Admin -> Doctor, Doctor -> Incharge, Incharge -> Caretaker (Section 11).
// Creating another person's login requires the Firebase Admin SDK, which
// only runs server-side.
//
// The caller's own role is checked against who they're allowed to create,
// mirroring the management chain in Section 11 and the permission matrix
// in Section 25:
//   admin    -> doctor
//   doctor   -> incharge
//   incharge -> caretaker

import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, auth } from "./admin";

const ALLOWED_CREATION: Record<string, string> = {
  admin: "doctor",
  doctor: "incharge",
  incharge: "caretaker",
};

interface CreateStaffUserRequest {
  email: string;
  fullName: string;
  phone?: string;
  role: string; // doctor | incharge | caretaker
  orgId?: string | null;
}

export const createStaffUser = onCall<CreateStaffUserRequest>(async (request) => {
  if (!request.auth) {
    throw new HttpsError("unauthenticated", "Sign in required.");
  }
  const { email, fullName, phone, role, orgId } = request.data;
  if (!email || !fullName || !role) {
    throw new HttpsError("invalid-argument", "email, fullName and role are required");
  }

  const callerId = request.auth.uid;
  const callerProfileSnap = await db.collection("profiles").doc(callerId).get();
  const callerRole = callerProfileSnap.data()?.role as string | undefined;
  const callerOrgId = callerProfileSnap.data()?.orgId as string | undefined;

  const expectedTargetRole = ALLOWED_CREATION[callerRole ?? ""];
  if (!expectedTargetRole || expectedTargetRole !== role) {
    throw new HttpsError(
      "permission-denied",
      `A ${callerRole ?? "unknown"} account may not create a ${role} account`,
    );
  }

  // Create the auth user with a random temporary password; Firebase Auth
  // doesn't send invite emails itself the way Supabase's Admin API does —
  // a production deployment should email this link via its own provider
  // (SendGrid, etc.) rather than log it (see SETUP.md "Emailing invites").
  const created = await auth.createUser({
    email,
    emailVerified: false,
    password: cryptoRandomPassword(),
    displayName: fullName,
  });
  const newUserId = created.uid;
  const resetLink = await auth.generatePasswordResetLink(email);

  const effectiveOrgId = orgId ?? callerOrgId ?? null;

  await db.collection("profiles").doc(newUserId).set({
    orgId: effectiveOrgId,
    role,
    fullName,
    phone: phone ?? null,
    email,
    timezone: "Asia/Kolkata",
    createdAt: new Date(),
  });

  // Populate the role-specific collection (Section 45).
  await db.collection(`${role}s`).doc(newUserId).set({});

  await db.collection("audit_logs").add({
    actorId: callerId,
    action: "staff_account_created",
    details: { newUserId, role },
    createdAt: new Date(),
  });

  return { ok: true, id: newUserId, passwordResetLink: resetLink };
});

function cryptoRandomPassword(): string {
  const chars =
    "ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789!@#$%";
  let out = "";
  for (let i = 0; i < 20; i++) {
    out += chars[Math.floor(Math.random() * chars.length)];
  }
  return out;
}
