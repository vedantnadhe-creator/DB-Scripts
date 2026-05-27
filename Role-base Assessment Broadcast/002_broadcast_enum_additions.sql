-- ============================================================================
-- Role-Based Assessment Broadcast — Enum Additions
-- Date: 2026-05-27
-- Description: Adds enum values that were added to the DB after the initial
--   schema migration but were not captured in the script repo.
-- ============================================================================

-- 1. Add ASSIGNED to BroadcastStatus enum
-- Used when a broadcast transitions from pool-ready to student-assigned state
ALTER TYPE assessment."BroadcastStatus" ADD VALUE IF NOT EXISTS 'ASSIGNED';

-- 2. Add ACTIVATION_BATCH to BroadcastMembershipSource enum
-- Used when memberships are created via bulk student activation
ALTER TYPE assessment."BroadcastMembershipSource" ADD VALUE IF NOT EXISTS 'ACTIVATION_BATCH';
