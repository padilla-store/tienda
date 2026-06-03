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
