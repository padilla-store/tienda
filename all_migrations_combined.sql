-- 000_base_schema.sql

DO $$ BEGIN
    CREATE TYPE public.user_role AS ENUM ('user', 'admin');
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

CREATE TABLE IF NOT EXISTS public.categories (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    slug text NOT NULL UNIQUE,
    description text,
    icon text,
    image_url text
);

CREATE TABLE IF NOT EXISTS public.products (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text NOT NULL,
    slug text UNIQUE,
    description text,
    price numeric NOT NULL,
    old_price numeric,
    offer_ends_at timestamp with time zone,
    offer_starts_at timestamp with time zone,
    is_active boolean DEFAULT true NOT NULL,
    category text REFERENCES public.categories(slug) ON DELETE SET NULL,
    images text[],
    image_path text,
    tags text[],
    updated_at timestamp with time zone DEFAULT now() NOT NULL
);

CREATE TABLE IF NOT EXISTS public.contact_messages (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    name text,
    email text,
    subject text,
    message text NOT NULL,
    is_read boolean DEFAULT false NOT NULL,
    client_ip text,
    ip_address text,
    user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

CREATE TABLE IF NOT EXISTS public.profiles (
    id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    role public.user_role DEFAULT 'user'::user_role NOT NULL
);

CREATE TABLE IF NOT EXISTS public.store_settings (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    updated_at timestamp with time zone DEFAULT now() NOT NULL,
    hero_title text NOT NULL,
    hero_subtitle text NOT NULL,
    hero_image_url text,
    contact_email text NOT NULL,
    contact_phone text NOT NULL,
    social_facebook text,
    social_instagram text,
    social_tiktok text
);

CREATE TABLE IF NOT EXISTS public.user_carts (
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE PRIMARY KEY,
    updated_at timestamp with time zone DEFAULT now(),
    cart_items jsonb DEFAULT '[]'::jsonb
);

CREATE TABLE IF NOT EXISTS public.user_favorites (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
    product_id uuid REFERENCES public.products(id) ON DELETE CASCADE NOT NULL
);

CREATE TABLE IF NOT EXISTS public.system_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    level text NOT NULL,
    message text NOT NULL,
    metadata jsonb
);

CREATE TABLE IF NOT EXISTS public.audit_log (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  action_type text NOT NULL,
  target_user_id uuid,
  performed_by uuid,
  details jsonb,
  created_at timestamp with time zone DEFAULT now()
);

CREATE OR REPLACE FUNCTION public.update_modified_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ language 'plpgsql';
-- CRIT-004: Add email to profiles to identify users in admin panel

-- 1. Add email column
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS email text;

-- 2. Backfill existing emails (run as superuser/postgres)
UPDATE public.profiles p
SET email = u.email
FROM auth.users u
WHERE p.id = u.id
  AND p.email IS NULL;

-- 3. Update the handle_new_user trigger function to capture email
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
    'user',
    NEW.email
  );
  RETURN NEW;
END;
$$;

-- 4. Create trigger to execute the function on new user registration
DROP TRIGGER IF EXISTS on_auth_user_created ON auth.users;
CREATE TRIGGER on_auth_user_created
  AFTER INSERT ON auth.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();
-- CRIT-006: Add server-side enforcement for file types and sizes in storage policies

DROP POLICY IF EXISTS "Admin upload product images" ON storage.objects;

CREATE POLICY "Admin upload product images"
  ON storage.objects FOR INSERT
  WITH CHECK (
    bucket_id = 'product-images'
    AND auth.role() = 'authenticated'
    AND public.is_admin()
    -- Solo extensiones seguras
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp', 'gif')
    -- Restringir MIME types y lÃ­mite de 5MB
    AND (
      storage.foldername(name) IS NULL -- allow top-level folders?
      OR (
        (metadata->>'mimetype') IN ('image/jpeg', 'image/png', 'image/webp', 'image/gif')
        AND COALESCE((metadata->>'size')::int, 0) <= 5242880
      )
    )
  );

DROP POLICY IF EXISTS "Admin update product images" ON storage.objects;

CREATE POLICY "Admin update product images"
  ON storage.objects FOR UPDATE
  USING (
    bucket_id = 'product-images'
    AND auth.role() = 'authenticated'
    AND public.is_admin()
    AND LOWER(storage.extension(name)) IN ('jpg', 'jpeg', 'png', 'webp', 'gif')
    AND (
      storage.foldername(name) IS NULL
      OR (
        (metadata->>'mimetype') IN ('image/jpeg', 'image/png', 'image/webp', 'image/gif')
        AND COALESCE((metadata->>'size')::int, 0) <= 5242880
      )
    )
  );
