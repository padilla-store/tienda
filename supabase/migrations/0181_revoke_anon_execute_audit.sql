-- =============================================================================
-- 017_revoke_anon_execute_audit.sql — SECURITY HARDENING
-- =============================================================================
-- Fixes discovered by Supabase DB Advisors during 360° pre-production audit.
--
-- ISSUES FIXED:
--   1. CRIT-DB-01: 10 SECURITY DEFINER functions callable by `anon` role
--      via /rest/v1/rpc/* — revoked EXECUTE on 6 sensitive functions.
--      (is_admin, generate_whatsapp_message, get_category_stats, get_top_favorites
--       are left accessible as they have internal auth checks or return public data)
--
--   2. CRIT-DB-02: system_logs had "Permitir inserciones anonimas en system_logs"
--      policy with WITH CHECK (true) — allowed any unauthenticated user to flood
--      the table. Dropped the policy.
--
--   3. CRIT-DB-03: update_modified_column() had mutable search_path — fixed
--      by setting search_path = public and switching to SECURITY INVOKER.
--
-- Safe to re-run: all statements use IF EXISTS / OR REPLACE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. CRIT-DB-01: Revoke EXECUTE from anon/public on sensitive functions
-- ---------------------------------------------------------------------------
-- These functions must NOT be callable without authentication via the REST API.

-- change_user_role: CRITICAL — privilege escalation vector
REVOKE EXECUTE ON FUNCTION public.change_user_role(uuid, text) FROM anon, public;

-- get_users_list: HIGH — exposes user list with emails
REVOKE EXECUTE ON FUNCTION public.get_users_list() FROM anon, public;

-- get_dashboard_data: HIGH — exposes dashboard statistics
REVOKE EXECUTE ON FUNCTION public.get_dashboard_data(int, int, int) FROM anon, public;

-- handle_new_user: MEDIUM — trigger function exposed as RPC endpoint
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, public;

-- trigger_cleanup_stale_carts: MEDIUM — could delete user carts
REVOKE EXECUTE ON FUNCTION public.trigger_cleanup_stale_carts() FROM anon, public;

-- check_admin_write_rate_limit: trigger function, not meant as RPC
REVOKE EXECUTE ON FUNCTION public.check_admin_write_rate_limit() FROM anon, public;

-- ---------------------------------------------------------------------------
-- 2. CRIT-DB-02: Drop overly permissive anonymous INSERT on system_logs
-- ---------------------------------------------------------------------------
-- The policy "Permitir inserciones anonimas en system_logs" used
-- WITH CHECK (true), allowing ANY unauthenticated request to insert
-- arbitrary data into system_logs — a DoS and data poisoning vector.
DROP POLICY IF EXISTS "Permitir inserciones anonimas en system_logs" ON public.system_logs;

-- ---------------------------------------------------------------------------
-- 3. CRIT-DB-03: Fix mutable search_path on update_modified_column
-- ---------------------------------------------------------------------------
-- The function had no SET search_path, making it vulnerable to
-- search path injection attacks.
CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS $$
BEGIN
  NEW.updated_at = now();
  RETURN NEW;
END;
$$;
