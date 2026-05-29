-- =============================================================================
-- Migration 003 — Per-scope label specialisations
-- =============================================================================
-- Purpose:
--   Adds target_degree_id and target_stream_id columns to
--   assessment.assessment_broadcast_label_specialisation so a label can be
--   associated with a SPECIFIC scope of a broadcast instead of being
--   broadcast-wide.
--
-- Why this was needed:
--   institute.specialisation_master uses a single master ID per spec name
--   across streams (e.g. "MARKETING" in Finance and "MARKETING" in HR share
--   the same specialisation_id). Without the target_* columns, there was no
--   way to express "MARKETING applies only to the Finance scope" on a
--   multi-scope broadcast — the admin UI couldn't tell which scope owned
--   each label and showed labels on every scope chip whose stream offered
--   the same master spec.
--
-- Backward compatibility:
--   Both new columns are NULLABLE. Existing rows keep target_* = NULL and
--   continue to be treated as broadcast-wide labels by the eligibility
--   query (see student-node Assessment.js scope_label_specialisations
--   subquery: "OR target_degree_id IS NULL AND target_stream_id IS NULL").
--
-- Index:
--   Drops the old UNIQUE(broadcast_id, specialisation_id) constraint/index
--   (named ..._broadcast_id_spec_key or ..._broadcast_id_specialisation_i_key
--   depending on which environment) and adds a new partial-unique index that
--   includes the target columns via COALESCE so NULL targets are equal to
--   empty string for uniqueness purposes.
--
-- Environments applied:
--   DEV  — applied 2026-05-28
--   UAT  — applied 2026-05-28
--   PROD — pending
--
-- Code changes that depend on this migration:
--   admin-node      — BroadcastService.createBroadcast, updateLabels accept
--                     per-scope label payload [{ targetDegreeId, targetStreamId,
--                     specialisationIds }] and write target_* columns.
--   student-node    — Assessment.js getBroadcastEligibleAssessments adds a
--                     scope_label_specialisations array filtered by the
--                     student's actual current_course (degree_id, stream_id),
--                     used for matchesSpec computation.
--   admin-react     — InlineBroadcastScopePicker (create) and ScopeEditModal
--                     (edit) send per-scope payloads.
--   Prisma schema   — AssessmentBroadcastLabelSpecialisation gains
--                     targetDegreeId String? @map("target_degree_id") and
--                     targetStreamId String? @map("target_stream_id").
-- =============================================================================

-- 1. Add the two new nullable columns. Safe to re-run.
ALTER TABLE assessment.assessment_broadcast_label_specialisation
  ADD COLUMN IF NOT EXISTS target_degree_id text,
  ADD COLUMN IF NOT EXISTS target_stream_id text;

-- 2. Drop the old uniqueness on (broadcast_id, specialisation_id).
--    Try both names — DEV and UAT had slightly different auto-generated
--    constraint names because Prisma originally truncated at 63 chars.
ALTER TABLE assessment.assessment_broadcast_label_specialisation
  DROP CONSTRAINT IF EXISTS assessment_broadcast_label_sp_broadcast_id_specialisation_i_key;

ALTER TABLE assessment.assessment_broadcast_label_specialisation
  DROP CONSTRAINT IF EXISTS assessment_broadcast_label_specialisation_broadcast_id_spec_key;

-- On some environments the same name survives as a unique INDEX (not a
-- CONSTRAINT) after Prisma migrations were re-applied. Drop the index too.
DROP INDEX IF EXISTS assessment.assessment_broadcast_label_specialisation_broadcast_id_spec_key;
DROP INDEX IF EXISTS assessment.assessment_broadcast_label_sp_broadcast_id_specialisation_i_key;

-- 3. New partial-unique index that includes target columns. COALESCE NULLs to
--    empty string so two NULL-target rows for the same (broadcast, spec) are
--    still considered duplicates.
CREATE UNIQUE INDEX IF NOT EXISTS uniq_broadcast_label_scope
  ON assessment.assessment_broadcast_label_specialisation(
    broadcast_id,
    specialisation_id,
    COALESCE(target_degree_id, ''),
    COALESCE(target_stream_id, '')
  );

-- =============================================================================
-- ROLLBACK (manual, only if absolutely needed)
-- =============================================================================
--   DROP INDEX IF EXISTS assessment.uniq_broadcast_label_scope;
--
--   -- Optional: re-add the broadcast-wide unique. WARNING: this fails if there
--   -- are now rows whose (broadcast_id, specialisation_id) repeat across
--   -- different target_* scopes. De-duplicate first.
--   ALTER TABLE assessment.assessment_broadcast_label_specialisation
--     ADD CONSTRAINT assessment_broadcast_label_specialisation_broadcast_id_spec_key
--     UNIQUE (broadcast_id, specialisation_id);
--
--   ALTER TABLE assessment.assessment_broadcast_label_specialisation
--     DROP COLUMN IF EXISTS target_degree_id,
--     DROP COLUMN IF EXISTS target_stream_id;
-- =============================================================================
