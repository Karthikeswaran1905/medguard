-- MedGuard — Performance advisor fixes (Section 46/49 addendum).
--
-- Supabase's performance advisor flagged three categories of finding
-- after 0001-0003 were applied to the live project:
--
--   1. unindexed_foreign_keys (18×) — every FK column below is one a
--      policy or repository query filters/joins on (Section 25's
--      permission checks all walk these relationships), so an unindexed
--      FK means a sequential scan on every RLS check, not just every
--      explicit query.
--   2. auth_rls_initplan (25×) — a bare `auth.uid()` inside a policy is
--      re-evaluated once per row; wrapping it as `(select auth.uid())`
--      lets Postgres hoist it into a one-time InitPlan instead. Policies
--      that only call `private.auth_role()`/`private.auth_org_id()`
--      (already STABLE functions) were not flagged and are left as-is.
--   3. multiple_permissive_policies (10× — 5 Postgres roles × 2 tables) —
--      Postgres ORs together every permissive policy that applies to a
--      command, so an overlapping pair is evaluated twice for no benefit:
--        - escalation_policies: `..._admin_write` (for all) overlapped
--          `..._select` on SELECT — split into insert/update/delete-only
--          policies so admin write no longer covers SELECT.
--        - medication_events: the separate patient/caretaker UPDATE
--          policies overlapped each other — merged into one.
--
-- Re-running `get_advisors(performance)` after this migration should show
-- only the (expected, informational) `unused_index` findings on an
-- otherwise-empty database.

-- ---------------------------------------------------------------------
-- 1. Covering indexes for previously-unindexed foreign keys.
-- ---------------------------------------------------------------------
create index if not exists idx_assignments_caretaker_id on assignments (caretaker_id);
create index if not exists idx_assignments_incharge_id on assignments (incharge_id);
create index if not exists idx_audit_logs_actor_id on audit_logs (actor_id);
create index if not exists idx_doctor_patient_links_patient_id on doctor_patient_links (patient_id);
create index if not exists idx_family_contacts_patient_id on family_contacts (patient_id);
create index if not exists idx_medication_events_ack_by on medication_events (ack_by);
create index if not exists idx_medication_events_medicine_id on medication_events (medicine_id);
create index if not exists idx_medication_events_schedule_id on medication_events (schedule_id);
create index if not exists idx_medication_schedules_medicine_id on medication_schedules (medicine_id);
create index if not exists idx_medication_schedules_patient_id on medication_schedules (patient_id);
create index if not exists idx_medicines_prescription_id on medicines (prescription_id);
create index if not exists idx_notifications_event_id on notifications (event_id);
create index if not exists idx_notifications_target_user_id on notifications (target_user_id);
create index if not exists idx_patient_invites_doctor_id on patient_invites (doctor_id);
create index if not exists idx_patient_invites_org_id on patient_invites (org_id);
create index if not exists idx_prescriptions_doctor_id on prescriptions (doctor_id);
create index if not exists idx_prescriptions_patient_id on prescriptions (patient_id);
create index if not exists idx_profiles_org_id on profiles (org_id);

-- ---------------------------------------------------------------------
-- 2. Wrap auth.uid() as (select auth.uid()) in every policy that calls
--    it directly, so Postgres evaluates it once per statement instead of
--    once per row.
-- ---------------------------------------------------------------------
drop policy if exists profiles_self_select on profiles;
create policy profiles_self_select on profiles
  for select using (
    id = (select auth.uid())
    or org_id = private.auth_org_id()
  );

drop policy if exists profiles_self_update on profiles;
create policy profiles_self_update on profiles
  for update using (id = (select auth.uid()));

drop policy if exists profiles_self_insert on profiles;
create policy profiles_self_insert on profiles
  for insert with check (id = (select auth.uid()));

