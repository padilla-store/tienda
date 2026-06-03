-- 017_update_store_data.sql
-- Rebranding a Padilla's Store y adecuación del catálogo a celulares y joyería.

-- 1. Agregar columna featured a la tabla categories si no existe
ALTER TABLE public.categories ADD COLUMN IF NOT EXISTS featured boolean DEFAULT false;

-- 2. Limpiar productos y categorías previas para evitar conflictos de integridad
DELETE FROM public.products;
DELETE FROM public.categories;

-- 3. Insertar nuevas categorías para Padilla's Store
INSERT INTO public.categories (name, slug, description, icon, featured) VALUES
('Accesorios de Celular', 'accesorios-celular', 'Fundas, protectores, cargadores y más para tu smartphone.', 'phone_iphone', true),
('Joyería Fina', 'joyeria', 'Cadenas, anillos, pulseras y accesorios de joyería premium.', 'diamond', true);

-- 4. Insertar productos de prueba premium para Padilla's Store
INSERT INTO public.products (name, slug, description, price, old_price, category, is_active, tags) VALUES
('Funda Aura Case Magnética - iPhone 15 Pro', 'funda-aura-case-iphone-15-pro', 'Funda con tecnología MagSafe, bordes elevados para protección de cámara y diseño minimalista premium.', 14.99, 19.99, 'accesorios-celular', true, ARRAY['Premium', 'Nuevo']),
('Cargador Carga Rápida 20W USB-C', 'cargador-carga-rapida-20w-usb-c', 'Cargador de pared de carga súper rápida, compatible con dispositivos iOS y Android.', 19.99, 24.99, 'accesorios-celular', true, ARRAY['Básico']),
('Anillo de Compromiso Plata Esterlina', 'anillo-compromiso-plata-esterlina', 'Anillo de plata esterlina 925 con circonia cúbica corte brillante de alta calidad.', 89.99, 120.00, 'joyeria', true, ARRAY['Premium', 'Oferta']),
('Cadena de Oro 14K Eslabón Clásico', 'cadena-oro-14k-eslabon-clasico', 'Cadena de oro amarillo de 14 quilates de 50cm con broche de seguridad tipo langosta.', 149.99, 199.99, 'joyeria', true, ARRAY['Premium']);

-- 5. Actualizar la configuración de la tienda (Store Settings)
UPDATE public.store_settings SET
  hero_title = 'Padilla''s Store',
  hero_subtitle = 'Tu destino premium para joyería y accesorios de celular en El Salvador.',
  contact_email = 'padillastoresv@gmail.com',
  contact_phone = '+50374866909',
  updated_at = now();