-- HIGH-009 + CRIT-001: Parametrizar dominio en RPC + restaurar validaciones de auth y lÃ­mites
-- SEGURIDAD: Esta funciÃ³n DEBE validar autenticaciÃ³n y lÃ­mites de cantidad.
-- La versiÃ³n anterior omitÃ­a estas validaciones, permitiendo invocaciÃ³n anÃ³nima.

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
  -- CRIT-001: Validate authentication â€” prevents anonymous RPC invocation
  IF auth.uid() IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Count items
  SELECT count(*) INTO item_count FROM jsonb_array_elements(items);
  
  IF item_count = 0 THEN
    RETURN '';
  END IF;

  -- CRIT-001: Validate total item count â€” prevents cart abuse
  IF item_count > max_total_items THEN
    RAISE EXCEPTION 'Too many items in cart. The maximum allowed is %.', max_total_items;
  END IF;

  IF item_count = 1 THEN
    order_text := 'Hola, me encantÃ³ este detalle de su tienda y me gustarÃ­a pedirlo:' || E'\n\n';
  ELSE
    order_text := 'Hola, estuve viendo su pÃ¡gina y me gustarÃ­a hacer un pedido con los siguientes artÃ­culos:' || E'\n\n';
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
    -- CRIT-001: Per-item quantity validation â€” prevents abuse via extreme quantities
    IF item.quantity > max_qty_per_item THEN
      RAISE EXCEPTION 'Quantity for item exceeds maximum limit of %', max_qty_per_item;
    END IF;
    IF item.quantity < 1 THEN
      RAISE EXCEPTION 'Quantity for item cannot be less than 1';
    END IF;

    SELECT name, price, old_price, offer_starts_at, offer_ends_at INTO db_product FROM products WHERE id = item.id AND is_active = true;
    IF FOUND THEN
      -- Determine applicable price
      -- MED-WA02: Added offer_starts_at check â€” prevents users from getting offer prices before scheduled start
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
        -- Remove trailing slash if exists in domain
        order_text := order_text || '  Link: ' || rtrim(store_domain, '/') || '/product/' || item.slug || E'\n\n';
      ELSE
        order_text := order_text || E'\n';
      END IF;
    END IF;
  END LOOP;
  
  IF item_count = 1 THEN
     order_text := order_text || 'El total marca *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || 'Â¿Me podrÃ­an ayudar a confirmar el pedido y el envÃ­o por favor?';
  ELSE
     order_text := order_text || 'El total de mi carrito es *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || 'Â¿Me apoyan con el proceso de pago y envÃ­o por favor?';
  END IF;
  
  RETURN order_text;
END;
$$;
-- TAREA-012: Agregar Ã­ndices recomendados para optimizar el rendimiento de la BD (Phase 3)

-- Optimizar bÃºsqueda por slug en categorÃ­as
CREATE INDEX IF NOT EXISTS idx_categories_slug ON public.categories(slug);

-- Optimizar el panel de administraciÃ³n al listar mensajes recientes
CREATE INDEX IF NOT EXISTS idx_contact_messages_created_at ON public.contact_messages(created_at DESC);

-- Optimizar queries en la tienda que filtran por categorÃ­a
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);

-- Optimizar el catÃ¡logo principal donde siempre se filtra is_active = true
CREATE INDEX IF NOT EXISTS idx_products_is_active ON public.products(is_active) WHERE is_active = true;
-- TAREA-011 / MED-001: Error Tracking y Logs del Sistema
-- Fallback para error tracking sin necesidad de dependencias externas en el plan gratuito

CREATE TABLE IF NOT EXISTS public.system_logs (
    id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    level text NOT NULL CHECK (level IN ('info', 'warn', 'error', 'fatal')),
    message text NOT NULL,
    details jsonb,
    url text,
    user_agent text,
    resolved boolean DEFAULT false
);

-- RLS: Solo usuarios autenticados pueden insertar logs.
-- CRIT-003: Cambiado de 'TO public' a 'TO authenticated' para prevenir DoS anÃ³nimo
-- vÃ­a la anon_key pÃºblica expuesta en el bundle del SPA.
ALTER TABLE public.system_logs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Allow insert system logs"
    ON public.system_logs
    FOR INSERT
    TO authenticated
    WITH CHECK (
        length(coalesce(message, '')) < 600 AND
        level IN ('error', 'warn', 'info', 'fatal')
    );

