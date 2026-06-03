-- 019_split_catalogs_and_categories.sql
-- Separación estática de Catálogos y Categorías dinámicas.

-- 1. Añadir columna catalog a categories con restricción de dominio
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS catalog text;

-- Asegurar que solo acepte 'joyeria' o 'tecnologia'
ALTER TABLE public.categories DROP CONSTRAINT IF EXISTS categories_catalog_check;
ALTER TABLE public.categories ADD CONSTRAINT categories_catalog_check CHECK (catalog IN ('joyeria', 'tecnologia'));

-- 2. Añadir columna catalog a products con la misma restricción
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS catalog text;

ALTER TABLE public.products DROP CONSTRAINT IF EXISTS products_catalog_check;
ALTER TABLE public.products ADD CONSTRAINT products_catalog_check CHECK (catalog IN ('joyeria', 'tecnologia'));

-- 3. Actualizar categorías existentes para asignarles su catálogo estático
-- 'accesorios-celular' pertenece a 'tecnologia'
UPDATE public.categories 
SET catalog = 'tecnologia', name = 'Accesorios de Celular'
WHERE slug = 'accesorios-celular';

-- 'joyeria' pertenece a 'joyeria'
UPDATE public.categories 
SET catalog = 'joyeria', name = 'Joyería Fina'
WHERE slug = 'joyeria';

-- 4. Actualizar productos existentes para asignarles su catálogo correspondiente
-- Si el producto está en la categoría 'accesorios-celular', va a catalog 'tecnologia'
UPDATE public.products 
SET catalog = 'tecnologia'
WHERE category = 'accesorios-celular';

-- Si el producto está en la categoría 'joyeria', va a catalog 'joyeria'
UPDATE public.products 
SET catalog = 'joyeria'
WHERE category = 'joyeria';

-- 5. Crear algunas categorías iniciales dinámicas para diversificar bajo cada catálogo
INSERT INTO public.categories (name, slug, description, icon, featured, catalog) VALUES
('Fundas y Protectores', 'fundas-y-protectores', 'Fundas magnéticas, de silicón y protectores de pantalla.', 'phone_iphone', true, 'tecnologia'),
('Cargadores y Cables', 'cargadores-y-cables', 'Cargadores de pared de carga rápida, cables USB-C y MagSafe.', 'battery_charging_full', true, 'tecnologia'),
('Anillos y Alianzas', 'anillos-y-alianzas', 'Anillos de compromiso, alianzas de plata esterlina y oro.', 'diamond', true, 'joyeria'),
('Cadenas y Collares', 'cadenas-y-collares', 'Cadenas finas y collares con acabados de primera calidad.', 'workspace_premium', true, 'joyeria')
ON CONFLICT (slug) DO UPDATE 
SET catalog = EXCLUDED.catalog, name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon;

-- 6. Añadir category_id a products y mapear los productos de prueba existentes
ALTER TABLE public.products ADD COLUMN IF NOT EXISTS category_id uuid REFERENCES public.categories(id);

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
