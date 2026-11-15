-- MedGuard — Security advisor fixes (Section 46 addendum).
--
-- Supabase's security advisor flagged two issues after 0001+0002 were
-- applied to the live project:
--   1. `organizations` had RLS enabled but zero policies — nobody, not
--      even an org's own Admin, could read or update their org row.
--   2. `auth_org_id()`/`auth_role()` lived in the `public` schema, which
--      PostgREST auto-exposes as callable RPCs
--      (`/rest/v1/rpc/auth_org_id`) to `anon` and `authenticated` — not
--      dangerous by itself (they only ever return the caller's own data),
--      but unnecessary surface area for a SECURITY DEFINER function.
--      Moving them to a `private` schema (never exposed by PostgREST)
--      closes that off, while every policy that calls them keeps working:
--      RLS policy evaluation still runs as the querying role, so that role
--      needs EXECUTE on the function it calls — hence the explicit
--      revoke-then-grant below rather than relying on default grants.

create schema if not exists private;

create or replace function private.auth_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select org_id from profiles where id = auth.uid();
$$;

create or replace function private.auth_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from profiles where id = auth.uid();
$$;

revoke all on function private.auth_org_id() from public, anon, authenticated;
revoke all on function private.auth_role() from public, anon, authenticated;
grant execute on function private.auth_org_id() to authenticated;
grant execute on function private.auth_role() to authenticated;

-- ---------------------------------------------------------------------
-- Re-point every policy that referenced the old public.* helpers at the
-- private.* versions. Each is dropped and recreated rather than altered
-- in place (Postgres has no `alter policy ... using`, so this is the
-- normal way to change a policy's condition).
-- ---------------------------------------------------------------------
drop policy if exists profiles_self_select on profiles;
create policy profiles_self_select on profiles
  for select using (
    id = auth.uid()
    or org_id = private.auth_org_id()
  );

drop policy if exists patients_select on patients;
create policy patients_select on patients
  for select using (
    id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = patients.id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = patients.id and l.doctor_id = auth.uid()
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists prescriptions_select on prescriptions;
create policy prescriptions_select on prescriptions
  for select using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = prescriptions.patient_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists medication_events_select on medication_events;
create policy medication_events_select on medication_events
  for select using (
    patient_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_events.patient_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_events.patient_id and l.doctor_id = auth.uid()
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists escalation_policies_select on escalation_policies;
create policy escalation_policies_select on escalation_policies
  for select using (org_id is null or org_id = private.auth_org_id());

drop policy if exists escalation_policies_admin_write on escalation_policies;
create policy escalation_policies_admin_write on escalation_policies
  for all using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

drop policy if exists ai_insights_select on ai_insights;
create policy ai_insights_select on ai_insights
  for select using (
    scope_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = ai_insights.scope_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists audit_logs_admin_select on audit_logs;
create policy audit_logs_admin_select on audit_logs
  for select using (private.auth_role() = 'admin');

-- `organizations` had RLS enabled with no policies at all — the two
-- policies that should have shipped with 0002.
create policy organizations_select on organizations
  for select using (id = private.auth_org_id());

create policy organizations_admin_update on organizations
  for update using (private.auth_role() = 'admin' and id = private.auth_org_id());

-- The public.* originals are no longer referenced by any policy — drop
-- them so there's exactly one copy of this logic (and nothing left for
-- PostgREST to expose).
drop function if exists public.auth_org_id();
drop function if exists public.auth_role();