CREATE POLICY "Allow admin to read system logs"
    ON public.system_logs
    FOR SELECT
    TO authenticated
    USING (
        EXISTS (
            SELECT 1 FROM public.profiles
            WHERE profiles.id = auth.uid() AND profiles.role = 'admin'
        )
    );

-- Ãndice para facilitar la depuraciÃ³n por fecha o por estado de resoluciÃ³n
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON public.system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_unresolved ON public.system_logs(resolved) WHERE resolved = false;
-- CRIT-DB01: Consolidated Dashboard RPC â€” hardened against missing dependent functions
-- This function provides all dashboard data in a single network call.
-- Requires admin role. Fixed phantom columns and added safe handling for optional functions.

-- Drop legacy fallback function if it exists
DROP FUNCTION IF EXISTS public.get_dashboard_summary();

CREATE OR REPLACE FUNCTION get_dashboard_data(limit_products int DEFAULT 5, limit_messages int DEFAULT 4, top_favorites_limit int DEFAULT 5)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    result json;
    summary_data record;
    products_data json;
    messages_data json;
    category_data json;
    top_favs_data json;
BEGIN
    -- Only admins can access dashboard data â€” prevents data leak to regular users
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Access denied';
    END IF;

    -- 1. Summary Stats
    SELECT 
        (SELECT COUNT(*) FROM public.products) as total_products,
        (SELECT COUNT(*) FROM public.products
         WHERE old_price IS NOT NULL AND old_price > price
         AND (offer_starts_at IS NULL OR offer_starts_at <= now())
         AND (offer_ends_at IS NULL OR offer_ends_at > now())) as active_offers,
        (SELECT COUNT(*) FROM public.contact_messages WHERE is_read = false) as unread_messages,
        (SELECT COUNT(*) FROM public.user_favorites) as total_favorites,
        (SELECT COUNT(*) FROM public.categories) as total_categories,
        (SELECT COUNT(*) FROM public.profiles) as total_users
    INTO summary_data;

    -- 2. Recent Products (fixed: 'category' -> 'category_id', added is_active column)
    SELECT json_agg(p)
    INTO products_data
    FROM (
        SELECT id, name, price, category_id, image_path, created_at, is_active
        FROM public.products
        ORDER BY created_at DESC
        LIMIT limit_products
    ) p;

    -- 3. Recent Messages
    SELECT json_agg(m)
    INTO messages_data
    FROM (
        SELECT id, name, subject, message, created_at, is_read
        FROM public.contact_messages
        WHERE is_read = false
        ORDER BY created_at DESC
        LIMIT limit_messages
    ) m;

    -- 4. Category Stats â€” safely handle missing function
    BEGIN
        category_data := public.get_category_stats();
    EXCEPTION WHEN undefined_function THEN
        category_data := '[]'::json;
    END;

    -- 5. Top Favorites â€” safely handle missing function
    BEGIN
        top_favs_data := public.get_top_favorites(top_favorites_limit);
    EXCEPTION WHEN undefined_function THEN
        top_favs_data := '[]'::json;
    END;

    -- Assemble JSON response
    result := json_build_object(
        'summary', json_build_object(
            'totalProducts', summary_data.total_products,
            'activeOffers', summary_data.active_offers,
            'unreadMessages', summary_data.unread_messages,
            'totalFavorites', summary_data.total_favorites,
            'totalCategories', summary_data.total_categories,
            'totalUsers', summary_data.total_users
        ),
        'recentProducts', COALESCE(products_data, '[]'::json),
        'recentMessages', COALESCE(messages_data, '[]'::json),
        'categoryData', COALESCE(category_data, '[]'::json),
        'topFavorites', COALESCE(top_favs_data, '[]'::json)
    );

    RETURN result;
END;
$$;
-- TAREA-017 / MED-007: Habilitar Realtime para Settings
-- Asegurar que la tabla store_settings emita eventos en realtime

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 
    FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' 
    AND schemaname = 'public' 
    AND tablename = 'store_settings'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.store_settings;
  END IF;
END
$$;
-- TAREA-020 / MED-010: Fallback para pg_cron
-- Agrega un recolector de basura probabilÃ­stico para limpiar carritos abandonados
-- en caso de que pg_cron falle o no estÃ© habilitado en el plan actual.

CREATE OR REPLACE FUNCTION public.trigger_cleanup_stale_carts()
RETURNS trigger AS $$
BEGIN
  -- 1% de probabilidad de limpiar carritos antiguos en cada modificaciÃ³n.
  -- Esto evita saturar la BD pero asegura limpieza eventual sin cron.
  IF random() < 0.01 THEN
    DELETE FROM public.user_carts 
    WHERE updated_at < now() - interval '7 days';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Recrear el trigger asegurando que use la funciÃ³n
