-- 024_contact_messages_rate_limit.sql
-- SEC-001: Implement database-level rate limiting for contact_messages
-- Prevents abuse by limiting users to 5 messages per hour.

CREATE OR REPLACE FUNCTION public.check_contact_messages_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recent_count integer;
BEGIN
  -- We only rate limit based on user_id if they are authenticated.
  -- If anon users were allowed, we would need IP-based limits (which Supabase handles via API gateway or Edge Functions).
  -- Since contact_messages is restricted to authenticated users (via RLS), we rate limit by auth.uid().
  
  IF auth.uid() IS NOT NULL THEN
    SELECT count(*)
    INTO recent_count
    FROM public.contact_messages
    WHERE user_id = auth.uid()
      AND created_at > now() - interval '1 hour';
      
    IF recent_count >= 5 THEN
      RAISE EXCEPTION 'Rate limit exceeded: Maximum 5 messages per hour allowed.';
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS enforce_contact_messages_rl ON public.contact_messages;
CREATE TRIGGER enforce_contact_messages_rl
  BEFORE INSERT ON public.contact_messages
  FOR EACH ROW
  EXECUTE FUNCTION public.check_contact_messages_rate_limit();
