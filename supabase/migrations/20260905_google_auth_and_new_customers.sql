-- =====================================================================
-- MIGRATION: Google Auth & New Customer Identification
-- Date: 2026-09-05
-- =====================================================================

-- 1. Add authentication & segment columns to customers
ALTER TABLE public.customers 
  ADD COLUMN IF NOT EXISTS auth_provider TEXT DEFAULT 'phone_password',
  ADD COLUMN IF NOT EXISTS google_id TEXT,
  ADD COLUMN IF NOT EXISTS is_new_customer BOOLEAN DEFAULT FALSE;

-- 2. Add is_new_customer_order to orders
ALTER TABLE public.orders 
  ADD COLUMN IF NOT EXISTS is_new_customer_order BOOLEAN DEFAULT FALSE;

-- 3. Create helpful indices
CREATE INDEX IF NOT EXISTS idx_customers_google_id ON public.customers(google_id) WHERE google_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_customers_auth_provider ON public.customers(auth_provider);
CREATE INDEX IF NOT EXISTS idx_customers_is_new ON public.customers(is_new_customer) WHERE is_new_customer IS TRUE;

-- 4. RPC function to safely link or register a Google Customer
CREATE OR REPLACE FUNCTION public.register_or_link_google_customer(
  p_google_id TEXT,
  p_email TEXT,
  p_name TEXT DEFAULT NULL,
  p_phone TEXT DEFAULT NULL,
  p_address TEXT DEFAULT NULL,
  p_area_id TEXT DEFAULT NULL,
  p_road_id TEXT DEFAULT NULL,
  p_sub_road_id TEXT DEFAULT NULL
)
RETURNS JSONB
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS \$\$
DECLARE
  v_customer_id UUID;
  v_existing_customer RECORD;
  v_is_new BOOLEAN := FALSE;
  v_clean_phone TEXT;
BEGIN
  -- Normalize phone if provided
  IF p_phone IS NOT NULL AND p_phone <> '' THEN
    v_clean_phone := regexp_replace(p_phone, '\D', '', 'g');
  END IF;

  -- Step 1: Check if customer already exists by google_id
  IF p_google_id IS NOT NULL AND p_google_id <> '' THEN
    SELECT * INTO v_existing_customer FROM public.customers WHERE google_id = p_google_id LIMIT 1;
  END IF;

  -- Step 2: If not found by google_id, check by verified email
  IF v_existing_customer.id IS NULL AND p_email IS NOT NULL AND p_email <> '' THEN
    SELECT * INTO v_existing_customer FROM public.customers WHERE lower(email) = lower(p_email) LIMIT 1;
  END IF;

  -- Step 3: If not found, check by phone number
  IF v_existing_customer.id IS NULL AND v_clean_phone IS NOT NULL AND length(v_clean_phone) = 10 THEN
    SELECT * INTO v_existing_customer FROM public.customers WHERE phone = v_clean_phone LIMIT 1;
  END IF;

  IF v_existing_customer.id IS NOT NULL THEN
    -- Customer exists -> update Google ID and email if not set
    v_customer_id := v_existing_customer.id;
    UPDATE public.customers
    SET
      google_id = COALESCE(google_id, p_google_id),
      email = COALESCE(email, p_email),
      auth_provider = CASE 
        WHEN auth_provider IS NULL OR auth_provider = 'phone_password' THEN 'google'
        ELSE auth_provider 
      END,
      name = CASE WHEN (name IS NULL OR name = '' OR name = 'Valued Customer') AND p_name IS NOT NULL AND p_name <> '' THEN p_name ELSE name END,
      phone = CASE WHEN (phone IS NULL OR phone = '') AND v_clean_phone IS NOT NULL THEN v_clean_phone ELSE phone END,
      address = CASE WHEN (address IS NULL OR address = '' OR address = 'N/A') AND p_address IS NOT NULL AND p_address <> '' THEN p_address ELSE address END,
      area_id = CASE WHEN area_id IS NULL AND p_area_id IS NOT NULL AND p_area_id <> '' THEN p_area_id::uuid ELSE area_id END,
      road_id = CASE WHEN road_id IS NULL AND p_road_id IS NOT NULL AND p_road_id <> '' THEN p_road_id::uuid ELSE road_id END,
      sub_road_id = CASE WHEN sub_road_id IS NULL AND p_sub_road_id IS NOT NULL AND p_sub_road_id <> '' THEN p_sub_road_id::uuid ELSE sub_road_id END,
      updated_at = now()
    WHERE id = v_customer_id;
  ELSE
    -- Brand new customer
    v_is_new := TRUE;
    v_customer_id := gen_random_uuid();
    INSERT INTO public.customers (
      id,
      name,
      phone,
      email,
      address,
      google_id,
      auth_provider,
      is_new_customer,
      is_guest,
      area_id,
      road_id,
      sub_road_id,
      created_at,
      updated_at
    ) VALUES (
      v_customer_id,
      COALESCE(p_name, 'Valued Customer'),
      v_clean_phone,
      p_email,
      p_address,
      p_google_id,
      'google',
      TRUE,
      FALSE,
      CASE WHEN p_area_id IS NOT NULL AND p_area_id <> '' THEN p_area_id::uuid ELSE NULL END,
      CASE WHEN p_road_id IS NOT NULL AND p_road_id <> '' THEN p_road_id::uuid ELSE NULL END,
      CASE WHEN p_sub_road_id IS NOT NULL AND p_sub_road_id <> '' THEN p_sub_road_id::uuid ELSE NULL END,
      now(),
      now()
    );
  END IF;

  -- Return the full customer record as JSON
  RETURN (
    SELECT json_build_object(
      'id', c.id,
      'name', c.name,
      'phone', c.phone,
      'email', c.email,
      'address', c.address,
      'google_id', c.google_id,
      'auth_provider', c.auth_provider,
      'is_new_customer', c.is_new_customer,
      'is_guest', c.is_guest,
      'customer_code', c.customer_code,
      'area_id', c.area_id,
      'road_id', c.road_id,
      'sub_road_id', c.sub_road_id,
      'area_name', a.name,
      'road_name', r.name,
      'sub_road_name', sr.name,
      'delivery_schedule', a.delivery_schedule,
      'cutoff_time', COALESCE(a.cutoff_time, '23:59'),
      'is_brand_new', v_is_new
    )
    FROM public.customers c
    LEFT JOIN public.areas a ON c.area_id = a.id
    LEFT JOIN public.roads r ON c.road_id = r.id
    LEFT JOIN public.sub_roads sr ON c.sub_road_id = sr.id
    WHERE c.id = v_customer_id
  );
END;
\$\$;
