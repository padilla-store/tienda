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
