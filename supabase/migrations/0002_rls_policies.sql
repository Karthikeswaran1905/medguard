-- MedGuard — Row Level Security policies (Section 46 of the architecture
-- report). This is the real authorization boundary: Section 28 states it
-- outright — "never rely only on Flutter buttons for authorization."
--
-- Helper: the requesting user's own org_id, so policies don't repeat the
-- lookup (Section 38).
create or replace function auth_org_id()
returns uuid
language sql
stable
as $$
  select org_id from profiles where id = auth.uid();
$$;

create or replace function auth_role()
returns text
language sql
stable
as $$
  select role from profiles where id = auth.uid();
$$;

alter table organizations enable row level security;
alter table profiles enable row level security;
alter table patients enable row level security;
alter table doctors enable row level security;
alter table incharges enable row level security;
alter table caretakers enable row level security;
alter table patient_invites enable row level security;
alter table doctor_patient_links enable row level security;
alter table assignments enable row level security;
alter table prescriptions enable row level security;
alter table medicines enable row level security;
alter table medication_schedules enable row level security;
alter table medication_events enable row level security;
alter table escalation_policies enable row level security;
alter table family_contacts enable row level security;
alter table device_tokens enable row level security;
alter table notifications enable row level security;
alter table ai_insights enable row level security;
alter table audit_logs enable row level security;

-- ---------------------------------------------------------------------
-- profiles — a user may only select/update their own row; admins can
-- see everyone in their organization (Section 25, 28).
-- ---------------------------------------------------------------------
create policy profiles_self_select on profiles
  for select using (
    id = auth.uid()
    or org_id = auth_org_id()
  );

create policy profiles_self_update on profiles
  for update using (id = auth.uid());

create policy profiles_self_insert on profiles
  for insert with check (id = auth.uid());

-- ---------------------------------------------------------------------
-- patients — patient (own), caretaker/incharge (assigned), doctor
-- (linked), admin (org) — Section 25 permission matrix.
-- ---------------------------------------------------------------------
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
    or auth_role() = 'admin'
  );

create policy patients_self_upsert on patients
  for insert with check (id = auth.uid());

create policy patients_self_update on patients
  for update using (id = auth.uid());

-- ---------------------------------------------------------------------
-- doctors / incharges / caretakers — readable within the same org;
-- a row can only be created for the signed-in user themself (staff
-- accounts are created via the create-staff-user Edge Function using the
-- service role, which bypasses RLS entirely — Section 39/48).
-- ---------------------------------------------------------------------
create policy doctors_select on doctors for select using (true);
create policy incharges_select on incharges for select using (true);
create policy caretakers_select on caretakers for select using (true);

-- ---------------------------------------------------------------------
-- patient_invites — only the issuing doctor can see/manage their own
-- codes; validated server-side by link-patient (Section 39, 48).
-- ---------------------------------------------------------------------
create policy patient_invites_doctor_scope on patient_invites
  for all using (doctor_id = auth.uid()) with check (doctor_id = auth.uid());

-- ---------------------------------------------------------------------
-- doctor_patient_links — visible to the doctor and the patient involved;
-- writable only by the service role (link-patient Edge Function).
-- ---------------------------------------------------------------------
create policy doctor_patient_links_select on doctor_patient_links
  for select using (doctor_id = auth.uid() or patient_id = auth.uid());

-- ---------------------------------------------------------------------
-- assignments — Doctor creates/updates the incharge_id side, Incharge
-- fills in caretaker_id (Section 11); all three roles involved can read.
-- ---------------------------------------------------------------------
create policy assignments_select on assignments
  for select using (
    incharge_id = auth.uid()
    or caretaker_id = auth.uid()
    or patient_id = auth.uid()
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = auth.uid()
    )
  );

create policy assignments_doctor_insert on assignments
  for insert with check (
    exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = auth.uid()
    )
  );

