-- =====================================================================
-- COMPREHENSIVE SUPABASE BACKEND SECURITY PATCH
-- =====================================================================
-- Purpose:
-- 1. Server-Authoritative Pricing & Total Calculation (Priority 1)
-- 2. Atomic Inventory Stock Validation & Locking (Priority 2)
-- 3. Row Level Security (RLS) Authorization (Priority 3)
-- 4. Order & Payment Status Immutability Protection (Priority 4)
-- 5. Strict Input Validation & Database Constraints (Priority 5)
-- =====================================================================

-- ---------------------------------------------------------------------
-- 0. SEQUENCES & CONSTRAINTS
-- ---------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS public.order_number_seq START WITH 1001;

ALTER TABLE IF EXISTS public.orders 
  DROP CONSTRAINT IF EXISTS chk_orders_total_positive,
  ADD CONSTRAINT chk_orders_total_positive CHECK (total_amount >= 0);

ALTER TABLE IF EXISTS public.order_items 
  DROP CONSTRAINT IF EXISTS chk_order_items_qty_positive,
  ADD CONSTRAINT chk_order_items_qty_positive CHECK (quantity > 0),
  DROP CONSTRAINT IF EXISTS chk_order_items_price_non_negative,
  ADD CONSTRAINT chk_order_items_price_non_negative CHECK (price >= 0);


-- ---------------------------------------------------------------------
-- 1. SERVER-AUTHORITATIVE PLACE_ORDER_SECURE RPC
-- ---------------------------------------------------------------------
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text, date, text);
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text, date, text, text, date);
DROP FUNCTION IF EXISTS public.place_order_secure CASCADE;

