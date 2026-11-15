// link-patient (Section 39, 48)
//
// Validates a patient_invites code and creates the authorized
// doctor_patient_links row. Called by the Flutter app right after a
// patient signs up with an invite code (AuthRepository.signUpPatient).
//
// Uses the service role so it can write doctor_patient_links regardless
// of the caller's own RLS grants — the validation logic below is what
// keeps this safe, not the database permissions.

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const { code, patient_id } = await req.json();
  if (!code || !patient_id) {
    return new Response(
      JSON.stringify({ error: "code and patient_id are required" }),
      { status: 400 },
    );
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  const { data: invite, error: inviteError } = await admin
    .from("patient_invites")
    .select("*")
    .eq("code", code.toUpperCase())
    .maybeSingle();

  if (inviteError || !invite) {
    return new Response(JSON.stringify({ error: "Invalid invite code" }), { status: 404 });
  }
  if (invite.used_at) {
    return new Response(JSON.stringify({ error: "This code has already been used" }), {
      status: 409,
    });
  }
  if (new Date(invite.expires_at) < new Date()) {
    return new Response(JSON.stringify({ error: "This code has expired" }), { status: 410 });
  }

  const { error: linkError } = await admin.from("doctor_patient_links").insert({
    doctor_id: invite.doctor_id,
    patient_id,
    status: "active",
  });
  if (linkError) {
    return new Response(JSON.stringify({ error: linkError.message }), { status: 500 });
  }

  await admin
    .from("patient_invites")
    .update({ used_at: new Date().toISOString() })
    .eq("id", invite.id);

  // Copy the doctor's org onto the newly-linked patient (Section 38).
  if (invite.org_id) {
    await admin.from("profiles").update({ org_id: invite.org_id }).eq("id", patient_id);
  }

  await admin.from("audit_logs").insert({
    actor_id: patient_id,
    action: "patient_linked_via_invite",
    details: { doctor_id: invite.doctor_id, code },
  });

  return new Response(JSON.stringify({ ok: true, doctor_id: invite.doctor_id }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
