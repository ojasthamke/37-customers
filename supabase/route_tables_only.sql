-- =====================================================================
-- ORDERKART ROUTE TABLES SETUP (Clean — No Mock Data)
-- =====================================================================
-- Run this in your Supabase SQL Editor ONCE to create the route
-- hierarchy tables and update the sync_customer_with_code function.
-- This script is safe, idempotent, and contains NO mock/seed data.
-- =====================================================================

-- 0. Define is_admin helper function
CREATE OR REPLACE FUNCTION public.is_admin()
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
  RETURN coalesce(
    auth.role() = 'service_role' OR
    lower(auth.jwt() ->> 'email') IN ('admin@aplibhaji.com', 'ojasthamkes@gmail.com'),
    false
  );
END;
$$;

-- 1. Create Areas table
CREATE TABLE IF NOT EXISTS public.areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  area_code text UNIQUE,
  name text UNIQUE NOT NULL,
  delivery_schedule jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

-- 2. Create Roads table
CREATE TABLE IF NOT EXISTS public.roads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  road_code text UNIQUE,
  area_id uuid NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  name text NOT NULL,
  delivery_schedule jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_road_name_in_area UNIQUE(area_id, name)
);

-- 3. Create Sub-Roads table
CREATE TABLE IF NOT EXISTS public.sub_roads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subroad_code text UNIQUE,
  road_id uuid NOT NULL REFERENCES public.roads(id) ON DELETE CASCADE,
  name text NOT NULL,
  delivery_schedule jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_sub_road_name_in_road UNIQUE(road_id, name)
);

-- 4. Add route columns to customers (safe, idempotent)
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS area_id uuid REFERENCES public.areas(id) ON DELETE SET NULL;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS road_id uuid REFERENCES public.roads(id) ON DELETE SET NULL;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS sub_road_id uuid REFERENCES public.sub_roads(id) ON DELETE SET NULL;

