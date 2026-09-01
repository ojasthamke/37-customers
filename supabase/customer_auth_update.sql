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
  v_customer_id UUID;
  v_phone TEXT;
  v_email TEXT;
  v_existing_password TEXT;
  v_existing_auth_id UUID;
  v_auth_user_id UUID;
  v_digits TEXT;
  v_last10 TEXT;
  v_formatted_password TEXT;
BEGIN
  -- Normalize code
  p_code := UPPER(TRIM(p_code));
  
  -- Extract digits if identifier is a phone number
  v_digits := regexp_replace(p_code, '\D', '', 'g');
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
  ELSE
    v_last10 := '';
  END IF;
  
  -- Find customer by customer_code or phone
  SELECT id, phone, password, auth_user_id 
  INTO v_customer_id, v_phone, v_existing_password, v_existing_auth_id
  FROM public.customers
  WHERE UPPER(customer_code) = p_code
     OR phone = p_code
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Invalid Customer Code: %', p_code;
  END IF;

  -- 🛑 PREVENT CREATING PASSWORD MULTIPLE TIMES
  IF (v_existing_password IS NOT NULL AND TRIM(v_existing_password) <> '') OR v_existing_auth_id IS NOT NULL THEN
    RAISE EXCEPTION 'Password already created. Please use your existing password to log in or use Reset Password.';
  END IF;

  v_email := LOWER(p_code) || '@aplibhaji.com';

  -- Format password if needed
  IF LENGTH(TRIM(p_password)) < 6 THEN
    v_formatted_password := 'OK_' || TRIM(p_password) || '_2026';
  ELSE
    v_formatted_password := TRIM(p_password);
  END IF;

  -- Create or update auth.users password if exists
  SELECT id INTO v_auth_user_id FROM auth.users WHERE email = v_email LIMIT 1;

  -- Update public.customers details & password
  UPDATE public.customers
  SET 
    name = COALESCE(NULLIF(TRIM(p_name), ''), name),
    password = p_password,
    is_guest = FALSE,
    auth_user_id = v_auth_user_id
  WHERE id = v_customer_id;

  IF v_auth_user_id IS NOT NULL THEN
    UPDATE auth.users
    SET encrypted_password = crypt(v_formatted_password, gen_salt('bf'))
    WHERE id = v_auth_user_id;
  END IF;

  RETURN jsonb_build_object(
    'success', true,
    'customer_id', v_customer_id,
    'email', v_email
  );
END;
$$;


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
AS $$
DECLARE
  v_customer RECORD;
  v_has_password BOOLEAN := FALSE;
  v_digits TEXT;
  v_last10 TEXT;
BEGIN
  p_identifier := TRIM(p_identifier);
  
  -- Extract trailing 10 digits for phone numbers
  v_digits := regexp_replace(p_identifier, '\D', '', 'g');
  IF LENGTH(v_digits) >= 10 THEN
    v_last10 := RIGHT(v_digits, 10);
  ELSE
    v_last10 := '';
  END IF;
  
  SELECT id, name, phone, customer_code, auth_user_id, password
  INTO v_customer
  FROM public.customers
  WHERE UPPER(customer_code) = UPPER(p_identifier)
     OR phone = p_identifier
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer.id IS NULL THEN
    RETURN jsonb_build_object(
      'exists', false,
      'has_password', false,
      'message', 'Customer account not found.'
    );
  END IF;

  -- Determine if customer already has a password created
  IF v_customer.auth_user_id IS NOT NULL OR (v_customer.password IS NOT NULL AND TRIM(v_customer.password) <> '') THEN
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
  IF p_phone_confirm IS NOT NULL AND p_phone_confirm <> '' THEN
    v_conf_digits := regexp_replace(p_phone_confirm, '\D', '', 'g');
    IF LENGTH(v_conf_digits) >= 4 THEN
      v_conf_last4 := RIGHT(v_conf_digits, 4);
    ELSE
      v_conf_last4 := v_conf_digits;
    END IF;
    
    IF RIGHT(regexp_replace(v_phone, '\D', '', 'g'), 4) <> v_conf_last4 AND v_phone <> p_phone_confirm THEN
      RETURN jsonb_build_object('success', false, 'error', 'Mobile number does not match registered account details.');
    END IF;
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

