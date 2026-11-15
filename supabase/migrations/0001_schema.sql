-- MedGuard — Initial schema (Section 45 of the architecture report)
-- Implements the v2 tables, including the ones added to close the gaps
-- identified in Part II: organizations, patient_invites,
-- doctor_patient_links, escalation_policies, device_tokens, ai_insights.

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------
-- organizations (Section 38) — the multi-tenant boundary
-- ---------------------------------------------------------------------
create table if not exists organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  type text not null check (type in ('school', 'college', 'hostel', 'clinic', 'hospital')),
  address text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------
-- profiles — common identity for every role (Section 5, 45)
-- ---------------------------------------------------------------------
create table if not exists profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  org_id uuid references organizations (id),
  role text not null check (role in ('admin', 'doctor', 'incharge', 'caretaker', 'patient')),
  full_name text not null,
  phone text,
  email text,
  timezone text not null default 'Asia/Kolkata',
  created_at timestamptz not null default now()
);

create table if not exists patients (
  id uuid primary key references profiles (id) on delete cascade,
  age int,
  dob date,
  gender text,
  address text,
  emergency_contact text,
  basic_medical_info text
);

create table if not exists doctors (
  id uuid primary key references profiles (id) on delete cascade,
  specialization text,
  active boolean not null default true
);

create table if not exists incharges (
  id uuid primary key references profiles (id) on delete cascade
);

create table if not exists caretakers (
  id uuid primary key references profiles (id) on delete cascade
);

-- ---------------------------------------------------------------------
-- Doctor <-> Patient linking (Section 39)
-- ---------------------------------------------------------------------
create table if not exists patient_invites (
  id uuid primary key default gen_random_uuid(),
  code text not null unique,
  doctor_id uuid not null references doctors (id) on delete cascade,
  org_id uuid references organizations (id),
  expires_at timestamptz not null,
  used_at timestamptz,
  created_at timestamptz not null default now()
);

create table if not exists doctor_patient_links (
  id uuid primary key default gen_random_uuid(),
  doctor_id uuid not null references doctors (id) on delete cascade,
  patient_id uuid not null references patients (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'unlinked', 'revoked')),
  linked_at timestamptz not null default now(),
  unique (doctor_id, patient_id)
);

-- ---------------------------------------------------------------------
-- Incharge -> Caretaker -> Patient allocation (Section 11, 45)
-- ---------------------------------------------------------------------
create table if not exists assignments (
  id uuid primary key default gen_random_uuid(),
  incharge_id uuid references incharges (id) on delete set null,
  caretaker_id uuid references caretakers (id) on delete set null,
  patient_id uuid not null references patients (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (patient_id)
);

-- ---------------------------------------------------------------------
-- Prescriptions, medicines, schedules, events (Section 9, 13, 14, 24)
-- ---------------------------------------------------------------------
create table if not exists prescriptions (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients (id) on delete cascade,
  doctor_id uuid not null references doctors (id) on delete cascade,
  status text not null default 'active' check (status in ('active', 'discontinued')),
  created_at timestamptz not null default now()
);

create table if not exists medicines (
  id uuid primary key default gen_random_uuid(),
  prescription_id uuid not null references prescriptions (id) on delete cascade,
  name text not null,
  dose text not null,
  frequency_per_day int not null default 1,
  instructions text,
  duration_days int not null default 30,
  start_date date not null default current_date
);

create table if not exists medication_schedules (
  id uuid primary key default gen_random_uuid(),
  medicine_id uuid not null references medicines (id) on delete cascade,
  patient_id uuid not null references patients (id) on delete cascade,
  time_of_day time not null,
  created_at timestamptz not null default now()
);

create table if not exists medication_events (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients (id) on delete cascade,
  medicine_id uuid not null references medicines (id) on delete cascade,
  schedule_id uuid references medication_schedules (id) on delete set null,
  scheduled_at timestamptz not null,
  patient_status text not null default 'pending' check (patient_status in ('pending', 'consumed', 'not_consumed', 'missed')),
  patient_confirmed_at timestamptz,
  server_received_at timestamptz,
  sync_status text not null default 'synced' check (sync_status in ('synced', 'pending_sync')),
  caretaker_status text not null default 'pending' check (caretaker_status in ('pending', 'consumed', 'not_consumed', 'missed')),
  caretaker_confirmed_at timestamptz,
  final_status text not null default 'pending' check (final_status in ('pending', 'consumed', 'not_consumed', 'missed')),
  escalation_level text not null default 'patient' check (escalation_level in ('patient', 'caretaker', 'incharge', 'critical_unresolved')),
  ack_by uuid references profiles (id),
  ack_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists idx_medication_events_escalation_scan
  on medication_events (scheduled_at, final_status);
create index if not exists idx_medication_events_patient
  on medication_events (patient_id, scheduled_at desc);

-- ---------------------------------------------------------------------
-- Escalation policy, contacts, devices, notifications, AI (Section 40-44)
-- ---------------------------------------------------------------------
create table if not exists escalation_policies (
  id uuid primary key default gen_random_uuid(),
  org_id uuid references organizations (id),
  level text not null check (level in ('patient', 'caretaker', 'incharge')),
  window_minutes int not null,
  unique (org_id, level)
);

create table if not exists family_contacts (
  id uuid primary key default gen_random_uuid(),
  patient_id uuid not null references patients (id) on delete cascade,
  name text not null,
  relationship text,
  phone text not null,
  is_emergency boolean not null default false
);

create table if not exists device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles (id) on delete cascade,
  token text not null,
  platform text not null check (platform in ('android', 'ios', 'web')),
  updated_at timestamptz not null default now(),
  unique (user_id, token)
);

create table if not exists notifications (
  id uuid primary key default gen_random_uuid(),
  channel text not null check (channel in ('push', 'sms', 'call', 'in_app')),
  target_user_id uuid references profiles (id),
  event_id uuid references medication_events (id),
  status text not null default 'queued' check (status in ('queued', 'sent', 'failed')),
  sent_at timestamptz
);

create table if not exists ai_insights (
  id uuid primary key default gen_random_uuid(),
  scope_type text not null check (scope_type in ('patient', 'caretaker', 'incharge', 'org')),
  scope_id uuid not null,
  insight_text text not null,
  generated_at timestamptz not null default now()
);

create table if not exists audit_logs (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid references profiles (id),
  action text not null,
  details jsonb,
  created_at timestamptz not null default now()
);

-- Seed sensible default escalation windows (Section 40) — editable per org.
insert into escalation_policies (org_id, level, window_minutes)
values (null, 'patient', 15), (null, 'caretaker', 20), (null, 'incharge', 30)
on conflict (org_id, level) do nothing;
