-- =====================================================================
-- APLIBHAJI & ORDERKART CUSTOMER AUTH & SCHEDULING SQL UPDATE
-- =====================================================================
-- Purpose: 
-- 1. Add guest user & password fields to customers and orders tables.
-- 2. Add RPC for first-time password setup by customer code (setup_customer_password).
-- 3. Add RPC for customer password reset by phone (reset_customer_password).
-- 4. Enable secure RPC execution permissions.
-- =====================================================================

-- 1. ADD COLUMNS TO CUSTOMERS TABLE
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS is_guest BOOLEAN DEFAULT FALSE;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS password TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS customer_code TEXT;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS cutoff_time TEXT DEFAULT '23:59';
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS delivery_schedule JSONB;

-- 2. ADD COLUMNS TO ORDERS TABLE FOR PRE-ORDERS & ORDER TAKING DATE
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_type TEXT DEFAULT 'Normal';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_taking_date DATE;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS offline_order_no TEXT;

-- Index for fast customer_code lookups
CREATE INDEX IF NOT EXISTS idx_customers_customer_code ON public.customers(UPPER(customer_code));
CREATE INDEX IF NOT EXISTS idx_orders_order_taking_date ON public.orders(order_taking_date);


-- =====================================================================
-- 3. RPC: SETUP CUSTOMER PASSWORD FOR NEW CODE-BASED USERS
-- =====================================================================
DROP FUNCTION IF EXISTS public.setup_customer_password(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.setup_customer_password CASCADE;

CREATE OR REPLACE FUNCTION public.setup_customer_password(
  p_code TEXT,
  p_name TEXT,
  p_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_customer RECORD;
  v_customer_id UUID;
  v_phone TEXT;
  v_email TEXT;
  v_existing_password TEXT;
  v_auth_user_id UUID;
  v_digits TEXT;
  v_last10 TEXT;
  v_formatted_password TEXT;
  v_canonical_code TEXT;
BEGIN
  p_code := TRIM(p_code);
  
  -- Extract digits if identifier is a phone number
  v_digits := regexp_replace(p_code, '\D', '', 'g');
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
  ELSE
    v_last10 := '';
  END IF;
  
  -- Find customer by customer_code or phone
  SELECT id, name, phone, password, auth_user_id, customer_code 
  INTO v_customer
  FROM public.customers
  WHERE UPPER(TRIM(customer_code)) = UPPER(p_code)
     OR phone = p_code
     OR (v_digits <> '' AND regexp_replace(phone, '\D', '', 'g') = v_digits)
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer.id IS NULL THEN
    RAISE EXCEPTION 'Invalid Customer Code: %', p_code;
  END IF;

  v_customer_id := v_customer.id;
  v_existing_password := v_customer.password;
  v_canonical_code := UPPER(TRIM(COALESCE(v_customer.customer_code, '')));

  -- 🛑 Only block if the customer already has an actual password set
  IF (v_existing_password IS NOT NULL AND TRIM(v_existing_password) <> '') THEN
    RAISE EXCEPTION 'Password already created. Please use your existing password to log in or use Reset Password.';
  END IF;

  -- Canonical synthetic email MUST use customer_code if available, otherwise phone digits
  IF v_canonical_code <> '' THEN
    v_email := LOWER(v_canonical_code) || '@aplibhaji.com';
  ELSE
    v_email := LOWER(regexp_replace(v_customer.phone, '\D', '', 'g')) || '@aplibhaji.com';
  END IF;

  -- Format password if needed (minimum 6 chars formatted for Supabase auth)
  IF LENGTH(TRIM(p_password)) < 6 THEN
    v_formatted_password := 'OK_' || TRIM(p_password) || '_2026';
  ELSE
    v_formatted_password := TRIM(p_password);
  END IF;

  -- Find or create auth.users entry
  SELECT id INTO v_auth_user_id FROM auth.users 
  WHERE id = v_customer_id OR email = v_email OR (v_customer.auth_user_id IS NOT NULL AND id = v_customer.auth_user_id)
  LIMIT 1;

  IF v_auth_user_id IS NULL THEN
    v_auth_user_id := v_customer_id;
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', v_customer_id, 'authenticated', 'authenticated',
      v_email, extensions.crypt(v_formatted_password, extensions.gen_salt('bf')),
      now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'name', COALESCE(NULLIF(TRIM(p_name), ''), v_customer.name),
        'phone', v_customer.phone,
        'customer_code', v_canonical_code
      ),
      now(), now(), '', '', '', ''
    );
  ELSE
    UPDATE auth.users SET
      email = v_email,
      encrypted_password = extensions.crypt(v_formatted_password, extensions.gen_salt('bf')),
      updated_at = now()
    WHERE id = v_auth_user_id;
  END IF;

  -- Update public.customers details & password
  UPDATE public.customers
  SET 
    name = COALESCE(NULLIF(TRIM(p_name), ''), name),
    password = p_password,
    is_guest = FALSE,
    auth_user_id = v_auth_user_id,
    customer_code = CASE WHEN customer_code IS NULL OR TRIM(customer_code) = '' THEN v_canonical_code ELSE customer_code END
  WHERE id = v_customer_id;

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', v_customer_id,
    'customer_code', v_canonical_code,
    'email', v_email
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.setup_customer_password(TEXT, TEXT, TEXT) TO authenticated, anon;

