-- =====================================================================
-- ORDERKART SCHEDULING & PRE-ORDER MIGRATION
-- =====================================================================
-- Run this in your Supabase SQL Editor to update tables and place_order_secure.
-- =====================================================================

-- 1. Add scheduling columns to areas table
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS preorder_enabled boolean DEFAULT true;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS max_preorder_days integer DEFAULT 30;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS is_active_override boolean DEFAULT true;
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS cutoff_time time DEFAULT '23:59:00';

-- 2. Add scheduling columns to orders table
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_type text DEFAULT 'Normal';
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS order_taking_date date;

-- 3. Update place_order_secure SQL Function (RPC)
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text, date, text);
DROP FUNCTION IF EXISTS public.place_order_secure(text, text, jsonb, text, date, text, text, date);

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
  if v_customer_id is null then
    raise exception 'Unauthorized: User must be logged in to place an order.';
  end if;

  -- Fetch route mapping from customer profile
  SELECT id, name, phone, area_id, road_id, sub_road_id
  INTO v_customer_id, v_customer_name, v_customer_phone, v_area_id, v_road_id, v_sub_road_id
  FROM public.customers
  WHERE id = auth.uid() OR auth_user_id = auth.uid()
  LIMIT 1;

  -- Verify that the customer profile exists
  if v_customer_name is null then
    raise exception 'Customer profile not found.';
  end if;

  -- Fetch route names for historical snapshot
  SELECT name INTO v_area_name FROM public.areas WHERE id::text = v_area_id;
  SELECT name INTO v_road_name FROM public.roads WHERE id::text = v_road_id;
  SELECT name INTO v_sub_road_name FROM public.sub_roads WHERE id::text = v_sub_road_id;

  -- Fetch area schedule control variables
  SELECT delivery_schedule, preorder_enabled, max_preorder_days, is_active_override, cutoff_time
  INTO v_area_schedule, v_preorder_enabled, v_max_preorder_days, v_is_active_override, v_cutoff_time
  FROM public.areas 
  WHERE id::text = v_area_id;

  -- 2. Validate Schedule and Cutoff
  IF p_order_type IN ('Quick Order', 'Quick Delivery', 'Order Now') THEN
    v_order_taking_date := (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date;
    v_delivery_date := v_order_taking_date;

  ELSIF p_order_type = 'Normal' THEN
    -- Verify that a schedule exists for this area
    IF v_area_schedule IS NULL OR jsonb_array_length(v_area_schedule) = 0 THEN
      RAISE EXCEPTION 'Ordering schedule is not available for your Area. Please contact support.';
    END IF;

    -- Verify override status (holiday/maintenance check)
    IF NOT coalesce(v_is_active_override, true) THEN
      RAISE EXCEPTION 'Ordering is temporarily closed for your Area due to holiday or maintenance.';
    END IF;

    -- Get today's day of week name (e.g. 'Monday', 'Tuesday') in local Indian time (locale-independent)
    v_today_day := CASE EXTRACT(ISODOW FROM current_timestamp AT TIME ZONE 'Asia/Kolkata')
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 7 THEN 'Sunday'
    END;
    
    -- Check if today is configured as an active Order-Taking day
    IF NOT (v_area_schedule ? v_today_day) THEN
      RAISE EXCEPTION 'Today (%) is not an active order-taking day for your Area.', v_today_day;
    END IF;

    -- Check if order cutoff has passed
    IF (current_timestamp AT TIME ZONE 'Asia/Kolkata')::time > coalesce(v_cutoff_time, time '23:59:00') THEN
      RAISE EXCEPTION 'Ordering window for today has closed (Cutoff was %).', to_char(coalesce(v_cutoff_time, time '23:59:00'), 'HH12:MI AM');
    END IF;

    v_order_taking_date := (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date;
    v_delivery_date := v_order_taking_date + 1;

  ELSIF p_order_type = 'Pre-Order' THEN
    -- Verify that a schedule exists for this area
    IF v_area_schedule IS NULL OR jsonb_array_length(v_area_schedule) = 0 THEN
      RAISE EXCEPTION 'Ordering schedule is not available for your Area. Please contact support.';
    END IF;

    -- Verify override status (holiday/maintenance check)
    IF NOT coalesce(v_is_active_override, true) THEN
      RAISE EXCEPTION 'Ordering is temporarily closed for your Area due to holiday or maintenance.';
    END IF;

    IF NOT coalesce(v_preorder_enabled, true) THEN
      RAISE EXCEPTION 'Pre-ordering is disabled for your Area.';
    END IF;

    IF p_order_taking_date IS NULL THEN
      RAISE EXCEPTION 'Target order-taking date must be specified for pre-orders.';
    END IF;

    -- Pre-order target date must be in the future
    IF p_order_taking_date <= (current_timestamp AT TIME ZONE 'Asia/Kolkata')::date THEN
      RAISE EXCEPTION 'Pre-order target date must be in the future.';
    END IF;

    -- Validate target date's day of week matches schedule (locale-independent)
    v_target_day := CASE EXTRACT(ISODOW FROM p_order_taking_date)
      WHEN 1 THEN 'Monday'
      WHEN 2 THEN 'Tuesday'
      WHEN 3 THEN 'Wednesday'
      WHEN 4 THEN 'Thursday'
      WHEN 5 THEN 'Friday'
      WHEN 6 THEN 'Saturday'
      WHEN 7 THEN 'Sunday'
    END;
    IF NOT (v_area_schedule ? v_target_day) THEN
      RAISE EXCEPTION 'Target pre-order date (%) is not an active order-taking day for your Area.', v_target_day;
    END IF;

    v_order_taking_date := p_order_taking_date;
    v_delivery_date := p_order_taking_date + 1;
  ELSE
    RAISE EXCEPTION 'Invalid order type: %', p_order_type;
  END IF;

  -- Idempotency Check
  if p_idempotency_key is not null then
    select id, order_number, customer_id, customer_phone, delivery_address, order_date, status, total_amount
    into v_order_row
    from public.orders
    where idempotency_key::text = p_idempotency_key::text and customer_id::text = v_customer_id::text
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

  -- 3. Input Validation
  if p_delivery_address is null or trim(p_delivery_address) = '' then
    raise exception 'Delivery address is required.';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain at least one item.';
  end if;

  -- 4. Generate Order ID and unique Order Number
  v_order_id := gen_random_uuid();
  v_order_no := coalesce(p_offline_order_no, '#ORD-' || lpad(nextval('public.order_number_seq')::text, 4, '0'));

  -- 5. Create Order
  insert into public.orders (
    id, order_number, customer_id, customer_phone, delivery_address, 
    total_amount, idempotency_key, delivery_date, offline_order_no,
    area_id, area_name, road_id, road_name, sub_road_id, sub_road_name, customer_name,
    order_type, order_taking_date
  )
  values (
    v_order_id, v_order_no, v_customer_id, coalesce(p_customer_phone, v_customer_phone), p_delivery_address, 
    0.00, p_idempotency_key, v_delivery_date, p_offline_order_no,
    v_area_id, v_area_name, v_road_id, v_road_name, v_sub_road_id, v_sub_road_name, v_customer_name,
    p_order_type, v_order_taking_date
  );

  -- 6. Process Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    if v_quantity <= 0 then
      raise exception 'Quantity must be positive.';
    end if;

    select name, price, unit, is_available, is_enabled, description,
           order_now_price, order_now_stock, order_now_is_available
    into v_product_name, v_price, v_unit, v_is_available, v_is_enabled, v_description,
         v_order_now_price, v_order_now_stock, v_order_now_is_available
    from public.products
    where id = v_product_id
    for update;

    if not found or not coalesce(v_is_enabled, true) then
      raise exception 'Product % is unavailable or disabled.', coalesce(v_product_name, 'Selected item');
    end if;

    -- Distinct separation: Quick Order vs Normal / Pre-Order
    IF p_order_type IN ('Quick Order', 'Quick Delivery', 'Order Now') THEN
      -- Quick Order availability & stock check (STRICTLY INDEPENDENT of Home section)
      IF NOT coalesce(v_order_now_is_available, true) THEN
        RAISE EXCEPTION 'Product % is unavailable for Quick Order.', v_product_name;
      END IF;

      -- Quick Order price resolution
      IF (v_item->>'price') IS NOT NULL AND (v_item->>'price')::numeric > 0 THEN
        v_price := (v_item->>'price')::numeric;
      ELSIF v_order_now_price IS NOT NULL AND v_order_now_price > 0 THEN
        v_price := v_order_now_price;
      END IF;

      -- Quick Order stock resolution
      IF v_order_now_stock IS NOT NULL THEN
        v_stock := v_order_now_stock;
      ELSE
        v_stock := NULL;
      END IF;
    ELSE
      -- Normal / Pre-Order availability check (Home section)
      IF NOT coalesce(v_is_available, true) THEN
        RAISE EXCEPTION 'Product % is out of stock.', v_product_name;
      END IF;

      -- Normal order price resolution
      IF (v_item->>'price') IS NOT NULL AND (v_item->>'price')::numeric > 0 THEN
        v_price := (v_item->>'price')::numeric;
      END IF;

      -- Normal order stock resolution from description JSON or column
      v_stock := NULL;
      IF v_description IS NOT NULL AND v_description ~ '^\s*\{.*\}\s*$' THEN
        BEGIN
          v_stock := (v_description::jsonb->>'stock')::numeric;
        EXCEPTION WHEN OTHERS THEN
          v_stock := NULL;
        END;
      END IF;
    END IF;

    -- Deduct stock and update section-specific availability
    IF v_stock IS NOT NULL THEN
      IF v_stock < v_quantity THEN
        RAISE EXCEPTION 'Insufficient stock for product %: requested %, available %', v_product_name, v_quantity, v_stock;
      END IF;
      v_new_stock := v_stock - v_quantity;
      IF p_order_type IN ('Quick Order', 'Quick Delivery', 'Order Now') THEN
        UPDATE public.products 
        SET order_now_stock = v_new_stock, 
            order_now_is_available = (v_new_stock > 0) 
        WHERE id = v_product_id;
      ELSE
        v_updated_description := (v_description::jsonb || jsonb_build_object('stock', v_new_stock))::text;
        UPDATE public.products 
        SET description = v_updated_description, 
            is_available = (v_new_stock > 0) 
        WHERE id = v_product_id;
      END IF;
    END IF;

    v_item_total := v_quantity * v_price;
    v_total_amount := v_total_amount + v_item_total;

    insert into public.order_items (order_id, product_id, product_name, price, quantity, unit, total_price)
    values (v_order_id, v_product_id, v_product_name, v_price, v_quantity, v_unit, v_item_total);
  end loop;

  -- Apply delivery charge
  IF p_order_type IN ('Quick Order', 'Quick Delivery', 'Order Now') THEN
    select value::numeric into v_delivery_charge from public.settings where key = 'order_now_delivery_charge';
    if v_delivery_charge is null then
      select value::numeric into v_delivery_charge from public.settings where key = 'quick_delivery_charge';
    end if;
    if v_delivery_charge is null then
      v_delivery_charge := 10.00;
    end if;

    select value::numeric into v_free_delivery_threshold from public.settings where key = 'order_now_free_delivery_threshold';
    if v_free_delivery_threshold is null then
      v_free_delivery_threshold := 100000.00;
    end if;
  ELSE
    select value::numeric into v_delivery_charge from public.settings where key = 'delivery_charge';
    if v_delivery_charge is null then
      v_delivery_charge := 30.00;
    end if;

    select value::numeric into v_free_delivery_threshold from public.settings where key = 'free_delivery_threshold';
    if v_free_delivery_threshold is null then
      v_free_delivery_threshold := 300.00;
    end if;
  END IF;

  if v_total_amount > 0 and v_total_amount < v_free_delivery_threshold then
    v_total_amount := v_total_amount + v_delivery_charge;
  end if;

  if v_total_amount > 0 then
    v_total_amount := ceil(v_total_amount / 5.0) * 5.0;
  end if;

  update public.orders set total_amount = v_total_amount where id::text = v_order_id::text;

  select * into v_order_row from public.orders where id::text = v_order_id::text;

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