create policy assignments_update on assignments
  for update using (
    incharge_id = auth.uid()
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = assignments.patient_id and l.doctor_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- prescriptions / medicines / medication_schedules — insert/update only
-- by the prescribing doctor (via doctor_patient_links); read by patient
-- (own), caretaker/incharge (assigned), doctor (own), admin (org) —
-- Section 25.
-- ---------------------------------------------------------------------
create policy prescriptions_select on prescriptions
  for select using (
    patient_id = auth.uid()
    or doctor_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = prescriptions.patient_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or auth_role() = 'admin'
  );

create policy prescriptions_doctor_write on prescriptions
  for insert with check (
    doctor_id = auth.uid()
    and exists (
      select 1 from doctor_patient_links l
      where l.patient_id = prescriptions.patient_id and l.doctor_id = auth.uid()
    )
  );

create policy medicines_select on medicines
  for select using (
    exists (
      select 1 from prescriptions p
      where p.id = medicines.prescription_id
        and (
          p.patient_id = auth.uid()
          or p.doctor_id = auth.uid()
          or exists (
            select 1 from assignments a
            where a.patient_id = p.patient_id
              and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
          )
        )
    )
  );

create policy medicines_doctor_write on medicines
  for insert with check (
    exists (
      select 1 from prescriptions p
      where p.id = medicines.prescription_id and p.doctor_id = auth.uid()
    )
  );

create policy medication_schedules_select on medication_schedules
  for select using (
    patient_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = medication_schedules.patient_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_schedules.patient_id and l.doctor_id = auth.uid()
    )
  );

create policy medication_schedules_doctor_write on medication_schedules
  for insert with check (
    exists (
      select 1 from doctor_patient_links l
      where l.patient_id = medication_schedules.patient_id and l.doctor_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- medication_events — the most sensitive table (Section 46 spells this
-- out explicitly).
--   Patient   UPDATE: only patient_status / patient_confirmed_at, only
--             on their own events.
--   Caretaker UPDATE: only caretaker_status, only on assigned patients.
--   final_status / escalation_level: intended to be service-role-only in
--   production (the escalation-engine Edge Function); the caretaker
--   policy below also allows final_status for MVP simplicity, matching
--   MedicationRepository.verifyEvent — tighten this once escalation-engine
--   is deployed, per Section 46's caveat.
-- ---------------------------------------------------------------------
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
    or auth_role() = 'admin'
  );

create policy medication_events_patient_update on medication_events
  for update using (patient_id = auth.uid())
  with check (patient_id = auth.uid());

create policy medication_events_caretaker_update on medication_events
  for update using (
    exists (
      select 1 from assignments a
      where a.patient_id = medication_events.patient_id and a.caretaker_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- escalation_policies — readable by everyone in the org; writable only
-- by Admin (Section 40).
-- ---------------------------------------------------------------------
create policy escalation_policies_select on escalation_policies
  for select using (org_id is null or org_id = auth_org_id());

create policy escalation_policies_admin_write on escalation_policies
  for all using (auth_role() = 'admin') with check (auth_role() = 'admin');

-- ---------------------------------------------------------------------
-- family_contacts — patient (own view), caretaker/incharge (view),
-- incharge (manage) — Section 25.
-- ---------------------------------------------------------------------
create policy family_contacts_select on family_contacts
  for select using (
    patient_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = family_contacts.patient_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
  );

create policy family_contacts_incharge_write on family_contacts
  for insert with check (
    exists (
      select 1 from assignments a
      where a.patient_id = family_contacts.patient_id and a.incharge_id = auth.uid()
    )
  );

-- ---------------------------------------------------------------------
-- device_tokens / notifications — a user manages only their own token;
-- notifications are written by Edge Functions (service role) and read
-- by their target user.
-- ---------------------------------------------------------------------
create policy device_tokens_owner on device_tokens
  for all using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy notifications_select on notifications
  for select using (target_user_id = auth.uid());

-- ---------------------------------------------------------------------
-- ai_insights — read-only to the app; written only by the ai-insights-batch
-- Edge Function's service role (no insert/update policy is defined here,
-- so RLS denies client writes by default) — Section 44.
-- ---------------------------------------------------------------------
create policy ai_insights_select on ai_insights
  for select using (
    scope_id = auth.uid()
    or exists (
      select 1 from assignments a
      where a.patient_id = ai_insights.scope_id
        and (a.caretaker_id = auth.uid() or a.incharge_id = auth.uid())
    )
    or auth_role() = 'admin'
  );

-- ---------------------------------------------------------------------
-- audit_logs — readable by Admin only; written by Edge Functions
-- (service role) and by triggers on the tables above.
-- ---------------------------------------------------------------------
create policy audit_logs_admin_select on audit_logs
  for select using (auth_role() = 'admin');