DROP TRIGGER IF EXISTS cleanup_stale_carts_trigger ON public.user_carts;
CREATE TRIGGER cleanup_stale_carts_trigger
  AFTER INSERT OR UPDATE ON public.user_carts
  FOR EACH STATEMENT
  EXECUTE FUNCTION public.trigger_cleanup_stale_carts();
-- DB-003: Crear Ã­ndice Ãºnico en products.slug
CREATE UNIQUE INDEX IF NOT EXISTS idx_products_slug ON public.products(slug);

-- DB-004: Limpiar datos antes de ADD CONSTRAINT en user_carts
UPDATE public.user_carts SET cart_items = '[]'::jsonb
WHERE cart_items IS NULL OR jsonb_typeof(cart_items) != 'array';

DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'valid_cart_items'
  ) THEN
    ALTER TABLE public.user_carts
    ADD CONSTRAINT valid_cart_items CHECK (jsonb_typeof(cart_items) = 'array');
  END IF;
END $$;
-- =============================================================================
-- 014_consolidate_all.sql â€” SINGLE SOURCE OF TRUTH
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
-- 1. CORE FUNCTION: is_admin() â€” SECURITY DEFINER to avoid RLS recursion
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
-- 2. TABLE: products â€” RLS policies
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
-- 3. TABLE: categories â€” RLS policies
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
-- 4. TABLE: store_settings â€” RLS policies
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
-- 5. TABLE: contact_messages â€” RLS policies (CANONICAL definition)
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
-- 6. TABLE: profiles â€” RLS policies (prevents role escalation via RLS)
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
-- 7. TABLE: user_favorites â€” RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_favorites ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own favorites" ON public.user_favorites;
CREATE POLICY "Users can CRUD own favorites" ON public.user_favorites
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 8. TABLE: user_carts â€” RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.user_carts ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can CRUD own carts" ON public.user_carts;
CREATE POLICY "Users can CRUD own carts" ON public.user_carts
FOR ALL TO authenticated
USING (auth.uid() = user_id)
WITH CHECK (auth.uid() = user_id);

-- ---------------------------------------------------------------------------
-- 9. STORAGE: product-images bucket â€” CONSOLIDATED policies
--    CRIT-002 FIX: Combines is_admin() + MIME validation + file size limit (5MB)
--    from 005_harden + 013_strict into ONE canonical set.
-- ---------------------------------------------------------------------------
ALTER TABLE storage.objects ENABLE ROW LEVEL SECURITY;

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
-- 10. FUNCTION: change_user_role â€” CRIT-004: Add admin limit to prevent lateral escalation
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
    RAISE EXCEPTION 'Rol invÃ¡lido';
  END IF;

  -- CRIT-004: Prevent unlimited admin creation
  IF new_role = 'admin' THEN
    SELECT COUNT(*) INTO current_admin_count FROM public.profiles WHERE role = 'admin';
    IF current_admin_count >= max_admins THEN
      RAISE EXCEPTION 'LÃ­mite mÃ¡ximo de administradores alcanzado (%). Contacte al administrador principal.', max_admins;
    END IF;
  END IF;

  UPDATE public.profiles SET role = new_role::user_role WHERE id = target_id;

  -- Audit log
  INSERT INTO public.audit_log (action_type, target_user_id, performed_by, details)
  VALUES ('role_change', target_id, auth.uid(), json_build_object('new_role', new_role));
END;
$$;

-- ---------------------------------------------------------------------------
-- 11. WhatsApp RPC â€” CANONICAL definition (supersedes 006 and supabase_sql_executed)
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
  -- Validate authentication â€” prevents anonymous RPC invocation
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
    order_text := 'Hola, me encantÃ³ este detalle de su tienda y me gustarÃ­a pedirlo:' || E'\n\n';
  ELSE
    order_text := 'Hola, estuve viendo su pÃ¡gina y me gustarÃ­a hacer un pedido con los siguientes artÃ­culos:' || E'\n\n';
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
      -- Determine applicable price (includes offer_starts_at check â€” fixes MED-WA02)
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
     order_text := order_text || 'El total marca *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || 'Â¿Me podrÃ­an ayudar a confirmar el pedido y el envÃ­o por favor?';
  ELSE
     order_text := order_text || 'El total de mi carrito es *$' || trim(to_char(total_price, '999999990.00')) || '*.' || E'\n' || 'Â¿Me apoyan con el proceso de pago y envÃ­o por favor?';
  END IF;

  RETURN order_text;
