-- 022_set_admin_role.sql
-- Ensure padillastoresv@gmail.com is admin

INSERT INTO public.profiles (id, email, role)
SELECT id, email, 'admin'::public.user_role
FROM auth.users
WHERE email = 'padillastoresv@gmail.com'
ON CONFLICT (id) DO UPDATE
SET role = 'admin', email = EXCLUDED.email;
