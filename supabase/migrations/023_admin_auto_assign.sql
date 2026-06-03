-- 023_admin_auto_assign.sql
-- Automatically assign 'admin' role to padillastoresv@gmail.com upon registration

CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  INSERT INTO public.profiles (id, role, email)
  VALUES (
    NEW.id, 
    CASE 
      WHEN NEW.email = 'padillastoresv@gmail.com' THEN 'admin'::public.user_role 
      ELSE 'user'::public.user_role 
    END,
    NEW.email
  );
  RETURN NEW;
END;
$$;