-- =====================================================================
-- 4. RPC: CHECK CUSTOMER AUTH STATUS (Determine if password already exists)
-- =====================================================================
DROP FUNCTION IF EXISTS public.check_customer_auth_status(TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.check_customer_auth_status CASCADE;

CREATE OR REPLACE FUNCTION public.check_customer_auth_status(
  p_identifier TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_customer RECORD;
  v_has_password BOOLEAN := FALSE;
  v_digits TEXT;
  v_last10 TEXT;
BEGIN
  p_identifier := TRIM(p_identifier);
  IF p_identifier = '' THEN
    RETURN jsonb_build_object(
      'exists', false,
      'has_password', false,
      'message', 'Please enter a valid Customer Code or Mobile Number.'
    );
  END IF;
  
  -- Extract digits if identifier is a phone number
  v_digits := regexp_replace(p_identifier, '\D', '', 'g');
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
  ELSE
    v_last10 := '';
  END IF;
  
  SELECT id, name, phone, customer_code, auth_user_id, password
  INTO v_customer
  FROM public.customers
  WHERE UPPER(TRIM(customer_code)) = UPPER(p_identifier)
     OR phone = p_identifier
     OR (v_digits <> '' AND regexp_replace(phone, '\D', '', 'g') = v_digits)
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer.id IS NULL THEN
    RETURN jsonb_build_object(
      'exists', false,
      'has_password', false,
      'message', 'Customer account not found. Please check your Customer Code or Mobile Number.'
    );
  END IF;

  -- A customer has a password ONLY if they have an actual password set in public.customers
  IF (v_customer.password IS NOT NULL AND TRIM(v_customer.password) <> '') THEN
    v_has_password := TRUE;
  END IF;

  RETURN jsonb_build_object(
    'exists', true,
    'has_password', v_has_password,
    'customer_id', v_customer.id,
    'customer_code', v_customer.customer_code,
    'name', v_customer.name,
    'phone', v_customer.phone,
    'phone_masked', CASE 
      WHEN LENGTH(v_customer.phone) >= 4 THEN
        SUBSTRING(v_customer.phone FROM 1 FOR 2) || '******' || SUBSTRING(v_customer.phone FROM LENGTH(v_customer.phone) - 1 FOR 2)
      ELSE v_customer.phone
    END
  );
END;
$$;

GRANT EXECUTE ON FUNCTION public.check_customer_auth_status(TEXT) TO authenticated, anon;


-- =====================================================================
-- 5. RPC: RESET CUSTOMER PASSWORD (WITH PHONE VERIFICATION)
-- =====================================================================
DROP FUNCTION IF EXISTS public.reset_customer_password(TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.reset_customer_password(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.reset_customer_password CASCADE;

CREATE OR REPLACE FUNCTION public.reset_customer_password(
  p_identifier TEXT,
  p_phone_confirm TEXT,
  p_new_password TEXT
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_customer_id UUID;
  v_phone TEXT;
  v_code TEXT;
  v_email1 TEXT;
  v_email2 TEXT;
  v_auth_user_id UUID;
  v_formatted_password TEXT;
  v_digits TEXT;
  v_last10 TEXT;
  v_conf_digits TEXT;
  v_conf_last4 TEXT;
BEGIN
  p_identifier := TRIM(p_identifier);
  p_phone_confirm := TRIM(p_phone_confirm);
  
  -- Extract digits for flexible matching
  v_digits := regexp_replace(p_identifier, '\D', '', 'g');
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
  ELSE
    v_last10 := '';
  END IF;
  
  -- Format password if needed
  IF LENGTH(TRIM(p_new_password)) < 6 THEN
    v_formatted_password := 'OK_' || TRIM(p_new_password) || '_2026';
  ELSE
    v_formatted_password := TRIM(p_new_password);
  END IF;

  -- Lookup customer by code or phone
  SELECT id, phone, customer_code, auth_user_id
  INTO v_customer_id, v_phone, v_code, v_auth_user_id
  FROM public.customers
  WHERE UPPER(customer_code) = UPPER(p_identifier)
     OR phone = p_identifier
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer_id IS NULL THEN
    RETURN jsonb_build_object('success', false, 'error', 'Customer account not found.');
  END IF;

  -- Verify identity: phone confirmation must match the customer's registered phone
  IF p_phone_confirm IS NULL OR TRIM(p_phone_confirm) = '' THEN
    RETURN jsonb_build_object('success', false, 'error', 'Registered mobile number confirmation is required to reset password.');
  END IF;

  v_conf_digits := regexp_replace(p_phone_confirm, '\D', '', 'g');
  IF LENGTH(v_conf_digits) >= 4 THEN
    v_conf_last4 := RIGHT(v_conf_digits, 4);
  ELSE
    v_conf_last4 := v_conf_digits;
  END IF;
  
  IF RIGHT(regexp_replace(v_phone, '\D', '', 'g'), 4) <> v_conf_last4 AND v_phone <> p_phone_confirm THEN
    RETURN jsonb_build_object('success', false, 'error', 'Mobile number does not match registered account details.');
  END IF;

  v_email1 := LOWER(COALESCE(v_code, '')) || '@aplibhaji.com';
  v_email2 := regexp_replace(v_phone, '\D', '', 'g') || '@aplibhaji.com';

  IF v_auth_user_id IS NULL THEN
    SELECT id INTO v_auth_user_id FROM auth.users WHERE email IN (v_email1, v_email2) LIMIT 1;
  END IF;

  -- Update auth.users password by auth_user_id or email
  IF v_auth_user_id IS NOT NULL THEN
    UPDATE auth.users
    SET encrypted_password = crypt(v_formatted_password, gen_salt('bf'))
    WHERE id = v_auth_user_id;
  END IF;

  UPDATE auth.users
  SET encrypted_password = crypt(v_formatted_password, gen_salt('bf'))
  WHERE email IN (v_email1, v_email2);

  -- Update public.customers password
  UPDATE public.customers
  SET password = p_new_password,
      auth_user_id = v_auth_user_id
  WHERE id = v_customer_id;

  RETURN jsonb_build_object(
    'success', true,
    'message', 'Password updated successfully',
    'customer_code', v_code
  );
END;
$$;


-- =====================================================================
-- 5. RPC: UPDATE CUSTOMER PROFILE
-- =====================================================================
DROP FUNCTION IF EXISTS public.update_customer_profile(TEXT, TEXT, TEXT, UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.update_customer_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.update_customer_profile CASCADE;

DROP FUNCTION IF EXISTS public.update_customer_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.update_customer_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.update_customer_profile CASCADE;

CREATE OR REPLACE FUNCTION public.update_customer_profile(
  p_name text DEFAULT NULL::text,
  p_phone text DEFAULT NULL::text,
  p_address text DEFAULT NULL::text,
  p_area_id text DEFAULT NULL::text,
  p_road_id text DEFAULT NULL::text,
  p_sub_road_id text DEFAULT NULL::text,
  p_id text DEFAULT NULL::text
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_caller_id UUID := auth.uid();
  v_target_id UUID;
  v_area_name text;
  v_road_name text;
  v_sub_road_name text;
  v_valid_area_id text;
  v_valid_road_id text;
  v_valid_sub_road_id text;
  v_is_admin boolean := public.is_admin();
BEGIN
  IF v_caller_id IS NULL AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  -- Determine target customer UUID
  IF p_id IS NOT NULL AND trim(p_id) <> '' THEN
    BEGIN
      v_target_id := p_id::uuid;
    EXCEPTION WHEN OTHERS THEN
      v_target_id := NULL;
    END;
  END IF;

  IF v_target_id IS NULL THEN
    v_target_id := v_caller_id;
  END IF;

  -- Only admin or the customer themselves can update
  IF v_target_id <> v_caller_id AND NOT v_is_admin THEN
    RAISE EXCEPTION 'Unauthorized: You can only update your own profile.';
  END IF;

  -- Validate area_id against public.areas by id or name
  IF p_area_id IS NOT NULL AND trim(p_area_id) <> '' THEN
    SELECT id, name INTO v_valid_area_id, v_area_name 
    FROM public.areas 
    WHERE id = trim(p_area_id) OR lower(trim(name)) = lower(trim(p_area_id)) 
    LIMIT 1;
  END IF;

  -- Validate road_id against public.roads by id or name
  IF p_road_id IS NOT NULL AND trim(p_road_id) <> '' THEN
    SELECT id, name INTO v_valid_road_id, v_road_name 
    FROM public.roads 
    WHERE id = trim(p_road_id) OR lower(trim(name)) = lower(trim(p_road_id)) 
    LIMIT 1;
  END IF;

  -- Validate sub_road_id against public.sub_roads by id or name
  IF p_sub_road_id IS NOT NULL AND trim(p_sub_road_id) <> '' THEN
    SELECT id, name INTO v_valid_sub_road_id, v_sub_road_name 
    FROM public.sub_roads 
    WHERE id = trim(p_sub_road_id) OR lower(trim(name)) = lower(trim(p_sub_road_id)) 
    LIMIT 1;
  END IF;

  UPDATE public.customers
  SET 
    name = COALESCE(NULLIF(TRIM(p_name), ''), name),
    phone = COALESCE(NULLIF(TRIM(p_phone), ''), phone),
    address = COALESCE(NULLIF(TRIM(p_address), ''), address),
    area_id = CASE WHEN p_area_id IS NOT NULL THEN v_valid_area_id ELSE area_id END,
    road_id = CASE WHEN p_road_id IS NOT NULL THEN v_valid_road_id ELSE road_id END,
    sub_road_id = CASE WHEN p_sub_road_id IS NOT NULL THEN v_valid_sub_road_id ELSE sub_road_id END,
    area_name = COALESCE(v_area_name, area_name),
    road_name = COALESCE(v_road_name, road_name),
    sub_road_name = COALESCE(v_sub_road_name, sub_road_name),
    updated_at = timezone('utc'::text, now())
  WHERE id = v_target_id OR auth_user_id = v_target_id;

  -- Also update auth user metadata if present
  UPDATE auth.users
  SET raw_user_meta_data = coalesce(raw_user_meta_data, '{}'::jsonb) || jsonb_build_object(
    'name', COALESCE(NULLIF(TRIM(p_name), ''), raw_user_meta_data->>'name'),
    'phone', COALESCE(NULLIF(TRIM(p_phone), ''), raw_user_meta_data->>'phone'),
    'address', COALESCE(NULLIF(TRIM(p_address), ''), raw_user_meta_data->>'address'),
    'area_id', v_valid_area_id,
    'road_id', v_valid_road_id,
    'sub_road_id', v_valid_sub_road_id
  ),
  updated_at = now()
  WHERE id = v_target_id;

  RETURN TRUE;
END;
$function$;

-- =====================================================================
-- 6. RPC: REGISTER GUEST CUSTOMER (SEPARATE ROW IN CUSTOMERS TABLE)
-- =====================================================================
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT, UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer CASCADE;

CREATE OR REPLACE FUNCTION public.register_guest_customer(
  p_name text,
  p_phone text,
  p_address text,
  p_area_id text DEFAULT NULL::text,
  p_road_id text DEFAULT NULL::text,
  p_sub_road_id text DEFAULT NULL::text
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_customer_id UUID;
  v_digits TEXT;
  v_last10 TEXT;
  v_clean_phone TEXT;
  v_email TEXT;
  v_customer_row RECORD;
  v_valid_area_id text;
  v_valid_road_id text;
  v_valid_sub_road_id text;
  v_is_guest BOOLEAN;
  v_existing_auth_id UUID;
  v_existing_password TEXT;
BEGIN
  -- Clean inputs
  p_name := TRIM(p_name);
  p_phone := TRIM(p_phone);
  p_address := TRIM(p_address);
  v_digits := regexp_replace(p_phone, '\D', '', 'g');
  
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
    v_clean_phone := v_last10;
  ELSE
    v_last10 := '';
    v_clean_phone := v_digits;
  END IF;

  v_email := v_clean_phone || '@aplibhaji.com';

  -- Validate area_id, road_id, sub_road_id against actual tables
  IF p_area_id IS NOT NULL AND trim(p_area_id) <> '' THEN
    SELECT id INTO v_valid_area_id FROM public.areas WHERE id = trim(p_area_id) OR lower(trim(name)) = lower(trim(p_area_id)) LIMIT 1;
  END IF;
  IF p_road_id IS NOT NULL AND trim(p_road_id) <> '' THEN
    SELECT id INTO v_valid_road_id FROM public.roads WHERE id = trim(p_road_id) OR lower(trim(name)) = lower(trim(p_road_id)) LIMIT 1;
  END IF;
  IF p_sub_road_id IS NOT NULL AND trim(p_sub_road_id) <> '' THEN
    SELECT id INTO v_valid_sub_road_id FROM public.sub_roads WHERE id = trim(p_sub_road_id) OR lower(trim(name)) = lower(trim(p_sub_road_id)) LIMIT 1;
  END IF;

  -- Check if guest or customer exists by phone
  SELECT id, is_guest, auth_user_id, password
  INTO v_customer_id, v_is_guest, v_existing_auth_id, v_existing_password
  FROM public.customers
  WHERE phone = p_phone
     OR phone = v_clean_phone
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  -- Security check: Prevent overwriting a registered customer account
  IF v_customer_id IS NOT NULL AND (v_is_guest IS FALSE OR v_existing_auth_id IS NOT NULL OR (v_existing_password IS NOT NULL AND TRIM(v_existing_password) <> '')) THEN
    RAISE EXCEPTION 'An account with this phone number already exists. Please log in with your password.';
  END IF;

  IF v_customer_id IS NOT NULL THEN
    -- Update existing guest record
    UPDATE public.customers
    SET name = COALESCE(NULLIF(p_name, ''), name),
        address = COALESCE(NULLIF(p_address, ''), address),
        phone = p_phone,
        is_guest = TRUE,
        area_id = COALESCE(v_valid_area_id, area_id),
        road_id = COALESCE(v_valid_road_id, road_id),
        sub_road_id = COALESCE(v_valid_sub_road_id, sub_road_id),
        updated_at = timezone('utc'::text, now())
    WHERE id = v_customer_id;
  ELSE
    -- Create new guest record with is_guest = TRUE
    v_customer_id := gen_random_uuid();
    INSERT INTO public.customers (
      id, name, phone, email, address, is_guest,
      area_id, road_id, sub_road_id, updated_at
    ) VALUES (
      v_customer_id, p_name, p_phone, v_email, p_address, TRUE,
      v_valid_area_id, v_valid_road_id, v_valid_sub_road_id, timezone('utc'::text, now())
    );
  END IF;

  -- Select customer record
  SELECT c.*, 
         a.name AS area_name, a.delivery_schedule, a.cutoff_time,
         r.name AS road_name,
         sr.name AS sub_road_name
  INTO v_customer_row
  FROM public.customers c
  LEFT JOIN public.areas a ON c.area_id = a.id
  LEFT JOIN public.roads r ON c.road_id = r.id
  LEFT JOIN public.sub_roads sr ON c.sub_road_id = sr.id
  WHERE c.id = v_customer_id;

  RETURN jsonb_build_object(
    'id', v_customer_row.id,
    'name', v_customer_row.name,
    'phone', v_customer_row.phone,
    'address', v_customer_row.address,
    'is_guest', TRUE,
    'customer_code', v_customer_row.customer_code,
    'area_id', v_customer_row.area_id,
    'area_name', v_customer_row.area_name,
    'road_id', v_customer_row.road_id,
    'road_name', v_customer_row.road_name,
    'sub_road_id', v_customer_row.sub_road_id,
    'sub_road_name', v_customer_row.sub_road_name,
    'delivery_schedule', v_customer_row.delivery_schedule,
    'cutoff_time', v_customer_row.cutoff_time
  );
END;
$$;

-- =====================================================================
-- 7. RPC: SYNC CUSTOMER WITH CODE (ADMIN ONLY)
-- =====================================================================
DROP FUNCTION IF EXISTS public.sync_customer_with_code(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.sync_customer_with_code(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.sync_customer_with_code CASCADE;

CREATE OR REPLACE FUNCTION public.sync_customer_with_code(
  p_id uuid,
  p_name text,
  p_phone text,
  p_email text,
  p_address text,
  p_customer_code text,
  p_area_id text DEFAULT NULL::text,
  p_road_id text DEFAULT NULL::text,
  p_sub_road_id text DEFAULT NULL::text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $function$
DECLARE
  v_email text;
  v_user_id uuid;
  v_customer_code text;
  v_random_password text;
  v_area_name text;
  v_road_name text;
  v_sub_road_name text;
  v_valid_area_id text;
  v_valid_road_id text;
  v_valid_sub_road_id text;
  v_resolved_address text;
  v_existing_password text;
BEGIN
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Only administrators can synchronize customer codes.';
  END IF;

  v_customer_code := upper(trim(p_customer_code));
  IF v_customer_code = '' THEN v_customer_code := null; END IF;

  IF v_customer_code IS NOT NULL THEN
    IF EXISTS (SELECT 1 FROM public.customers WHERE upper(trim(customer_code)) = v_customer_code AND id != p_id) THEN
      RAISE EXCEPTION 'Customer code % already assigned to another customer.', v_customer_code;
    END IF;
    v_email := lower(v_customer_code) || '@aplibhaji.com';
  ELSE
    v_email := lower(p_id::text) || '@placeholder.aplibhaji.com';
  END IF;

  -- Validate area_id against public.areas by id or name
  IF p_area_id IS NOT NULL AND trim(p_area_id) <> '' THEN
    SELECT id, name INTO v_valid_area_id, v_area_name 
    FROM public.areas 
    WHERE id = trim(p_area_id) OR lower(trim(name)) = lower(trim(p_area_id)) 
    LIMIT 1;
  END IF;

  -- Validate road_id against public.roads by id or name
  IF p_road_id IS NOT NULL AND trim(p_road_id) <> '' THEN
    SELECT id, name INTO v_valid_road_id, v_road_name 
    FROM public.roads 
    WHERE id = trim(p_road_id) OR lower(trim(name)) = lower(trim(p_road_id)) 
    LIMIT 1;
  END IF;

  -- Validate sub_road_id against public.sub_roads by id or name
  IF p_sub_road_id IS NOT NULL AND trim(p_sub_road_id) <> '' THEN
    SELECT id, name INTO v_valid_sub_road_id, v_sub_road_name 
    FROM public.sub_roads 
    WHERE id = trim(p_sub_road_id) OR lower(trim(name)) = lower(trim(p_sub_road_id)) 
    LIMIT 1;
  END IF;

  -- Compose resolved delivery address if empty
  v_resolved_address := trim(coalesce(p_address, ''));
  IF v_resolved_address = '' THEN
    v_resolved_address := concat_ws(', ', nullif(trim(v_road_name), ''), nullif(trim(v_area_name), ''));
  END IF;

  -- Check existing customer password to preserve it on update!
  SELECT password INTO v_existing_password FROM public.customers WHERE id = p_id;

  -- Ensure auth.users has an entry with id = p_id
  SELECT id INTO v_user_id FROM auth.users WHERE id = p_id;

  IF v_user_id IS NULL THEN
    -- Free up any colliding email on another user
    DELETE FROM auth.users WHERE email = v_email AND id != p_id;

    v_random_password := encode(gen_random_bytes(32), 'hex');
    INSERT INTO auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change
    ) VALUES (
      '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
      v_email, extensions.crypt(v_random_password, extensions.gen_salt('bf')),
      now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'name', p_name,
        'phone', p_phone,
        'address', v_resolved_address,
        'area_id', v_valid_area_id,
        'road_id', v_valid_road_id,
        'sub_road_id', v_valid_sub_road_id,
        'customer_code', v_customer_code
      ),
      now(), now(), '', '', '', ''
    );
    v_user_id := p_id;
  ELSE
    -- Free up colliding email on another user
    DELETE FROM auth.users WHERE email = v_email AND id != p_id;

    UPDATE auth.users SET
      email = v_email,
      raw_user_meta_data = jsonb_build_object(
        'name', p_name,
        'phone', p_phone,
        'address', v_resolved_address,
        'area_id', v_valid_area_id,
        'road_id', v_valid_road_id,
        'sub_road_id', v_valid_sub_road_id,
        'customer_code', v_customer_code
      ),
      updated_at = now()
    WHERE id = p_id;
  END IF;

  -- Upsert customer record, preserving existing password!
  INSERT INTO public.customers (
    id, auth_user_id, name, phone, email, address, customer_code,
    area_id, road_id, sub_road_id, area_name, road_name, sub_road_name, updated_at
  )
  VALUES (
    p_id, v_user_id, p_name, nullif(trim(p_phone), ''), v_email, v_resolved_address, v_customer_code,
    v_valid_area_id, v_valid_road_id, v_valid_sub_road_id, v_area_name, v_road_name, v_sub_road_name, timezone('utc'::text, now())
  )
  ON CONFLICT (id) DO UPDATE SET
    auth_user_id = excluded.auth_user_id,
    name = excluded.name,
    phone = excluded.phone,
    email = excluded.email,
    address = CASE WHEN excluded.address <> '' THEN excluded.address ELSE public.customers.address END,
    customer_code = excluded.customer_code,
    area_id = coalesce(excluded.area_id, public.customers.area_id),
    road_id = coalesce(excluded.road_id, public.customers.road_id),
    sub_road_id = coalesce(excluded.sub_road_id, public.customers.sub_road_id),
    area_name = coalesce(excluded.area_name, public.customers.area_name),
    road_name = coalesce(excluded.road_name, public.customers.road_name),
    sub_road_name = coalesce(excluded.sub_road_name, public.customers.sub_road_name),
    password = coalesce(public.customers.password, v_existing_password),
    updated_at = timezone('utc'::text, now());
END;
$function$;

-- =====================================================================
-- 8. GRANT EXECUTE PERMISSIONS ON ALL RPCs
-- =====================================================================
GRANT EXECUTE ON FUNCTION public.setup_customer_password(TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.check_customer_auth_status(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reset_customer_password(TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_customer_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;
GRANT EXECUTE ON FUNCTION public.register_guest_customer(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.sync_customer_with_code(UUID, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, service_role;