drop policy if exists patients_select on patients;
create policy patients_select on patients
  for select using (
    id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = patients.id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = patients.id and l.doctor_id = (select auth.uid())
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists patients_self_upsert on patients;
create policy patients_self_upsert on patients
  for insert with check (id = (select auth.uid()));

drop policy if exists patients_self_update on patients;
create policy patients_self_update on patients
  for update using (id = (select auth.uid()));

drop policy if exists patient_invites_doctor_scope on patient_invites;
create policy patient_invites_doctor_scope on patient_invites
  for all using (doctor_id = (select auth.uid())) with check (doctor_id = (select auth.uid()));

drop policy if exists doctor_patient_links_select on doctor_patient_links;
create policy doctor_patient_links_select on doctor_patient_links
  for select using (doctor_id = (select auth.uid()) or patient_id = (select auth.uid()));

drop policy if exists assignments_select on assignments;
create policy assignments_select on assignments
  for select using (
    incharge_id = (select auth.uid())
    or caretaker_id = (select auth.uid())
    or patient_id = (select auth.uid())
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists assignments_doctor_insert on assignments;
create policy assignments_doctor_insert on assignments
  for insert with check (
    exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists assignments_update on assignments;
create policy assignments_update on assignments
  for update using (
    incharge_id = (select auth.uid())
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists prescriptions_select on prescriptions;
create policy prescriptions_select on prescriptions
  for select using (
    patient_id = (select auth.uid())
    or doctor_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = prescriptions.patient_id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists prescriptions_doctor_write on prescriptions;
create policy prescriptions_doctor_write on prescriptions
  for insert with check (
    doctor_id = (select auth.uid())
    and exists (
      select 1 from doctor_patient_links l
      where l.patient_id = prescriptions.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists medicines_select on medicines;
create policy medicines_select on medicines
  for select using (
    exists (
      select 1 from prescriptions p
      where p.id = medicines.prescription_id
        and (
          p.patient_id = (select auth.uid())
          or p.doctor_id = (select auth.uid())
          or exists (
            select 1 from assignments a
            where a.patient_id = p.patient_id
              and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
          )
        )
    )
  );

drop policy if exists medicines_doctor_write on medicines;
create policy medicines_doctor_write on medicines
  for insert with check (
    exists (
      select 1 from prescriptions p
      where p.id = medicines.prescription_id and p.doctor_id = (select auth.uid())
    )
  );

drop policy if exists medication_schedules_select on medication_schedules;
create policy medication_schedules_select on medication_schedules
  for select using (
    patient_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_schedules.patient_id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_schedules.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists medication_schedules_doctor_write on medication_schedules;
create policy medication_schedules_doctor_write on medication_schedules
  for insert with check (
    exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_schedules.patient_id and l.doctor_id = (select auth.uid())
    )
  );

drop policy if exists medication_events_select on medication_events;
create policy medication_events_select on medication_events
  for select using (
    patient_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_events.patient_id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_events.patient_id and l.doctor_id = (select auth.uid())
    )
    or private.auth_role() = 'admin'
  );

drop policy if exists family_contacts_select on family_contacts;
create policy family_contacts_select on family_contacts
  for select using (
    patient_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = family_contacts.patient_id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
  );

drop policy if exists family_contacts_incharge_write on family_contacts;
create policy family_contacts_incharge_write on family_contacts
  for insert with check (
    exists (
      select 1 from assignments a
      where a.patient_id = family_contacts.patient_id and a.incharge_id = (select auth.uid())
    )
  );

drop policy if exists device_tokens_owner on device_tokens;
create policy device_tokens_owner on device_tokens
  for all using (user_id = (select auth.uid())) with check (user_id = (select auth.uid()));

drop policy if exists notifications_select on notifications;
create policy notifications_select on notifications
  for select using (target_user_id = (select auth.uid()));

drop policy if exists ai_insights_select on ai_insights;
create policy ai_insights_select on ai_insights
  for select using (
    scope_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = ai_insights.scope_id
        and (a.caretaker_id = (select auth.uid()) or a.incharge_id = (select auth.uid()))
    )
    or private.auth_role() = 'admin'
  );

-- ---------------------------------------------------------------------
-- 3a. medication_events — merge the separate patient/caretaker UPDATE
--     policies into one, so only a single permissive policy applies to
--     UPDATE instead of two overlapping ones. Same effective grant as
--     before: a patient can update their own event, a caretaker can
--     update an event for a patient they're assigned to.
-- ---------------------------------------------------------------------
drop policy if exists medication_events_patient_update on medication_events;
drop policy if exists medication_events_caretaker_update on medication_events;
create policy medication_events_update on medication_events
  for update using (
    patient_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_events.patient_id and a.caretaker_id = (select auth.uid())
    )
  )
  with check (
    patient_id = (select auth.uid())
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_events.patient_id and a.caretaker_id = (select auth.uid())
    )
  );

-- ---------------------------------------------------------------------
-- 3b. escalation_policies — split the `for all` admin-write policy into
--     insert/update/delete-only policies so it no longer overlaps
--     escalation_policies_select on SELECT. (No auth.uid() wrapping
--     needed here — these only call the already-STABLE
--     private.auth_role(), which wasn't flagged.)
-- ---------------------------------------------------------------------
drop policy if exists escalation_policies_admin_write on escalation_policies;

create policy escalation_policies_admin_insert on escalation_policies
  for insert with check (private.auth_role() = 'admin');

create policy escalation_policies_admin_update on escalation_policies
  for update using (private.auth_role() = 'admin') with check (private.auth_role() = 'admin');

create policy escalation_policies_admin_delete on escalation_policies
  for delete using (private.auth_role() = 'admin');
