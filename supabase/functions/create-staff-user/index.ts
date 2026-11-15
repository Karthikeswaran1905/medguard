// create-staff-user (Section 39, 48)
//
// Admin -> Doctor, Doctor -> Incharge, Incharge -> Caretaker (Section 11).
// Creating another person's login requires the Supabase admin API, which
// only works with the service role — this is why the Flutter app can't do
// it directly with the anon key (PeopleRepository.createStaffAccount calls
// this function instead).
//
// The caller's own role is checked against who they're allowed to create,
// mirroring the management chain in Section 11 and the permission matrix
// in Section 25:
//   admin    -> doctor
//   doctor   -> incharge
//   incharge -> caretaker

import { createClient } from "jsr:@supabase/supabase-js@2";

const supabaseUrl = Deno.env.get("SUPABASE_URL")!;
const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

const ALLOWED_CREATION: Record<string, string> = {
  admin: "doctor",
  doctor: "incharge",
  incharge: "caretaker",
};

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const authHeader = req.headers.get("Authorization") ?? "";
  const jwt = authHeader.replace("Bearer ", "");
  if (!jwt) {
    return new Response(JSON.stringify({ error: "Missing Authorization header" }), {
      status: 401,
    });
  }

  const admin = createClient(supabaseUrl, serviceRoleKey);

  // Identify the caller and their role from their own JWT.
  const { data: callerAuth, error: callerAuthError } = await admin.auth.getUser(jwt);
  if (callerAuthError || !callerAuth.user) {
    return new Response(JSON.stringify({ error: "Invalid session" }), { status: 401 });
  }
  const { data: callerProfile } = await admin
    .from("profiles")
    .select("role, org_id")
    .eq("id", callerAuth.user.id)
    .single();

  const body = await req.json();
  const { email, full_name, phone, role, org_id } = body;

  if (!email || !full_name || !role) {
    return new Response(JSON.stringify({ error: "email, full_name and role are required" }), {
      status: 400,
    });
  }

  const expectedTargetRole = ALLOWED_CREATION[callerProfile?.role ?? ""];
  if (!expectedTargetRole || expectedTargetRole !== role) {
    return new Response(
      JSON.stringify({
        error: `A ${callerProfile?.role ?? "unknown"} account may not create a ${role} account`,
      }),
      { status: 403 },
    );
  }

  // Create the auth user with a temporary password; Supabase sends an
  // invite/reset email so they set their own on first login.
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    email_confirm: false,
    user_metadata: { full_name },
  });
  if (createError || !created.user) {
    return new Response(JSON.stringify({ error: createError?.message ?? "Could not create user" }), {
      status: 500,
    });
  }

  const newUserId = created.user.id;
  const effectiveOrgId = org_id ?? callerProfile?.org_id ?? null;

  await admin.from("profiles").insert({
    id: newUserId,
    org_id: effectiveOrgId,
    role,
    full_name,
    phone,
    email,
  });

  // Populate the role-specific table (Section 45).
  await admin.from(`${role}s`).insert({ id: newUserId });

  await admin.auth.admin.inviteUserByEmail(email);

  await admin.from("audit_logs").insert({
    actor_id: callerAuth.user.id,
    action: "staff_account_created",
    details: { new_user_id: newUserId, role },
  });

  return new Response(JSON.stringify({ ok: true, id: newUserId }), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
