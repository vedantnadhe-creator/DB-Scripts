-- ============================================================================
-- Role-Based Assessment Broadcast — Schema Migration
-- Date: 2026-05-25
-- Description: Adds broadcast assessment support for Role-Based assessments.
--   Creates 4 new tables, 2 enums, 1 ALTER on assessment_institute_map.
-- ============================================================================

-- 1. Add is_broadcast column to assessment_institute_map
ALTER TABLE assessment.assessment_institute_map
  ADD COLUMN IF NOT EXISTS is_broadcast boolean NOT NULL DEFAULT false;

-- 2. Create BroadcastStatus enum
DO $$ BEGIN
  CREATE TYPE assessment."BroadcastStatus" AS ENUM ('ACTIVE', 'PAUSED', 'CLOSED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 3. Create BroadcastMembershipSource enum
DO $$ BEGIN
  CREATE TYPE assessment."BroadcastMembershipSource" AS ENUM ('LAZY_ON_FETCH', 'NEW_STUDENT_HOOK', 'ADMIN_MANUAL', 'SCOPE_EXPANDED');
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- 4. Create assessment_broadcast table
CREATE TABLE IF NOT EXISTS assessment.assessment_broadcast (
  broadcast_id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  assessment_institute_map_id uuid NOT NULL UNIQUE
    REFERENCES assessment.assessment_institute_map(assessment_institute_map_id) ON DELETE CASCADE,
  assessment_set_group_id   uuid NOT NULL
    REFERENCES assessment.assessment_set_groups(id),
  institute_id              text NOT NULL,
  institute_campus_id       text NOT NULL,
  status                    assessment."BroadcastStatus" NOT NULL DEFAULT 'ACTIVE',
  next_set_index            integer NOT NULL DEFAULT 0,
  created_by                varchar(255),
  created_at                timestamptz NOT NULL DEFAULT now(),
  updated_at                timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS ix_broadcast_inst_campus
  ON assessment.assessment_broadcast (institute_id, institute_campus_id, status);

-- 5. Create assessment_broadcast_scope table
CREATE TABLE IF NOT EXISTS assessment.assessment_broadcast_scope (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id      uuid NOT NULL
    REFERENCES assessment.assessment_broadcast(broadcast_id) ON DELETE CASCADE,
  target_degree_id  text NOT NULL,
  target_stream_id  text NOT NULL,
  UNIQUE (broadcast_id, target_degree_id, target_stream_id)
);

CREATE INDEX IF NOT EXISTS ix_broadcast_scope_match
  ON assessment.assessment_broadcast_scope (target_degree_id, target_stream_id);

-- 6. Create assessment_broadcast_label_specialisation table
CREATE TABLE IF NOT EXISTS assessment.assessment_broadcast_label_specialisation (
  id                uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id      uuid NOT NULL
    REFERENCES assessment.assessment_broadcast(broadcast_id) ON DELETE CASCADE,
  specialisation_id text NOT NULL,
  UNIQUE (broadcast_id, specialisation_id)
);

-- 7. Create assessment_broadcast_membership table
CREATE TABLE IF NOT EXISTS assessment.assessment_broadcast_membership (
  id                    uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  broadcast_id          uuid NOT NULL
    REFERENCES assessment.assessment_broadcast(broadcast_id) ON DELETE CASCADE,
  primary_email         varchar(255) NOT NULL,
  student_id            text,
  assessment_assigned_id uuid
    REFERENCES assessment.assessment_assigned_students(assessment_assigned_id),
  is_hidden             boolean NOT NULL DEFAULT false,
  hidden_reason         varchar(50),
  source                assessment."BroadcastMembershipSource" NOT NULL,
  materialised_at       timestamptz,
  created_at            timestamptz NOT NULL DEFAULT now(),
  updated_at            timestamptz NOT NULL DEFAULT now(),
  UNIQUE (broadcast_id, primary_email)
);

CREATE INDEX IF NOT EXISTS ix_broadcast_membership_lookup
  ON assessment.assessment_broadcast_membership (primary_email, is_hidden);
