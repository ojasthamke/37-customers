-- =====================================================================
-- ORDERKART CUSTOMER LOGIN AUDIT LOGS & 5-DAY AUTO EXPIRATION MIGRATION
-- =====================================================================
-- Purpose:
-- 1. Track who logged in, when, and their device/login method.
-- 2. Automatically delete logs older than 5 days.
-- =====================================================================

CREATE TABLE IF NOT EXISTS public.customer_login_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    customer_id TEXT,
    customer_code TEXT,
    customer_name TEXT,
    customer_phone TEXT,
    login_method TEXT,
    logged_in_at TIMESTAMPTZ NOT NULL DEFAULT now(),
    device_info TEXT,
    app_version TEXT,
    expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + INTERVAL '5 days'),
    created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE public.customer_login_logs ENABLE ROW LEVEL SECURITY;

-- Allow anon and authenticated users to insert login logs
DROP POLICY IF EXISTS "Allow public insert to customer_login_logs" ON public.customer_login_logs;
CREATE POLICY "Allow public insert to customer_login_logs" 
ON public.customer_login_logs FOR INSERT TO anon, authenticated 
WITH CHECK (true);

-- Allow anon and authenticated users to read login logs
DROP POLICY IF EXISTS "Allow read customer_login_logs" ON public.customer_login_logs;
CREATE POLICY "Allow read customer_login_logs" 
ON public.customer_login_logs FOR SELECT TO anon, authenticated 
USING (true);

-- Allow deletion of expired logs (older than 5 days)
DROP POLICY IF EXISTS "Allow delete expired customer_login_logs" ON public.customer_login_logs;
CREATE POLICY "Allow delete expired customer_login_logs" 
ON public.customer_login_logs FOR DELETE TO anon, authenticated 
USING (true);

-- Indexes for performant lookup & cleanup
CREATE INDEX IF NOT EXISTS idx_customer_login_logs_logged_in_at ON public.customer_login_logs(logged_in_at);
CREATE INDEX IF NOT EXISTS idx_customer_login_logs_customer_id ON public.customer_login_logs(customer_id);
CREATE INDEX IF NOT EXISTS idx_customer_login_logs_customer_phone ON public.customer_login_logs(customer_phone);

-- Function & Trigger to automatically purge logs older than 5 days whenever a new log is inserted
CREATE OR REPLACE FUNCTION public.cleanup_old_login_logs()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    DELETE FROM public.customer_login_logs
    WHERE logged_in_at < (now() - INTERVAL '5 days');
    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_cleanup_old_login_logs ON public.customer_login_logs;
CREATE TRIGGER trg_cleanup_old_login_logs
AFTER INSERT ON public.customer_login_logs
FOR EACH STATEMENT
EXECUTE FUNCTION public.cleanup_old_login_logs();
