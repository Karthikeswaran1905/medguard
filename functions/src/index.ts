// MedGuard Cloud Functions — entry point.
//
// Firebase replacement for the original 6 Supabase Edge Functions
// (Section 48 of the architecture report). Deploy all at once with
// `firebase deploy --only functions`, or one at a time with
// `firebase deploy --only functions:linkPatient` etc.
//
// Cloud Functions require Firebase's Blaze (pay-as-you-go) plan — Spark
// can't deploy any of these. `createStaffUser` is exported below for
// completeness but the app itself no longer calls it: on Spark,
// `PeopleRepository.createStaffAccount` creates Doctor/Incharge/Caretaker
// accounts client-side instead (see that method's doc comment). The rest
// — `linkPatient`, `scheduleGenerator`, `escalationEngine`,
// `sendNotification`, `aiInsightsBatch` — still need Blaze; there's no
// client-side equivalent for those yet.

export { createStaffUser } from "./createStaffUser";
export { linkPatient } from "./linkPatient";
export { scheduleGenerator } from "./scheduleGenerator";
export { escalationEngine } from "./escalationEngine";
export { sendNotification } from "./sendNotification";
export { aiInsightsBatch } from "./aiInsightsBatch";
