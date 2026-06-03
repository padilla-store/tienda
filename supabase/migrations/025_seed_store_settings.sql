-- 025_seed_store_settings.sql
-- Ensure there is exactly one row in store_settings

INSERT INTO public.store_settings (
  hero_title, 
  hero_subtitle, 
  contact_email, 
  contact_phone,
  bio_name,
  bio_description,
  bio_image_url
)
SELECT 
  'Padilla''s Store', 
  'Tu destino premium para joyería y accesorios de celular en El Salvador.', 
  'padillastoresv@gmail.com', 
  '+50374866909',
  'Padilla Store',
  'Accesorios tecnológicos, bisutería fina de acero y plata en San Miguel. Entrega a domicilio en 24h.',
  '/logo.svg'
WHERE NOT EXISTS (SELECT 1 FROM public.store_settings);
