-- HIGH-003: Rate limiting for admin writes (INSERT/DELETE) on products and categories
-- Prevents an attacker with a stolen admin session from emptying the catalog in seconds

CREATE OR REPLACE FUNCTION public.check_admin_write_rate_limit()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  recent_count integer;
  client_user_id uuid;
  action_name text;
BEGIN
  client_user_id := auth.uid();
  
  IF client_user_id IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Determine action type based on operation and table
  action_name := TG_OP || '_' || TG_TABLE_NAME;

  -- Log the action
  INSERT INTO public.audit_log (action_type, performed_by, details)
  VALUES (action_name, client_user_id, json_build_object('table', TG_TABLE_NAME, 'operation', TG_OP));

  -- Check rate limit: Max 60 write actions (INSERT/DELETE) per hour for a single admin
  -- We allow 60 for bulk uploads/deletions, but it slows down automated bot-like draining.
  SELECT count(*)
  INTO recent_count
  FROM public.audit_log
  WHERE performed_by = client_user_id
    AND action_type IN ('INSERT_products', 'DELETE_products', 'INSERT_categories', 'DELETE_categories')
    AND created_at > now() - interval '1 hour';

  IF recent_count > 60 THEN
    RAISE EXCEPTION 'Rate limit exceeded: You have performed too many write operations. Please wait before creating or deleting more items.';
  END IF;

  RETURN COALESCE(NEW, OLD);
END;
$$;

-- Apply to products
DROP TRIGGER IF EXISTS admin_write_rl_insert_products ON public.products;
CREATE TRIGGER admin_write_rl_insert_products
AFTER INSERT ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.check_admin_write_rate_limit();

DROP TRIGGER IF EXISTS admin_write_rl_delete_products ON public.products;
CREATE TRIGGER admin_write_rl_delete_products
AFTER DELETE ON public.products
FOR EACH ROW
EXECUTE FUNCTION public.check_admin_write_rate_limit();

-- Apply to categories
DROP TRIGGER IF EXISTS admin_write_rl_insert_categories ON public.categories;
CREATE TRIGGER admin_write_rl_insert_categories
AFTER INSERT ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.check_admin_write_rate_limit();

DROP TRIGGER IF EXISTS admin_write_rl_delete_categories ON public.categories;
CREATE TRIGGER admin_write_rl_delete_categories
AFTER DELETE ON public.categories
FOR EACH ROW
EXECUTE FUNCTION public.check_admin_write_rate_limit();
