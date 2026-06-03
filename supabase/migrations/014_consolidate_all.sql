-- =============================================================================
-- 014_consolidate_all.sql — SINGLE SOURCE OF TRUTH
-- =============================================================================
-- This migration consolidates and supersedes all previous duplicate definitions.
-- It resolves CRIT-001 (duplicate RLS policies) and CRIT-002 (storage policy shadow).
--
-- SUPERSEDES:
--   - supabase_sql_executed.sql (contact_messages INSERT policy, is_admin, change_user_role)
--   - rls_audit_fix.sql (all RLS policies)
--   - 013_strict_rls_policies.sql (strict RLS + storage)
--   - 005_harden_storage_policies.sql (storage MIME/size validation)
--   - supabase_storage_policies.sql (basic storage policies)
--
-- Safe to re-run: all statements use DROP IF EXISTS before CREATE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. CORE FUNCTION: is_admin() — SECURITY DEFINER to avoid RLS recursion
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 FROM public.profiles
    WHERE id = auth.uid() AND role = 'admin'
  );
END;
$$;

-- ---------------------------------------------------------------------------
-- 2. TABLE: products — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view active products" ON public.products;
CREATE POLICY "Public can view active products" ON public.products
FOR SELECT TO public
USING (is_active = true OR public.is_admin());

DROP POLICY IF EXISTS "Admins can insert products" ON public.products;
CREATE POLICY "Admins can insert products" ON public.products
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update products" ON public.products;
CREATE POLICY "Admins can update products" ON public.products
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete products" ON public.products;
CREATE POLICY "Admins can delete products" ON public.products
FOR DELETE TO authenticated
USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- 3. TABLE: categories — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.categories ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view all categories" ON public.categories;
CREATE POLICY "Public can view all categories" ON public.categories
FOR SELECT TO public
USING (true);

DROP POLICY IF EXISTS "Admins can insert categories" ON public.categories;
CREATE POLICY "Admins can insert categories" ON public.categories
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update categories" ON public.categories;
CREATE POLICY "Admins can update categories" ON public.categories
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete categories" ON public.categories;
CREATE POLICY "Admins can delete categories" ON public.categories
FOR DELETE TO authenticated
USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- 4. TABLE: store_settings — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.store_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view store settings" ON public.store_settings;
CREATE POLICY "Public can view store settings" ON public.store_settings
FOR SELECT TO public
USING (true);

DROP POLICY IF EXISTS "Admins can insert store settings" ON public.store_settings;
CREATE POLICY "Admins can insert store settings" ON public.store_settings
FOR INSERT TO authenticated
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can update store settings" ON public.store_settings;
CREATE POLICY "Admins can update store settings" ON public.store_settings
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete store settings" ON public.store_settings;
CREATE POLICY "Admins can delete store settings" ON public.store_settings
FOR DELETE TO authenticated
USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- 5. TABLE: contact_messages — RLS policies (CANONICAL definition)
--    CRIT-001 FIX: This is the ONE definition. Requires auth + validates user_id + field lengths.
-- ---------------------------------------------------------------------------
ALTER TABLE public.contact_messages ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Anyone can insert contact_messages" ON public.contact_messages;
DROP POLICY IF EXISTS "Authenticated users can insert contact_messages" ON public.contact_messages;
CREATE POLICY "Authenticated users can insert contact_messages"
ON public.contact_messages FOR INSERT
TO authenticated
WITH CHECK (
  auth.uid() IS NOT NULL AND
  (user_id IS NULL OR user_id = auth.uid()) AND
  length(trim(coalesce(message, ''))) > 0 AND
  length(trim(coalesce(message, ''))) < 5000 AND
  length(trim(coalesce(name, ''))) < 200 AND
  length(trim(coalesce(subject, ''))) < 200 AND
  length(trim(coalesce(email, ''))) < 200
);

DROP POLICY IF EXISTS "Admins can view contact messages" ON public.contact_messages;
CREATE POLICY "Admins can view contact messages" ON public.contact_messages
FOR SELECT TO authenticated
USING (public.is_admin());

DROP POLICY IF EXISTS "Admins can update contact messages" ON public.contact_messages;
CREATE POLICY "Admins can update contact messages" ON public.contact_messages
FOR UPDATE TO authenticated
USING (public.is_admin())
WITH CHECK (public.is_admin());

DROP POLICY IF EXISTS "Admins can delete contact messages" ON public.contact_messages;
CREATE POLICY "Admins can delete contact messages" ON public.contact_messages
FOR DELETE TO authenticated
USING (public.is_admin());

-- ---------------------------------------------------------------------------
-- 6. TABLE: profiles — RLS policies (prevents role escalation via RLS)
-- ---------------------------------------------------------------------------
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Public can view profiles" ON public.profiles;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.profiles;
DROP POLICY IF EXISTS "Users can view own profile or admin" ON public.profiles;
CREATE POLICY "Users can view own profile or admin" ON public.profiles
FOR SELECT TO authenticated
USING (auth.uid() = id OR public.is_admin());