END;
$$;

-- ---------------------------------------------------------------------------
-- 12. TABLE: audit_log â€” RLS policies
-- ---------------------------------------------------------------------------
ALTER TABLE public.audit_log ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Admins can view audit logs" ON public.audit_log;
CREATE POLICY "Admins can view audit logs" ON public.audit_log
FOR SELECT TO authenticated
USING (public.is_admin());

-- =============================================================================
-- 015_add_bio_settings.sql
-- =============================================================================
-- AÃ±ade los campos necesarios para la configuraciÃ³n dinÃ¡mica de la pÃ¡gina de Links (Bio).
-- Incluye un JSONB para precargar los enlaces por defecto y poder activarlos/desactivarlos.
-- =============================================================================

ALTER TABLE public.store_settings
ADD COLUMN IF NOT EXISTS bio_name text DEFAULT 'Padilla Store',
ADD COLUMN IF NOT EXISTS bio_description text DEFAULT 'Accesorios tecnolÃ³gicos, bisuterÃ­a fina de acero y plata en San Miguel. Entrega a domicilio en 24h.',
ADD COLUMN IF NOT EXISTS bio_image_url text DEFAULT '/logo.svg',
ADD COLUMN IF NOT EXISTS bio_links jsonb DEFAULT '[
  {
    "id": "whatsapp",
    "name": "WhatsApp",
    "url": "https://api.whatsapp.com/send?phone=50374866909",
    "icon": "fa-brands fa-whatsapp",
    "iconColor": "text-[#25d366]",
    "is_active": true
  },
  {
    "id": "website",
    "name": "PÃ¡gina web",
    "url": "https://padillastore.com",
    "icon": "fa-solid fa-globe",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "facebook",
    "name": "PÃ¡gina de Facebook",
    "url": "https://facebook.com/padillastoresv",
    "icon": "fa-brands fa-facebook",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "facebook-admin",
    "name": "Perfil de Facebook",
    "url": "https://web.facebook.com/padillastoresv.admin/",
    "icon": "fa-brands fa-facebook",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "instagram",
    "name": "Instagram",
    "url": "https://instagram.com/padillastoresv",
    "icon": "fa-brands fa-instagram",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "tiktok",
    "name": "TikTok",
    "url": "https://tiktok.com/@padillastoresv",
    "icon": "fa-brands fa-tiktok",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "threads",
    "name": "Threads",
    "url": "https://www.threads.com/@padillastoresv",
    "icon": "fa-brands fa-threads",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "twitter",
    "name": "X (Twitter)",
    "url": "https://x.com/padillastoresv",
    "icon": "fa-brands fa-x-twitter",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "youtube",
    "name": "YouTube",
    "url": "https://www.youtube.com/@padillastoresv",
    "icon": "fa-brands fa-youtube",
    "iconColor": "text-[#ff0000]",
    "is_active": true
  },
  {
    "id": "linkedin",
    "name": "LinkedIn",
    "url": "https://www.linkedin.com/company/padillastoresv",
    "icon": "fa-brands fa-linkedin",
    "iconColor": "text-[#0a66c2]",
    "is_active": true
  },
  {
    "id": "pinterest",
    "name": "Pinterest",
    "url": "https://www.pinterest.com/padillastoresv",
    "icon": "fa-brands fa-pinterest",
    "iconColor": "text-[#bd081c]",
    "is_active": true
  },
  {
    "id": "marketplace",
    "name": "MarketPlace",
    "url": "https://web.facebook.com/marketplace/profile/padillastoresv/",
    "icon": "fa-solid fa-store",
    "iconColor": "",
    "is_active": true
  },
  {
    "id": "location",
    "name": "UbicaciÃ³n",
    "url": "https://maps.app.goo.gl/search/San+Miguel,+El+Salvador",
    "icon": "fa-solid fa-map-location-dot",
    "iconColor": "text-[#ea4335]",
    "is_active": true
  }
]'::jsonb;

-- Trigger an update to fill the default values for the existing row
UPDATE public.store_settings SET bio_name = bio_name;
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
-- =============================================================================
-- 016_add_bio_header_name.sql
-- =============================================================================
-- AÃ±ade un campo separado para el nombre del header de la pÃ¡gina de Links (Bio).
-- =============================================================================

ALTER TABLE public.store_settings
ADD COLUMN IF NOT EXISTS bio_header_name text DEFAULT 'Padilla Store';