CREATE OR REPLACE FUNCTION public.update_customer_profile(
  p_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_area_id TEXT DEFAULT NULL,
  p_road_id TEXT DEFAULT NULL,
  p_sub_road_id TEXT DEFAULT NULL
)
RETURNS BOOLEAN
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_user_id UUID := auth.uid();
BEGIN
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Not authenticated';
  END IF;

  UPDATE public.customers
  SET 
    name = p_name,
    phone = p_phone,
    address = p_address,
    area_id = p_area_id,
    road_id = p_road_id,
    sub_road_id = p_sub_road_id
  WHERE id = v_user_id;

  RETURN TRUE;
END;
$$;


-- =====================================================================
-- 6. RPC: REGISTER GUEST CUSTOMER (SEPARATE ROW IN CUSTOMERS TABLE)
-- =====================================================================
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT, UUID, UUID, UUID) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer(TEXT, TEXT, TEXT) CASCADE;
DROP FUNCTION IF EXISTS public.register_guest_customer CASCADE;

CREATE OR REPLACE FUNCTION public.register_guest_customer(
  p_name TEXT,
  p_phone TEXT,
  p_address TEXT,
  p_area_id TEXT DEFAULT NULL,
  p_road_id TEXT DEFAULT NULL,
  p_sub_road_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_customer_id UUID;
  v_digits TEXT;
  v_last10 TEXT;
  v_clean_phone TEXT;
  v_email TEXT;
  v_customer_row RECORD;
  v_area_uuid UUID;
  v_road_uuid UUID;
  v_sub_road_uuid UUID;
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

  -- Parse UUIDs safely
  IF p_area_id IS NOT NULL AND p_area_id <> '' THEN
    BEGIN v_area_uuid := p_area_id::uuid; EXCEPTION WHEN OTHERS THEN v_area_uuid := NULL; END;
  END IF;
  IF p_road_id IS NOT NULL AND p_road_id <> '' THEN
    BEGIN v_road_uuid := p_road_id::uuid; EXCEPTION WHEN OTHERS THEN v_road_uuid := NULL; END;
  END IF;
  IF p_sub_road_id IS NOT NULL AND p_sub_road_id <> '' THEN
    BEGIN v_sub_road_uuid := p_sub_road_id::uuid; EXCEPTION WHEN OTHERS THEN v_sub_road_uuid := NULL; END;
  END IF;

  -- Check if guest or customer exists by phone
  SELECT id INTO v_customer_id
  FROM public.customers
  WHERE phone = p_phone
     OR phone = v_clean_phone
     OR (v_last10 <> '' AND RIGHT(regexp_replace(phone, '\D', '', 'g'), 10) = v_last10)
  LIMIT 1;

  IF v_customer_id IS NOT NULL THEN
    -- Update existing customer record to ensure is_guest = TRUE
    UPDATE public.customers
    SET name = COALESCE(NULLIF(p_name, ''), name),
        address = COALESCE(NULLIF(p_address, ''), address),
        phone = p_phone,
        is_guest = TRUE,
        area_id = COALESCE(v_area_uuid, area_id),
        road_id = COALESCE(v_road_uuid, road_id),
        sub_road_id = COALESCE(v_sub_road_uuid, sub_road_id)
    WHERE id = v_customer_id;
  ELSE
    -- Create new guest record with is_guest = TRUE
    v_customer_id := gen_random_uuid();
    INSERT INTO public.customers (
      id, name, phone, email, address, is_guest,
      area_id, road_id, sub_road_id
    ) VALUES (
      v_customer_id, p_name, p_phone, v_email, p_address, TRUE,
      v_area_uuid, v_road_uuid, v_sub_road_uuid
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
-- 7. GRANT EXECUTE PERMISSIONS ON ALL RPCs
-- =====================================================================
GRANT EXECUTE ON FUNCTION public.setup_customer_password(TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.check_customer_auth_status(TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.reset_customer_password(TEXT, TEXT, TEXT) TO authenticated, anon;
GRANT EXECUTE ON FUNCTION public.update_customer_profile(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated;
GRANT EXECUTE ON FUNCTION public.register_guest_customer(TEXT, TEXT, TEXT, TEXT, TEXT, TEXT) TO authenticated, anon;


