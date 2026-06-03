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

ALTER TABLE public.system_logs ADD COLUMN IF NOT EXISTS details jsonb;
ALTER TABLE public.system_logs ADD COLUMN IF NOT EXISTS url text;
ALTER TABLE public.system_logs ADD COLUMN IF NOT EXISTS user_agent text;
ALTER TABLE public.system_logs ADD COLUMN IF NOT EXISTS resolved boolean DEFAULT false;

-- RLS: Solo usuarios autenticados pueden insertar logs.
-- CRIT-003: Cambiado de 'TO public' a 'TO authenticated' para prevenir DoS anónimo
-- vía la anon_key pública expuesta en el bundle del SPA.
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

-- Índice para facilitar la depuración por fecha o por estado de resolución
CREATE INDEX IF NOT EXISTS idx_system_logs_created_at ON public.system_logs(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_system_logs_unresolved ON public.system_logs(resolved) WHERE resolved = false;