-- Inicializar con el valor existente de bio_name para mantener coherencia
UPDATE public.store_settings SET bio_header_name = bio_name WHERE bio_header_name IS NULL;
-- 016_fix_system_logs_schema.sql
-- TAREA-011 / CRIT-001: CorrecciÃ³n de Schema de system_logs
-- Agrega las columnas faltantes para que el logger de frontend y el diseÃ±o original coexistan sin errores de PostgREST.

ALTER TABLE public.system_logs 
ADD COLUMN IF NOT EXISTS details jsonb,
ADD COLUMN IF NOT EXISTS url text,
ADD COLUMN IF NOT EXISTS user_agent text,
ADD COLUMN IF NOT EXISTS resolved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS context text,
ADD COLUMN IF NOT EXISTS source text;

-- Asegura la validaciÃ³n de niveles de error
ALTER TABLE public.system_logs DROP CONSTRAINT IF EXISTS system_logs_level_check;
ALTER TABLE public.system_logs ADD CONSTRAINT system_logs_level_check CHECK (level IN ('info', 'warn', 'error', 'fatal'));
-- =============================================================================
-- 017_revoke_anon_execute_audit.sql â€” SECURITY HARDENING
-- =============================================================================
-- Fixes discovered by Supabase DB Advisors during 360Â° pre-production audit.
--
-- ISSUES FIXED:
--   1. CRIT-DB-01: 10 SECURITY DEFINER functions callable by `anon` role
--      via /rest/v1/rpc/* â€” revoked EXECUTE on 6 sensitive functions.
--      (is_admin, generate_whatsapp_message, get_category_stats, get_top_favorites
--       are left accessible as they have internal auth checks or return public data)
--
--   2. CRIT-DB-02: system_logs had "Permitir inserciones anonimas en system_logs"
--      policy with WITH CHECK (true) â€” allowed any unauthenticated user to flood
--      the table. Dropped the policy.
--
--   3. CRIT-DB-03: update_modified_column() had mutable search_path â€” fixed
--      by setting search_path = public and switching to SECURITY INVOKER.
--
-- Safe to re-run: all statements use IF EXISTS / OR REPLACE.
-- =============================================================================

-- ---------------------------------------------------------------------------
-- 1. CRIT-DB-01: Revoke EXECUTE from anon/public on sensitive functions
-- ---------------------------------------------------------------------------
-- These functions must NOT be callable without authentication via the REST API.

-- change_user_role: CRITICAL â€” privilege escalation vector
REVOKE EXECUTE ON FUNCTION public.change_user_role(uuid, text) FROM anon, public;

-- get_users_list: HIGH â€” exposes user list with emails
REVOKE EXECUTE ON FUNCTION public.get_users_list() FROM anon, public;

-- get_dashboard_data: HIGH â€” exposes dashboard statistics
REVOKE EXECUTE ON FUNCTION public.get_dashboard_data(int, int, int) FROM anon, public;

-- handle_new_user: MEDIUM â€” trigger function exposed as RPC endpoint
REVOKE EXECUTE ON FUNCTION public.handle_new_user() FROM anon, public;

-- trigger_cleanup_stale_carts: MEDIUM â€” could delete user carts
REVOKE EXECUTE ON FUNCTION public.trigger_cleanup_stale_carts() FROM anon, public;

-- check_admin_write_rate_limit: trigger function, not meant as RPC
REVOKE EXECUTE ON FUNCTION public.check_admin_write_rate_limit() FROM anon, public;

-- ---------------------------------------------------------------------------
-- 2. CRIT-DB-02: Drop overly permissive anonymous INSERT on system_logs
-- ---------------------------------------------------------------------------
-- The policy "Permitir inserciones anonimas en system_logs" used
-- WITH CHECK (true), allowing ANY unauthenticated request to insert
-- arbitrary data into system_logs â€” a DoS and data poisoning vector.
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
-- 017_update_store_data.sql
-- Rebranding a Padilla's Store y adecuaciÃ³n del catÃ¡logo a celulares y joyerÃ­a.

-- 1. Agregar columna featured a la tabla categories si no existe
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS featured boolean DEFAULT false;

-- 2. Limpiar productos y categorÃ­as previas para evitar conflictos de integridad
DELETE FROM public.products;
DELETE FROM public.categories;

-- 3. Insertar nuevas categorÃ­as para Padilla's Store
INSERT INTO public.categories (name, slug, description, icon, featured) VALUES
('Accesorios de Celular', 'accesorios-celular', 'Fundas, protectores, cargadores y mÃ¡s para tu smartphone.', 'phone_iphone', true),
('JoyerÃ­a Fina', 'joyeria', 'Cadenas, anillos, pulseras y accesorios de joyerÃ­a premium.', 'diamond', true);

-- 4. Insertar productos de prueba premium para Padilla's Store
INSERT INTO public.products (name, slug, description, price, old_price, category, is_active, tags) VALUES
('Funda Aura Case MagnÃ©tica - iPhone 15 Pro', 'funda-aura-case-iphone-15-pro', 'Funda con tecnologÃ­a MagSafe, bordes elevados para protecciÃ³n de cÃ¡mara y diseÃ±o minimalista premium.', 14.99, 19.99, 'accesorios-celular', true, ARRAY['Premium', 'Nuevo']),
('Cargador Carga RÃ¡pida 20W USB-C', 'cargador-carga-rapida-20w-usb-c', 'Cargador de pared de carga sÃºper rÃ¡pida, compatible con dispositivos iOS y Android.', 19.99, 24.99, 'accesorios-celular', true, ARRAY['BÃ¡sico']),
('Anillo de Compromiso Plata Esterlina', 'anillo-compromiso-plata-esterlina', 'Anillo de plata esterlina 925 con circonia cÃºbica corte brillante de alta calidad.', 89.99, 120.00, 'joyeria', true, ARRAY['Premium', 'Oferta']),
('Cadena de Oro 14K EslabÃ³n ClÃ¡sico', 'cadena-oro-14k-eslabon-clasico', 'Cadena de oro amarillo de 14 quilates de 50cm con broche de seguridad tipo langosta.', 149.99, 199.99, 'joyeria', true, ARRAY['Premium']);

-- 5. Actualizar la configuraciÃ³n de la tienda (Store Settings)
UPDATE public.store_settings SET
  hero_title = 'Padilla''s Store',
  hero_subtitle = 'Tu destino premium para joyerÃ­a y accesorios de celular en El Salvador.',
  contact_email = 'padillastoresv@gmail.com',
  contact_phone = '+50374866909',
  updated_at = now();
-- 018_missing_rpcs.sql
-- Defines missing RPC functions required by the frontend and the consolidated dashboard RPC.

-- 1. get_category_stats()
CREATE OR REPLACE FUNCTION public.get_category_stats()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    res json;
BEGIN
    SELECT json_agg(row_to_json(t))
    INTO res
    FROM (
        SELECT c.name, COUNT(p.id)::int as count
        FROM public.categories c
        LEFT JOIN public.products p ON p.category = c.slug
        GROUP BY c.name
    ) t;
    RETURN COALESCE(res, '[]'::json);
END;
$$;

-- 2. get_top_favorites(limit_num int)
-- Returns both count and fav_count to support both FavoritesPage and TopFavorites widget
CREATE OR REPLACE FUNCTION public.get_top_favorites(limit_num int)
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    res json;
BEGIN
    SELECT json_agg(row_to_json(t))
    INTO res
    FROM (
        SELECT p.id, p.name, p.image_path, p.price, COUNT(uf.id)::int as count, COUNT(uf.id)::int as fav_count
        FROM public.products p
        JOIN public.user_favorites uf ON uf.product_id = p.id
        GROUP BY p.id, p.name, p.image_path, p.price
        ORDER BY count DESC
        LIMIT limit_num
    ) t;
    RETURN COALESCE(res, '[]'::json);
END;
$$;

-- 3. get_users_list()
CREATE OR REPLACE FUNCTION public.get_users_list()
RETURNS json
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
    res json;
BEGIN
    -- Only admins can retrieve user list
    IF NOT public.is_admin() THEN
      RAISE EXCEPTION 'Access denied';
    END IF;

    SELECT json_agg(row_to_json(t))
    INTO res
    FROM (
      SELECT 
        p.id,
        p.email,
        p.role,
        COALESCE(u.raw_user_meta_data->>'full_name', 'Usuario') as full_name
      FROM public.profiles p
      LEFT JOIN auth.users u ON p.id = u.id
      ORDER BY p.created_at DESC
    ) t;
    RETURN COALESCE(res, '[]'::json);
END;
$$;
-- 019_split_catalogs_and_categories.sql
-- SeparaciÃ³n estÃ¡tica de CatÃ¡logos y CategorÃ­as dinÃ¡micas.

-- 1. AÃ±adir columna catalog a categories con restricciÃ³n de dominio
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS catalog text;

-- Asegurar que solo acepte 'joyeria' o 'tecnologia'
ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_catalog_check;
ALTER TABLE public.categories ADD CONSTRAINT categories_catalog_check CHECK (catalog IN ('joyeria', 'tecnologia'));

-- 2. AÃ±adir columna catalog a products con la misma restricciÃ³n
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS catalog text;

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_catalog_check;
ALTER TABLE public.products ADD CONSTRAINT products_catalog_check CHECK (catalog IN ('joyeria', 'tecnologia'));

-- 3. Actualizar categorÃ­as existentes para asignarles su catÃ¡logo estÃ¡tico
-- 'accesorios-celular' pertenece a 'tecnologia'
UPDATE public.categories 
SET catalog = 'tecnologia', name = 'Accesorios de Celular'
WHERE slug = 'accesorios-celular';

-- 'joyeria' pertenece a 'joyeria'
UPDATE public.categories 
SET catalog = 'joyeria', name = 'JoyerÃ­a Fina'
WHERE slug = 'joyeria';

-- 4. Actualizar productos existentes para asignarles su catÃ¡logo correspondiente
-- Si el producto estÃ¡ en la categorÃ­a 'accesorios-celular', va a catalog 'tecnologia'
UPDATE public.products 
SET catalog = 'tecnologia'
WHERE category = 'accesorios-celular';

-- Si el producto estÃ¡ en la categorÃ­a 'joyeria', va a catalog 'joyeria'
UPDATE public.products 
SET catalog = 'joyeria'
WHERE category = 'joyeria';

-- 5. Crear algunas categorÃ­as iniciales dinÃ¡micas para diversificar bajo cada catÃ¡logo
INSERT INTO public.categories (name, slug, description, icon, featured, catalog) VALUES
('Fundas y Protectores', 'fundas-y-protectores', 'Fundas magnÃ©ticas, de silicÃ³n y protectores de pantalla.', 'phone_iphone', true, 'tecnologia'),
('Cargadores y Cables', 'cargadores-y-cables', 'Cargadores de pared de carga rÃ¡pida, cables USB-C y MagSafe.', 'battery_charging_full', true, 'tecnologia'),
('Anillos y Alianzas', 'anillos-y-alianzas', 'Anillos de compromiso, alianzas de plata esterlina y oro.', 'diamond', true, 'joyeria'),
('Cadenas y Collares', 'cadenas-y-collares', 'Cadenas finas y collares con acabados de primera calidad.', 'workspace_premium', true, 'joyeria')
ON CONFLICT (slug) DO UPDATE 
SET catalog = EXCLUDED.catalog, name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon;

-- 6. Mapear los productos de prueba existentes a las nuevas categorÃ­as mÃ¡s especÃ­ficas
UPDATE public.products 
SET category = 'fundas-y-protectores', category_id = (SELECT id FROM public.categories WHERE slug = 'fundas-y-protectores')
WHERE slug = 'funda-aura-case-iphone-15-pro';

UPDATE public.products 
SET category = 'cargadores-y-cables', category_id = (SELECT id FROM public.categories WHERE slug = 'cargadores-y-cables')
WHERE slug = 'cargador-carga-rapida-20w-usb-c';

UPDATE public.products 
SET category = 'anillos-y-alianzas', category_id = (SELECT id FROM public.categories WHERE slug = 'anillos-y-alianzas')
WHERE slug = 'anillo-compromiso-plata-esterlina';

UPDATE public.products 
SET category = 'cadenas-y-collares', category_id = (SELECT id FROM public.categories WHERE slug = 'cadenas-y-collares')
WHERE slug = 'cadena-oro-14k-eslabon-clasico';
-- 020_add_story_image_to_settings.sql
-- Agrega la columna story_image_url a store_settings para la
-- secciÃ³n "Tu regalo, tu historia" de la pÃ¡gina de inicio.
-- El formulario de administraciÃ³n ya tenÃ­a el campo de carga de imagen
-- pero la columna no estaba definida en el esquema.

ALTER TABLE public.store_settings
  ADD COLUMN IF NOT EXISTS story_image_url text;
-- 021_missing_fk_indexes.sql
-- Phase 2 DB Audit: Agregando Ã­ndices para claves forÃ¡neas

CREATE INDEX IF NOT EXISTS idx_products_category_id ON public.products(category_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_user_id ON public.user_favorites(user_id);
CREATE INDEX IF NOT EXISTS idx_user_favorites_product_id ON public.user_favorites(product_id);
-- 022_set_admin_role.sql
-- Ensure padillastoresv@gmail.com is admin

INSERT INTO public.profiles (id, email, role)
SELECT id, email, 'admin'::public.user_role
FROM auth.users
WHERE email = 'padillastoresv@gmail.com'
ON CONFLICT (id) DO UPDATE
SET role = 'admin', email = EXCLUDED.email;