DROP POLICY IF EXISTS "Users can update own profile" ON public.profiles;
DROP POLICY IF EXISTS "Prevent role update via RLS" ON public.profiles;
DROP POLICY IF EXISTS "Users can update own profile (no role change)" ON public.profiles;
CREATE POLICY "Users can update own profile (no role change)" ON public.profiles
FOR UPDATE TO authenticated
USING (auth.uid() = id)
WITH CHECK (
  auth.uid() = id AND
  role = (SELECT role FROM public.profiles WHERE id = auth.uid())
);

-- ---------------------------------------------------------------------------
-- 7. TABLE: user_favorites — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own favorites" ON public.user_favorites;
CREATE POLICY "Users can CRUD own favorites" ON public.user_favorites
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 8. TABLE: user_carts — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_carts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own carts" ON public.user_carts;
CREATE POLICY "Users can CRUD own carts" ON public.user_carts
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 9. STORAGE: product-images bucket — CONSOLIDATED policies
--    CRIT-002 FIX: Combines is_admin() + MIME validation + file size limit (5MB)
--    from 005_harden + 013_strict into ONE canonical set.
-- ---------------------------------------------------------------------------
-- ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

-- Public read
DROP POLICY IF EXISTS "Public access to product images" ON storage.objects;
CREATE POLICY "Public access to product images"
ON storage.objects FOR SELECT
USING (bucket_id = 'product-images');

-- Admin INSERT with MIME + size + extension validation
DROP POLICY IF EXISTS "Admin upload product images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can insert product-images" ON storage.objects;
CREATE POLICY "Admin upload product images"
ON storage.objects FOR INSERT
TO authenticated
WITH CHECK (
  bucket_id = 'product-images'
  AND public.is_admin()
  -- CRIT-002: Enforce safe file extensions at policy level
  AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp', 'gif')
  -- CRIT-002: Enforce MIME type and max file size (5MB)
  AND (metadata->>'mimetype') IN ('image/jpeg', 'image/png', 'image/webp', 'image/gif')
  AND COALESCE((metadata->>'size')::int, 0) <= 5242880
);

-- Admin UPDATE with same validations
DROP POLICY IF EXISTS "Admin update product images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can update product-images" ON storage.objects;
CREATE POLICY "Admin update product images"
ON storage.objects FOR UPDATE
TO authenticated
USING (
  bucket_id = 'product-images'
  AND public.is_admin()
  AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp', 'gif')
  AND (metadata->>'mimetype') IN ('image/jpeg', 'image/png', 'image/webp', 'image/gif')
  AND COALESCE((metadata->>'size')::int, 0) <= 5242880
);

-- Admin DELETE (no MIME check needed on delete)
DROP POLICY IF EXISTS "Admin delete product images" ON storage.objects;
DROP POLICY IF EXISTS "Admins can delete product-images" ON storage.objects;
CREATE POLICY "Admin delete product images"
ON storage.objects FOR DELETE
TO authenticated
USING (bucket_id = 'product-images' AND public.is_admin());

-- ---------------------------------------------------------------------------
-- 10. FUNCTION: change_user_role — CRIT-004: Add admin limit to prevent lateral escalation
-- ---------------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.change_user_role(uuid, user_role);

