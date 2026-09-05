-- =====================================================================
-- SERVER-AUTHORITATIVE AUTH RATE LIMIT & LOGIN LOCKOUT MIGRATION
-- =====================================================================
CREATE TABLE IF NOT EXISTS public.auth_rate_limits (
  identifier text PRIMARY KEY,
  failed_attempts integer DEFAULT 0,
  hourly_lockout_count integer DEFAULT 0,
  locked_until timestamp with time zone,
  lockout_type text DEFAULT '',
  updated_at timestamp with time zone DEFAULT now()
);

ALTER TABLE public.auth_rate_limits ENABLE ROW LEVEL SECURITY;

-- 1. Check Lockout Status
CREATE OR REPLACE FUNCTION public.check_auth_lockout(p_identifier TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_norm_id TEXT;
  v_row RECORD;
  v_remaining_secs INT;
BEGIN
  v_norm_id := UPPER(TRIM(p_identifier));
  IF v_norm_id = '' THEN 
    RETURN jsonb_build_object('is_locked', false, 'remaining_attempts', 10); 
  END IF;

  SELECT * INTO v_row FROM public.auth_rate_limits WHERE identifier = v_norm_id;
  
  IF FOUND AND v_row.locked_until IS NOT NULL AND clock_timestamp() < v_row.locked_until THEN
    v_remaining_secs := EXTRACT(EPOCH FROM (v_row.locked_until - clock_timestamp()))::INT;
    RETURN jsonb_build_object(
      'is_locked', true,
      'locked_until', to_char(v_row.locked_until, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
      'remaining_seconds', v_remaining_secs,
      'lockout_type', COALESCE(v_row.lockout_type, '1hr'),
      'failed_attempts', v_row.failed_attempts,
      'message', CASE 
        WHEN v_row.lockout_type = '3days' THEN 'Account locked for 3 days due to 8 repeated lockouts.'
        ELSE 'Account locked for 1 hour due to 10 failed login attempts.'
      END
    );
  END IF;

  RETURN jsonb_build_object(
    'is_locked', false,
    'remaining_attempts', GREATEST(0, 10 - COALESCE(v_row.failed_attempts, 0)),
    'failed_attempts', COALESCE(v_row.failed_attempts, 0)
  );
END;
$$;

-- 2. Record Failure and Trigger Lockout
CREATE OR REPLACE FUNCTION public.record_auth_failure(p_identifier TEXT)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_norm_id TEXT;
  v_row RECORD;
  v_failed INT;
  v_hourly INT;
  v_locked_until TIMESTAMPTZ := NULL;
  v_lockout_type TEXT := '';
  v_remaining_secs INT := 0;
BEGIN
  v_norm_id := UPPER(TRIM(p_identifier));
  IF v_norm_id = '' THEN 
    RETURN jsonb_build_object('is_locked', false, 'remaining_attempts', 10); 
  END IF;

  SELECT * INTO v_row FROM public.auth_rate_limits WHERE identifier = v_norm_id FOR UPDATE;

  IF FOUND THEN
    IF v_row.locked_until IS NOT NULL AND clock_timestamp() < v_row.locked_until THEN
      v_remaining_secs := EXTRACT(EPOCH FROM (v_row.locked_until - clock_timestamp()))::INT;
      RETURN jsonb_build_object(
        'is_locked', true,
        'locked_until', to_char(v_row.locked_until, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'remaining_seconds', v_remaining_secs,
        'lockout_type', v_row.lockout_type,
        'message', 'Account is currently locked. Try again later.'
      );
    END IF;

    v_failed := COALESCE(v_row.failed_attempts, 0) + 1;
    v_hourly := COALESCE(v_row.hourly_lockout_count, 0);

    IF v_failed >= 10 THEN
      v_hourly := v_hourly + 1;
      IF v_hourly >= 8 THEN
        v_locked_until := clock_timestamp() + INTERVAL '3 days';
        v_lockout_type := '3days';
        v_hourly := 0;
      ELSE
        v_locked_until := clock_timestamp() + INTERVAL '1 hour';
        v_lockout_type := '1hr';
      END IF;
      v_failed := 0;
      
      UPDATE public.auth_rate_limits
      SET failed_attempts = v_failed,
          hourly_lockout_count = v_hourly,
          locked_until = v_locked_until,
          lockout_type = v_lockout_type,
          updated_at = clock_timestamp()
      WHERE identifier = v_norm_id;

      v_remaining_secs := EXTRACT(EPOCH FROM (v_locked_until - clock_timestamp()))::INT;
      RETURN jsonb_build_object(
        'is_locked', true,
        'locked_until', to_char(v_locked_until, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'remaining_seconds', v_remaining_secs,
        'lockout_type', v_lockout_type,
        'message', CASE WHEN v_lockout_type = '3days' 
          THEN 'Account locked for 3 days due to 8 repeated 1-hour lockouts.' 
          ELSE 'Account locked for 1 hour due to 10 failed login attempts.' END
      );
    ELSE
      UPDATE public.auth_rate_limits
      SET failed_attempts = v_failed,
          locked_until = NULL,
          lockout_type = '',
          updated_at = clock_timestamp()
      WHERE identifier = v_norm_id;

      RETURN jsonb_build_object(
        'is_locked', false,
        'remaining_attempts', 10 - v_failed,
        'failed_attempts', v_failed,
        'message', format('Invalid credentials. %s attempts remaining before 1-hour lockout.', 10 - v_failed)
      );
    END IF;
  ELSE
    INSERT INTO public.auth_rate_limits (identifier, failed_attempts, hourly_lockout_count, locked_until, lockout_type, updated_at)
    VALUES (v_norm_id, 1, 0, NULL, '', clock_timestamp());

    RETURN jsonb_build_object(
      'is_locked', false,
      'remaining_attempts', 9,
      'failed_attempts', 1,
      'message', 'Invalid credentials. 9 attempts remaining before 1-hour lockout.'
    );
  END IF;
END;
$$;

-- 3. Record Successful Login
CREATE OR REPLACE FUNCTION public.record_auth_success(p_identifier TEXT)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_norm_id TEXT;
BEGIN
  v_norm_id := UPPER(TRIM(p_identifier));
  IF v_norm_id <> '' THEN
    UPDATE public.auth_rate_limits
    SET failed_attempts = 0,
        locked_until = NULL,
        lockout_type = '',
        updated_at = clock_timestamp()
    WHERE identifier = v_norm_id;
  END IF;
  RETURN true;
END;
$$;

-- 4. Grant Permissions
GRANT EXECUTE ON FUNCTION public.check_auth_lockout(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.record_auth_failure(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.record_auth_success(TEXT) TO authenticated, anon;