CREATE OR REPLACE FUNCTION public.place_order_secure(
  p_delivery_address text,
  p_customer_phone text,
  p_items jsonb,
  p_idempotency_key text default null,
  p_delivery_date date default null,
  p_offline_order_no text default null,
  p_order_type text default 'Normal',
  p_order_taking_date date default null
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, auth, extensions, pg_temp
AS $$
DECLARE
  v_customer_id uuid;
  v_order_id uuid;
  v_order_no text;
  v_item jsonb;
  v_product_id uuid;
  v_quantity numeric(12,3);
  v_authoritative_price numeric(12,2);
  v_product_name text;
  v_unit text;
  v_is_available boolean;
  v_is_enabled boolean;
  v_description text;
  v_stock numeric(12,3);
  v_new_stock numeric(12,3);
  v_item_total numeric(12,2);
  v_subtotal numeric(12,2) := 0.00;
  v_total_amount numeric(12,2) := 0.00;
  v_updated_description text;
  v_delivery_charge numeric(12,2);
  v_free_delivery_threshold numeric(12,2);
  v_order_row record;
  
  -- Route snapshot variables
  v_customer_name text;
  v_customer_phone text;
  v_area_id text;
  v_road_id text;
  v_sub_road_id text;
  v_area_name text;
  v_road_name text;
  v_sub_road_name text;

  -- Scheduling variables
  v_area_schedule jsonb;
  v_preorder_enabled boolean;
  v_max_preorder_days integer;
  v_is_active_override boolean;
  v_cutoff_time time;
  v_today_day text;
  v_target_day text;
  v_order_taking_date date;
  v_delivery_date date;
BEGIN
  -- 1. Authentication Check
  v_customer_id := auth.uid();
  IF v_customer_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be logged in to place an order.';
  END IF;

  -- Fetch customer profile strictly bound to the authenticated caller
  SELECT id, name, phone, area_id, road_id, sub_road_id
  INTO v_customer_id, v_customer_name, v_customer_phone, v_area_id, v_road_id, v_sub_road_id
  FROM public.customers
  WHERE id = auth.uid() OR auth_user_id = auth.uid()
  LIMIT 1;

  -- Fallback for unlinked legacy customer record matching verified phone
  IF v_customer_name IS NULL AND p_customer_phone IS NOT NULL AND TRIM(p_customer_phone) <> '' THEN
    SELECT id, name, phone, area_id, road_id, sub_road_id
    INTO v_customer_id, v_customer_name, v_customer_phone, v_area_id, v_road_id, v_sub_road_id
    FROM public.customers
    WHERE phone = p_customer_phone AND (auth_user_id IS NULL OR auth_user_id = auth.uid())
    LIMIT 1;

    IF v_customer_id IS NOT NULL THEN
      UPDATE public.customers SET auth_user_id = auth.uid() WHERE id = v_customer_id AND auth_user_id IS NULL;
    END IF;
  END IF;

  IF v_customer_name IS NULL THEN
    RAISE EXCEPTION 'Customer profile not found.';
  END IF;

  -- Fetch route names for historical snapshot
  IF v_area_id IS NOT NULL THEN
    SELECT name INTO v_area_name FROM public.areas WHERE id::text = v_area_id;
  END IF;
  IF v_road_id IS NOT NULL THEN
    SELECT name INTO v_road_name FROM public.roads WHERE id::text = v_road_id;
  END IF;
  IF v_sub_road_id IS NOT NULL THEN
    SELECT name INTO v_sub_road_name FROM public.sub_roads WHERE id::text = v_sub_road_id;
  END IF;

  -- Fetch area schedule control variables
  IF v_area_id IS NOT NULL THEN
    SELECT delivery_schedule, preorder_enabled, max_preorder_days, is_active_override, cutoff_time
    INTO v_area_schedule, v_preorder_enabled, v_max_preorder_days, v_is_active_override, v_cutoff_time
    FROM public.areas 
    WHERE id::text = v_area_id;
  END IF;

  -- Resilient schedule default: If area schedule is unconfigured, allow all 7 days
  IF v_area_schedule IS NULL OR jsonb_array_length(v_area_schedule) = 0 THEN
    v_area_schedule := jsonb_build_array('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday');
  END IF;

  -- Ensure max_preorder_days is at least 30 days in advance
  v_max_preorder_days := GREATEST(COALESCE(v_max_preorder_days, 30), 30);

  -- Sanitize p_offline_order_no: Only admins/staff can specify custom offline order numbers
  IF p_offline_order_no IS NOT NULL AND TRIM(p_offline_order_no) <> '' AND NOT public.is_admin() THEN
    p_offline_order_no := NULL;
  END IF;

  -- 2. Validate Schedule and Cutoff
  IF p_order_type = 'Normal' THEN
    IF NOT coalesce(v_is_active_override, true) THEN
      RAISE EXCEPTION 'Ordering is temporarily closed for your Area due to holiday or maintenance.';
    END IF;

    v_today_day := CASE EXTRACT(ISODOW FROM current_timestamp AT TIME ZONE 'Asia/Kolkata')
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 7 THEN 'Sunday'
    END;
    
    IF NOT (
      v_area_schedule ? v_today_day
      OR v_area_schedule ? lower(v_today_day)
      OR v_area_schedule ? initcap(v_today_day)
      OR v_area_schedule ? upper(v_today_day)
    ) THEN
      RAISE EXCEPTION 'Today (%) is not an active order-taking day for your Area.', v_today_day;
    END IF;

    IF (current_timestamp AT TIME ZONE 'Asia/Kolkata')::time > coalesce(v_cutoff_time, time '23:59:00') THEN
      RAISE EXCEPTION 'Ordering window for today has closed (Cutoff was %).', to_char(coalesce(v_cutoff_time, time '23:59:00'), 'HH12:MI AM');
    END IF;

    v_order_taking_date := (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date;
    v_delivery_date := v_order_taking_date + 1;

  ELSIF p_order_type = 'Pre-Order' THEN
    IF NOT coalesce(v_is_active_override, true) THEN
      RAISE EXCEPTION 'Ordering is temporarily closed for your Area due to holiday or maintenance.';
    END IF;

    IF NOT coalesce(v_preorder_enabled, true) THEN
      RAISE EXCEPTION 'Pre-ordering is disabled for your Area.';
    END IF;

    IF p_order_taking_date IS NULL THEN
      RAISE EXCEPTION 'Target order-taking date must be specified for pre-orders.';
    END IF;

    IF p_order_taking_date <= (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date THEN
      RAISE EXCEPTION 'Pre-order target date must be in the future.';
    END IF;

    -- Enforce maximum preorder advance days (at least 30 days)
    IF (p_order_taking_date - (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date) > v_max_preorder_days THEN
      RAISE EXCEPTION 'Pre-order date exceeds maximum allowed limit of % days in advance.', v_max_preorder_days;
    END IF;

    v_target_day := CASE EXTRACT(ISODOW FROM p_order_taking_date)
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 7 THEN 'Sunday'
    END;

    -- Case-insensitive check on schedule array
    IF NOT (
      v_area_schedule ? v_target_day
      OR v_area_schedule ? lower(v_target_day)
      OR v_area_schedule ? initcap(v_target_day)
      OR v_area_schedule ? upper(v_target_day)
    ) THEN
      RAISE EXCEPTION 'Target pre-order date (%) is not an active order-taking day for your Area.', v_target_day;
    END IF;

    v_order_taking_date := p_order_taking_date;
    v_delivery_date := p_order_taking_date + 1;
  ELSE
    RAISE EXCEPTION 'Invalid order type: %', p_order_type;
  END IF;

  -- 3. Idempotency Check
  IF p_idempotency_key IS NOT NULL AND TRIM(p_idempotency_key) <> '' THEN
    SELECT id, order_number, customer_id, customer_phone, delivery_address, order_date, status, total_amount
    INTO v_order_row
    FROM public.orders
    WHERE idempotency_key::text = p_idempotency_key::text AND customer_id::text = v_customer_id::text
    LIMIT 1;
    
    IF v_order_row.id IS NOT NULL THEN
      RETURN jsonb_build_object(
        'id', v_order_row.id,
        'order_number', v_order_row.order_number,
        'customer_id', v_order_row.customer_id,
        'customer_phone', v_order_row.customer_phone,
        'delivery_address', v_order_row.delivery_address,
        'order_date', to_char(v_order_row.order_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
        'status', v_order_row.status,
        'total_amount', v_order_row.total_amount
      );
    END IF;
  END IF;

  -- 4. Input Validation
  IF p_delivery_address IS NULL OR TRIM(p_delivery_address) = '' THEN
    RAISE EXCEPTION 'Delivery address is required.';
  END IF;

  IF p_items IS NULL OR jsonb_array_length(p_items) = 0 THEN
    RAISE EXCEPTION 'Order must contain at least one item.';
  END IF;

  -- 5. Generate Order ID and unique Order Number
  v_order_id := gen_random_uuid();
  v_order_no := coalesce(p_offline_order_no, '#ORD-' || lpad(nextval('public.order_number_seq')::text, 4, '0'));

  -- Insert initial order record with valid schema columns
  INSERT INTO public.orders (
    id, order_number, customer_id, customer_phone, delivery_address, 
    total_amount, idempotency_key, delivery_date, offline_order_no,
    area_id, area_name, road_id, road_name, sub_road_id, sub_road_name, customer_name,
    order_type, order_taking_date, status
  )
  VALUES (
    v_order_id, v_order_no, v_customer_id, COALESCE(p_customer_phone, v_customer_phone), p_delivery_address, 
    0.00, p_idempotency_key, v_delivery_date, p_offline_order_no,
    v_area_id, v_area_name, v_road_id, v_road_name, v_sub_road_id, v_sub_road_name, v_customer_name,
    p_order_type, v_order_taking_date, 'Pending'
  );

  -- 6. Process Items with Server-Authoritative Pricing and Stock Locking
  FOR v_item IN SELECT * FROM jsonb_array_elements(p_items) LOOP
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    -- Strict Server-Side Quantity Validation (Priority 2 & 5)
    IF v_quantity IS NULL OR v_quantity <= 0 OR v_quantity > 1000 THEN
      RAISE EXCEPTION 'Invalid quantity % for item.', v_quantity;
    END IF;

    -- ATOMIC LOCK: Row-level lock on products table with mode-specific stock & price
    IF p_order_type = 'Quick Order' THEN
      SELECT name, 
             COALESCE(order_now_price, selling_price, price), 
             unit, 
             COALESCE(order_now_is_available, is_available, true), 
             is_enabled, 
             description, 
             COALESCE(order_now_stock, stock),
             (order_now_stock IS NOT NULL)
      INTO v_product_name, v_authoritative_price, v_unit, v_is_available, v_is_enabled, v_description, v_stock, v_is_order_now_stock
      FROM public.products
      WHERE id = v_product_id
      FOR UPDATE;
    ELSE
      SELECT name, 
             COALESCE(selling_price, price), 
             unit, 
             is_available, 
             is_enabled, 
             description, 
             stock,
             false
      INTO v_product_name, v_authoritative_price, v_unit, v_is_available, v_is_enabled, v_description, v_stock, v_is_order_now_stock
      FROM public.products
      WHERE id = v_product_id
      FOR UPDATE;
    END IF;

    IF NOT FOUND OR NOT COALESCE(v_is_enabled, true) THEN
      RAISE EXCEPTION 'Product % is unavailable or disabled.', COALESCE(v_product_name, 'Selected item');
    END IF;

    IF NOT COALESCE(v_is_available, true) THEN
      RAISE EXCEPTION 'Product % is out of stock.', v_product_name;
    END IF;

    -- Extract stock from column or description JSON if column was null
    IF v_stock IS NULL AND v_description IS NOT NULL AND v_description ~ '^\s*\{.*\}\s*$' THEN
      BEGIN
        v_stock := (v_description::jsonb->>'stock')::numeric;
      EXCEPTION WHEN OTHERS THEN
        v_stock := NULL;
      END;
    END IF;

    -- Atomic Stock Validation & Deduction (only when stock tracking is active)
    IF v_stock IS NOT NULL AND v_stock > 0 THEN
      IF v_stock < v_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for %: requested %, available %', v_product_name, v_quantity, v_stock;
      END IF;
      v_new_stock := v_stock - v_quantity;

      IF p_order_type = 'Quick Order' AND v_is_order_now_stock THEN
        UPDATE public.products 
        SET order_now_stock = v_new_stock,
            order_now_is_available = (v_new_stock > 0) 
        WHERE id = v_product_id;
      ELSE
        IF v_description IS NOT NULL AND v_description ~ '^\s*\{.*\}\s*$' THEN
          v_updated_description := (v_description::jsonb || jsonb_build_object('stock', v_new_stock))::text;
        ELSE
          v_updated_description := v_description;
        END IF;

        UPDATE public.products 
        SET stock = v_new_stock,
            description = v_updated_description, 
            is_available = (v_new_stock > 0) 
        WHERE id = v_product_id;
      END IF;
    END IF;

    -- Server-Authoritative Line Item Calculation (Priority 1)
    v_item_total := ROUND(v_quantity * v_authoritative_price, 2);
    v_subtotal := v_subtotal + v_item_total;

    INSERT INTO public.order_items (
      order_id, product_id, product_name, price, quantity, unit, total_price,
      selling_price_snapshot, line_total
    )
    VALUES (
      v_order_id, v_product_id, v_product_name, v_authoritative_price, v_quantity, v_unit, v_item_total,
      v_authoritative_price, v_item_total
    );
  END LOOP;

  -- 7. Server-Authoritative Delivery Fee & Grand Total Calculation (Priority 1)
  SELECT value::numeric INTO v_delivery_charge FROM public.settings WHERE key = 'delivery_charge';
  IF v_delivery_charge IS NULL THEN
    v_delivery_charge := 10.00;
  END IF;

  SELECT value::numeric INTO v_free_delivery_threshold FROM public.settings WHERE key = 'free_delivery_threshold';
  IF v_free_delivery_threshold IS NULL THEN
    v_free_delivery_threshold := 900.00;
  END IF;

  v_total_amount := v_subtotal;
  IF v_subtotal > 0 AND v_subtotal < v_free_delivery_threshold THEN
    v_total_amount := v_total_amount + v_delivery_charge;
  END IF;

  -- Apply 5-rupee rounding rule
  IF v_total_amount > 0 THEN
    v_total_amount := CEIL(v_total_amount / 5.0) * 5.0;
  END IF;

  -- Final update with server-computed authoritative total
  UPDATE public.orders 
  SET total_amount = v_total_amount 
  WHERE id = v_order_id;

  SELECT * INTO v_order_row FROM public.orders WHERE id = v_order_id;

  RETURN jsonb_build_object(
    'id', v_order_row.id,
    'order_number', v_order_row.order_number,
    'customer_id', v_order_row.customer_id,
    'customer_name', v_order_row.customer_name,
    'customer_phone', v_order_row.customer_phone,
    'delivery_address', v_order_row.delivery_address,
    'order_date', to_char(v_order_row.order_date, 'YYYY-MM-DD"T"HH24:MI:SS.MS"Z"'),
    'status', v_order_row.status,
    'total_amount', v_order_row.total_amount,
    'delivery_date', to_char(v_order_row.delivery_date, 'YYYY-MM-DD'),
    'order_type', v_order_row.order_type,
    'order_taking_date', to_char(v_order_row.order_taking_date, 'YYYY-MM-DD')
  );
END;
$$;


-- ---------------------------------------------------------------------
-- 2. ORDER IMMUTABILITY & STATUS PROTECTION TRIGGER (Priority 4)
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION public.protect_order_mutation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public', 'auth', 'extensions', 'pg_temp'
AS $$
BEGIN
  IF current_user IN ('authenticated', 'anon') AND auth.uid() IS NOT NULL THEN
    IF NOT public.is_admin() THEN
      -- Disallow altering total amount
      IF NEW.total_amount <> OLD.total_amount THEN
        RAISE EXCEPTION 'Unauthorized: Order totals are immutable once created.';
      END IF;

      -- Disallow altering status to anything directly
      IF NEW.status IS DISTINCT FROM OLD.status THEN
        RAISE EXCEPTION 'Unauthorized: Order status cannot be modified by customer directly.';
      END IF;

      -- Disallow reassigning order ownership
      IF NEW.customer_id IS DISTINCT FROM OLD.customer_id THEN
        RAISE EXCEPTION 'Unauthorized: Order ownership is immutable.';
      END IF;
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_protect_order_mutation ON public.orders;
CREATE TRIGGER trg_protect_order_mutation
  BEFORE UPDATE ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.protect_order_mutation();


-- ---------------------------------------------------------------------
-- 3. ROW LEVEL SECURITY (RLS) POLICIES (Priority 3)
-- ---------------------------------------------------------------------
ALTER TABLE public.orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.customers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.products ENABLE ROW LEVEL SECURITY;

-- Products: Everyone can read active products
DROP POLICY IF EXISTS "products_select_policy" ON public.products;
CREATE POLICY "products_select_policy" ON public.products
  FOR SELECT TO authenticated, anon
  USING (true);

-- Customers: Can select and update only own profile
DROP POLICY IF EXISTS "customers_select_own" ON public.customers;
CREATE POLICY "customers_select_own" ON public.customers
  FOR SELECT TO authenticated
  USING (id = auth.uid() OR auth_user_id = auth.uid());

-- Orders: Can only read own orders
DROP POLICY IF EXISTS "orders_select_own" ON public.orders;
CREATE POLICY "orders_select_own" ON public.orders
  FOR SELECT TO authenticated
  USING (
    customer_id = auth.uid()
    OR customer_id IN (
      SELECT id FROM public.customers WHERE auth_user_id = auth.uid() OR id = auth.uid()
    )
  );

-- Order Items: Can only read items belonging to own orders
DROP POLICY IF EXISTS "order_items_select_own" ON public.order_items;
CREATE POLICY "order_items_select_own" ON public.order_items
  FOR SELECT TO authenticated
  USING (
    EXISTS (
      SELECT 1 FROM public.orders 
      WHERE orders.id = order_items.order_id 
        AND (
          orders.customer_id = auth.uid()
          OR orders.customer_id IN (
            SELECT id FROM public.customers WHERE auth_user_id = auth.uid() OR id = auth.uid()
          )
        )
    )
  );

-- ---------------------------------------------------------------------
-- 4. PERMISSIONS & RPC ACCESS
-- ---------------------------------------------------------------------
-- Revoke direct table mutations: All order insertions must go through place_order_secure
REVOKE INSERT, UPDATE, DELETE ON public.orders FROM authenticated, anon;
REVOKE INSERT, UPDATE, DELETE ON public.order_items FROM authenticated, anon;

GRANT EXECUTE ON FUNCTION public.place_order_secure(text, text, jsonb, text, date, text, text, date) TO authenticated, anon;