CREATE OR REPLACE FUNCTION public.change_user_role(target_id uuid, new_role text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  caller_role user_role;
  first_admin_id uuid;
  current_admin_count int;
  max_admins int := 3; -- CRIT-004: Configurable admin limit
BEGIN
  -- Only admins can change roles
  SELECT role INTO caller_role FROM public.profiles WHERE id = auth.uid();
  IF caller_role != 'admin' THEN
    RAISE EXCEPTION 'Solo los administradores pueden cambiar roles';
  END IF;

  -- Protect the first admin from being degraded by others
  SELECT id INTO first_admin_id FROM public.profiles WHERE role = 'admin' ORDER BY created_at ASC LIMIT 1;
  IF target_id = first_admin_id AND auth.uid() != first_admin_id AND new_role != 'admin' THEN
    RAISE EXCEPTION 'No se puede cambiar el rol del administrador principal';
  END IF;

  -- Validation
  IF new_role NOT IN ('admin', 'user') THEN
    RAISE EXCEPTION 'Rol inválido';
  END IF;

  -- CRIT-004: Prevent unlimited admin creation
  IF new_role = 'admin' THEN
    SELECT COUNT(*) INTO current_admin_count FROM public.profiles WHERE role = 'admin';
    IF current_admin_count >= max_admins THEN
      RAISE EXCEPTION 'Límite máximo de administradores alcanzado (%). Contacte al administrador principal.', max_admins;
    END IF;
  END IF;

  UPDATE public.profiles SET role = new_role::user_role WHERE id = target_id;

  -- Audit log
  INSERT INTO public.audit_log (action_type, target_user_id, performed_by, details)
  VALUES ('role_change', target_id, auth.uid(), json_build_object('new_role', new_role));
END;
$$;

-- ---------------------------------------------------------------------------
-- 11. WhatsApp RPC — CANONICAL definition (supersedes 006 and supabase_sql_executed)
--     Includes offer_starts_at check that was missing in the original.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.generate_whatsapp_message(items jsonb, store_domain text DEFAULT 'https://padillastore.com')
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  order_text text;
  total_price numeric := 0;
  item record;
  db_product record;
  product_price numeric;
  item_count int := 0;
  max_qty_per_item int := 50;
  max_total_items int := 50;
BEGIN
  -- Validate authentication — prevents anonymous RPC invocation
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Count items
  SELECT count(*) INTO item_count FROM jsonb_array_elements(items);

  IF item_count = 0 THEN
    RETURN '';
  END IF;

  -- Validate total item count
  IF item_count > max_total_items THEN
    RAISE EXCEPTION 'Too many items in cart. The maximum allowed is %.', max_total_items;
  END IF;

  IF item_count = 1 THEN
    order_text := 'Hola, me encantó este detalle de su tienda y me gustaría pedirlo:' || E'\n\n';
  ELSE
    order_text := 'Hola, estuve viendo su página y me gustaría hacer un pedido con los siguientes artículos:' || E'\n\n';
  END IF;

  FOR item IN SELECT * FROM jsonb_to_recordset(
    (SELECT jsonb_agg(
      jsonb_build_object(
        'id', (i->'product'->>'id')::uuid,
        'quantity', (i->>'quantity')::int,
        'color', coalesce(i->'color'->>'name', i->>'color', ''),
        'note', coalesce(i->>'note', ''),
        'slug', coalesce(i->'product'->>'slug', '')
      )
    ) FROM jsonb_array_elements(items) i)
  ) AS x(id uuid, quantity int, color text, note text, slug text)
  LOOP
    -- Per-item quantity validation
    IF item.quantity > max_qty_per_item THEN
      RAISE EXCEPTION 'Quantity for item exceeds maximum limit of %', max_qty_per_item;
    END IF;
    IF item.quantity < 1 THEN
      RAISE EXCEPTION 'Quantity for item cannot be less than 1';
    END IF;

    SELECT name, price, old_price, offer_starts_at, offer_ends_at INTO db_product FROM products WHERE id = item.id AND is_active = true;
    IF FOUND THEN
      -- Determine applicable price (includes offer_starts_at check — fixes MED-WA02)
      product_price := db_product.price;
      IF db_product.old_price IS NOT NULL AND db_product.old_price > db_product.price
         AND (db_product.offer_starts_at IS NULL OR db_product.offer_starts_at <= now())
         AND (db_product.offer_ends_at IS NULL OR db_product.offer_ends_at > now()) THEN
         product_price := db_product.price;
      END IF;

      IF item_count = 1 THEN
         IF item.quantity > 1 THEN
           order_text := order_text || '- ' || item.quantity || ' unidades de *' || db_product.name || '* (';
         ELSE
           order_text := order_text || '- *' || db_product.name || '* (';
         END IF;
      ELSE
         order_text := order_text || '- ' || item.quantity || 'x *' || db_product.name || '* (';
      END IF;

      IF product_price IS NULL OR product_price = 0 THEN
        order_text := order_text || 'Precio a consultar)' || E'\n';
      ELSE
        order_text := order_text || '$' || trim(to_char(product_price, '999999990.00')) || ')' || E'\n';
        total_price := total_price + (product_price * item.quantity);
      END IF;

      IF item.color IS NOT NULL AND item.color != '' THEN
        -- Strip whatsapp formatting chars (*, _, ~, `) and limit to 50 chars
        order_text := order_text || '  Color: ' || substring(regexp_replace(item.color, '[*_~`]', '', 'g') from 1 for 50) || E'\n';
      END IF;

      IF item.note IS NOT NULL AND item.note != '' THEN
        -- Strip whatsapp formatting chars and limit to 200 chars
        order_text := order_text || '  Nota: "' || substring(regexp_replace(item.note, '[*_~`]', '', 'g') from 1 for 200) || '"' || E'\n';
      END IF;

      IF item.slug IS NOT NULL AND item.slug != '' THEN
        order_text := order_text || '  Link: ' || rtrim(store_domain, '/') || '/product/' || item.slug || E'\n\n';
      ELSE
        order_text := order_text || E'\n';
      END IF;
    END IF;
  END LOOP;

  IF item_count = 1 THEN
     order_text := order_text || 'El total marca *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || '¿Me podrían ayudar a confirmar el pedido y el envío por favor?';
  ELSE
     order_text := order_text || 'El total de mi carrito es *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || '¿Me apoyan con el proceso de pago y envío por favor?';
  END IF;

  RETURN order_text;
END;
$$;

-- ---------------------------------------------------------------------------
-- 12. TABLE: audit_log — RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_log;
CREATE POLICY "Admins can view audit logs" ON public.audit_log
FOR SELECT TO authenticated
USING (public.is_admin());