-- 5. Add route snapshot columns to orders (safe, idempotent)
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_date date;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_id uuid REFERENCES public.areas(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS road_id uuid REFERENCES public.roads(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS road_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sub_road_id uuid REFERENCES public.sub_roads(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sub_road_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS offline_order_no text;

-- 6. Enable RLS
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_roads ENABLE ROW LEVEL SECURITY;

-- 7. Create RLS Policies (idempotent)
DROP POLICY IF EXISTS "Allow select areas" ON public.areas;
CREATE POLICY "Allow select areas" ON public.areas FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins have full access to areas" ON public.areas;
CREATE POLICY "Admins have full access to areas" ON public.areas FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Allow select roads" ON public.roads;
CREATE POLICY "Allow select roads" ON public.roads FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins have full access to roads" ON public.roads;
CREATE POLICY "Admins have full access to roads" ON public.roads FOR ALL USING (public.is_admin());

DROP POLICY IF EXISTS "Allow select sub_roads" ON public.sub_roads;
CREATE POLICY "Allow select sub_roads" ON public.sub_roads FOR SELECT USING (true);
DROP POLICY IF EXISTS "Admins have full access to sub_roads" ON public.sub_roads;
CREATE POLICY "Admins have full access to sub_roads" ON public.sub_roads FOR ALL USING (public.is_admin());

-- 8. Update sync_customer_with_code to include route parameters
-- Drop old overloaded versions of the sync function to prevent PGRST203 candidate resolution errors in PostgREST
-- 8. Update sync_customer_with_code to include route parameters
-- Drop old overloaded versions of the sync function to prevent PGRST203 candidate resolution errors in PostgREST
DROP FUNCTION IF EXISTS public.sync_customer_with_code(uuid, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.sync_customer_with_code(uuid, text, text, text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.sync_customer_with_code(uuid, text, text, text, text, text, uuid, uuid, uuid);

CREATE OR REPLACE FUNCTION public.sync_customer_with_code(
  p_id uuid, p_name text, p_phone text, p_email text, p_address text, p_customer_code text,
  p_area_id uuid default null, p_road_id uuid default null, p_sub_road_id uuid default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_email text;
  v_user_id uuid;
  v_customer_code text;
  v_random_password text;
BEGIN
  -- Verify caller is an admin
  IF NOT public.is_admin() THEN
    RAISE EXCEPTION 'Unauthorized: Only administrators can synchronize customer codes.';
  END IF;

  v_customer_code := upper(trim(p_customer_code));
  if v_customer_code = '' then v_customer_code := null; END IF;

  if v_customer_code is not null then
    if exists (select 1 from public.customers where customer_code = v_customer_code and id != p_id) then
      raise exception 'Customer code already assigned. Please enter another code.';
    end if;
    v_email := lower(v_customer_code) || '@aplibhaji.com';
  else
    v_email := lower(p_id::text) || '@placeholder.aplibhaji.com';
  end if;

  select id into v_user_id from auth.users where id = p_id;

  if v_user_id is null then
    v_random_password := encode(gen_random_bytes(32), 'hex');
    insert into auth.users (
      instance_id, id, aud, role, email, encrypted_password,
      email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
      created_at, updated_at, confirmation_token, recovery_token,
      email_change_token_new, email_change
    ) values (
      '00000000-0000-0000-0000-000000000000', p_id, 'authenticated', 'authenticated',
      v_email, extensions.crypt(v_random_password, extensions.gen_salt('bf')),
      now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
      jsonb_build_object(
        'name', p_name,
        'phone', p_phone,
        'address', p_address,
        'area_id', p_area_id,
        'road_id', p_road_id,
        'sub_road_id', p_sub_road_id
      ),
      now(), now(), '', '', '', ''
    );
  else
    update auth.users set
      email = v_email,
      raw_user_meta_data = jsonb_build_object(
        'name', p_name,
        'phone', p_phone,
        'address', p_address,
        'area_id', p_area_id,
        'road_id', p_road_id,
        'sub_road_id', p_sub_road_id
      ),
      updated_at = now()
    where id = p_id;
  end if;

  insert into public.customers (id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id)
  values (p_id, p_name, p_phone, v_email, p_address, v_customer_code, p_area_id, p_road_id, p_sub_road_id)
  on conflict (id) do update set
    name = excluded.name, phone = excluded.phone, email = excluded.email,
    address = excluded.address, customer_code = excluded.customer_code,
    area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
END;
$$;

-- 9. Clean up and Update place_order_secure (6 parameters)
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text);
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text, date, text);

CREATE OR REPLACE FUNCTION public.place_order_secure(
  p_delivery_address text,
  p_customer_phone text,
  p_items jsonb,
  p_idempotency_key text default null,
  p_delivery_date date default null,
  p_offline_order_no text default null
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_customer_id uuid;
  v_order_id uuid;
  v_order_no text;
  v_total_amount numeric(12,2) := 0.00;
  v_item jsonb;
  v_product_id uuid;
  v_quantity numeric(12,3);
  v_price numeric(12,2);
  v_product_name text;
  v_unit text;
  v_is_available boolean;
  v_is_enabled boolean;
  v_description text;
  v_stock numeric(12,3);
  v_new_stock numeric(12,3);
  v_item_total numeric(12,2);
  v_updated_description text;
  v_delivery_charge numeric(12,2);
  v_free_delivery_threshold numeric(12,2);
  v_order_row record;
  
  -- Route snapshot variables
  v_customer_name text;
  v_customer_phone text;
  v_area_id uuid;
  v_road_id uuid;
  v_sub_road_id uuid;
  v_area_name text;
  v_road_name text;
  v_sub_road_name text;
BEGIN
  -- 1. Authentication Check
  v_customer_id := auth.uid();
  if v_customer_id is null then
    raise exception 'Unauthorized: User must be logged in to place an order.';
  end if;

  -- Fetch route mapping from customer profile
  SELECT name, phone, area_id, road_id, sub_road_id
  INTO v_customer_name, v_customer_phone, v_area_id, v_road_id, v_sub_road_id
  FROM public.customers
  WHERE id = v_customer_id;

  -- Verify that the customer profile exists
  if v_customer_name is null then
    raise exception 'Customer profile not found.';
  end if;

  -- Fetch route names for historical snapshot
  SELECT name INTO v_area_name FROM public.areas WHERE id = v_area_id;
  SELECT name INTO v_road_name FROM public.roads WHERE id = v_road_id;
  SELECT name INTO v_sub_road_name FROM public.sub_roads WHERE id = v_sub_road_id;

  -- Idempotency Check
  if p_idempotency_key is not null then
    select id, order_number, customer_id, customer_phone, delivery_address, order_date, status, total_amount
    into v_order_row
    from public.orders
    where idempotency_key = p_idempotency_key and customer_id = v_customer_id
    limit 1;
    
    if v_order_row.id is not null then
      return jsonb_build_object(
        'id', v_order_row.id,
        'order_number', v_order_row.order_number,
        'customer_id', v_order_row.customer_id,
        'customer_phone', v_order_row.customer_phone,
        'delivery_address', v_order_row.delivery_address,
        'order_date', to_char(v_order_row.order_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'status', v_order_row.status,
        'total_amount', v_order_row.total_amount
      );
    end if;
  end if;

  -- 2. Input Validation
  if p_delivery_address is null or trim(p_delivery_address) = '' then
    raise exception 'Delivery address is required.';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain at least one item.';
  end if;

  -- 3. Generate Order ID and unique Order Number
  v_order_id := gen_random_uuid();
  v_order_no := coalesce(p_offline_order_no, '#ORD-' || lpad(nextval('public.order_number_seq')::text, 4, '0'));

  -- 4. Create Order
  insert into public.orders (
    id, order_number, customer_id, customer_phone, delivery_address, 
    total_amount, idempotency_key, delivery_date, offline_order_no,
    area_id, area_name, road_id, road_name, sub_road_id, sub_road_name, customer_name
  )
  values (
    v_order_id, v_order_no, v_customer_id, coalesce(p_customer_phone, v_customer_phone), p_delivery_address, 
    0.00, p_idempotency_key, p_delivery_date, p_offline_order_no,
    v_area_id, v_area_name, v_road_id, v_road_name, v_sub_road_id, v_sub_road_name, v_customer_name
  );

  -- 5. Process Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    if v_quantity <= 0 then
      raise exception 'Quantity must be positive.';
    end if;

    select name, price, unit, is_available, is_enabled, description
    into v_product_name, v_price, v_unit, v_is_available, v_is_enabled, v_description
    from public.products
    where id = v_product_id
    for update;

    if not found or not v_is_enabled or not v_is_available then
      raise exception 'Product is unavailable.';
    end if;

    v_stock := null;
    if v_description is not null and v_description ~ '^\s*\{.*\}\s*$' then
      begin
        v_stock := (v_description::jsonb->>'stock')::numeric;
      exception when others then
        v_stock := null;
      end;
    end if;

    if v_stock is not null then
      if v_stock < v_quantity then
        raise exception 'Insufficient stock for product %: requested %, available %', v_product_name, v_quantity, v_stock;
      end if;
      v_new_stock := v_stock - v_quantity;
      v_updated_description := (v_description::jsonb || jsonb_build_object('stock', v_new_stock))::text;
      update public.products set description = v_updated_description, is_available = (v_new_stock > 0) where id = v_product_id;
    end if;

    v_item_total := v_quantity * v_price;
    v_total_amount := v_total_amount + v_item_total;

    insert into public.order_items (order_id, product_id, product_name, price, quantity, unit, total_price)
    values (v_order_id, v_product_id, v_product_name, v_price, v_quantity, v_unit, v_item_total);
  end loop;

  -- Apply delivery charge
  select value::numeric into v_delivery_charge from public.settings where key = 'delivery_charge';
  if v_delivery_charge is null then
    v_delivery_charge := 30.00;
  end if;

  select value::numeric into v_free_delivery_threshold from public.settings where key = 'free_delivery_threshold';
  if v_free_delivery_threshold is null then
    v_free_delivery_threshold := 300.00;
  end if;

  if v_total_amount > 0 and v_total_amount < v_free_delivery_threshold then
    v_total_amount := v_total_amount + v_delivery_charge;
  end if;

  if v_total_amount > 0 then
    v_total_amount := ceil(v_total_amount / 5.0) * 5.0;
  end if;

  update public.orders set total_amount = v_total_amount where id = v_order_id;

  select * into v_order_row from public.orders where id = v_order_id;

  return jsonb_build_object(
    'id', v_order_row.id,
    'order_number', v_order_row.order_number,
    'customer_id', v_order_row.customer_id,
    'customer_phone', v_order_row.customer_phone,
    'delivery_address', v_order_row.delivery_address,
    'order_date', to_char(v_order_row.order_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'status', v_order_row.status,
    'total_amount', v_order_row.total_amount
  );
END;
$$;

-- 10. Clean up and Update update_customer_profile (with UUIDs)
DROP FUNCTION IF EXISTS public.update_customer_profile(text, text, text, text, text, text);
DROP FUNCTION IF EXISTS public.update_customer_profile(text, text, text, uuid, uuid, uuid);

CREATE OR REPLACE FUNCTION public.update_customer_profile(
  p_name text, p_phone text, p_address text,
  p_area_id uuid default null, p_road_id uuid default null, p_sub_road_id uuid default null
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, pg_temp
AS $$
DECLARE
  v_customer_id uuid;
BEGIN
  v_customer_id := auth.uid();
  if v_customer_id is null then
    raise exception 'Unauthorized';
  end if;

  update auth.users set
    raw_user_meta_data = jsonb_build_object(
      'name', p_name,
      'phone', p_phone,
      'address', p_address,
      'area_id', p_area_id,
      'road_id', p_road_id,
      'sub_road_id', p_sub_road_id
    ),
    updated_at = now()
  where id = v_customer_id;

  insert into public.customers (id, name, phone, address, area_id, road_id, sub_road_id)
  values (v_customer_id, p_name, p_phone, p_address, p_area_id, p_road_id, p_sub_road_id)
  on conflict (id) do update set
    name = excluded.name,
    phone = excluded.phone,
    address = excluded.address,
    area_id = excluded.area_id,
    road_id = excluded.road_id,
    sub_road_id = excluded.sub_road_id;
END;
$$;

-- 11. Clean up and Update get_effective_schedule (with UUIDs)
DROP FUNCTION IF EXISTS public.get_effective_schedule(text, text, text);
DROP FUNCTION IF EXISTS public.get_effective_schedule(uuid, uuid, uuid);

CREATE OR REPLACE FUNCTION public.get_effective_schedule(
  p_area_id uuid,
  p_road_id uuid,
  p_sub_road_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_schedule jsonb;
BEGIN
  -- 1. Try Sub-Road schedule
  if p_sub_road_id is not null then
    select delivery_schedule into v_schedule from public.sub_roads where id = p_sub_road_id;
    if v_schedule is not null and jsonb_array_length(v_schedule) > 0 then
      return v_schedule;
    end if;
  end if;

  -- 2. Try Road schedule
  if p_road_id is not null then
    select delivery_schedule into v_schedule from public.roads where id = p_road_id;
    if v_schedule is not null and jsonb_array_length(v_schedule) > 0 then
      return v_schedule;
    end if;
  end if;

  -- 3. Try Area schedule
  if p_area_id is not null then
    select delivery_schedule into v_schedule from public.areas where id = p_area_id;
    if v_schedule is not null and jsonb_array_length(v_schedule) > 0 then
      return v_schedule;
    end if;
  end if;

  return '[]'::jsonb;
END;
$$;

-- 12. Update User Self-Registration Trigger (to capture Area/Road/Sub-road UUIDs)
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS trigger AS $$
BEGIN
  INSERT INTO public.customers (id, name, phone, email, address, area_id, road_id, sub_road_id)
  VALUES (
    new.id,
    coalesce(new.raw_user_meta_data->>'name', 'Valued Customer'),
    coalesce(new.raw_user_meta_data->>'phone', ''),
    new.email,
    coalesce(new.raw_user_meta_data->>'address', ''),
    (new.raw_user_meta_data->>'area_id')::uuid,
    (new.raw_user_meta_data->>'road_id')::uuid,
    (new.raw_user_meta_data->>'sub_road_id')::uuid
  )
  ON CONFLICT (id) DO UPDATE SET
    name = excluded.name,
    phone = excluded.phone,
    email = excluded.email,
    address = excluded.address,
    area_id = excluded.area_id,
    road_id = excluded.road_id,
    sub_road_id = excluded.sub_road_id;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;
