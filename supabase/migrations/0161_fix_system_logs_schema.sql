-- 016_fix_system_logs_schema.sql
-- TAREA-011 / CRIT-001: Corrección de Schema de system_logs
-- Agrega las columnas faltantes para que el logger de frontend y el diseño original coexistan sin errores de PostgREST.

ALTER TABLE public.system_logs 
ADD COLUMN IF NOT EXISTS details jsonb,
ADD COLUMN IF NOT EXISTS url text,
ADD COLUMN IF NOT EXISTS user_agent text,
ADD COLUMN IF NOT EXISTS resolved boolean DEFAULT false,
ADD COLUMN IF NOT EXISTS context text,
ADD COLUMN IF NOT EXISTS source text;

-- Asegura la validación de niveles de error
ALTER TABLE public.system_logs DROP CONSTRAINT IF EXISTS system_logs_level_check;
ALTER TABLE public.system_logs ADD CONSTRAINT system_logs_level_check CHECK (level IN ('info', 'warn', 'error', 'fatal'));
