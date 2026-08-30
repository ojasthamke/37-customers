-- =====================================================================
-- ORDERKART MASTER ROUTE & CUSTOMER MIGRATION SCRIPT
-- =====================================================================
-- Deterministically generated from orderkart_seeded.db
-- This script is safe and idempotent.
-- =====================================================================

-- 1. Create tables with UUID and stable codes if they do not exist
CREATE TABLE IF NOT EXISTS public.areas (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  area_code text UNIQUE NOT NULL,
  name text UNIQUE NOT NULL,
  delivery_schedule jsonb NOT NULL DEFAULT '[]'::jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL
);

CREATE TABLE IF NOT EXISTS public.roads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  road_code text UNIQUE NOT NULL,
  area_id uuid NOT NULL REFERENCES public.areas(id) ON DELETE CASCADE,
  name text NOT NULL,
  delivery_schedule jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_road_name_in_area UNIQUE(area_id, name)
);

CREATE TABLE IF NOT EXISTS public.sub_roads (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  subroad_code text UNIQUE NOT NULL,
  road_id uuid NOT NULL REFERENCES public.roads(id) ON DELETE CASCADE,
  name text NOT NULL,
  delivery_schedule jsonb,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()) NOT NULL,
  CONSTRAINT unique_sub_road_name_in_road UNIQUE(road_id, name)
);

-- 2. Add route UUID columns to customers
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS area_id uuid REFERENCES public.areas(id) ON DELETE SET NULL;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS road_id uuid REFERENCES public.roads(id) ON DELETE SET NULL;
ALTER TABLE public.customers ADD COLUMN IF NOT EXISTS sub_road_id uuid REFERENCES public.sub_roads(id) ON DELETE SET NULL;

-- 3. Add route UUID and snapshot columns to orders
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS delivery_date date;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_id uuid REFERENCES public.areas(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS area_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS road_id uuid REFERENCES public.roads(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS road_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sub_road_id uuid REFERENCES public.sub_roads(id) ON DELETE SET NULL;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS sub_road_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS customer_name text;
ALTER TABLE public.orders ADD COLUMN IF NOT EXISTS offline_order_no text;

-- Enable RLS
ALTER TABLE public.areas ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.roads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sub_roads ENABLE ROW LEVEL SECURITY;

-- Create RLS Policies
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

-- 3b. Ensure code columns exist (in case tables were pre-created without them)
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS area_code text UNIQUE;
ALTER TABLE public.roads ADD COLUMN IF NOT EXISTS road_code text UNIQUE;
ALTER TABLE public.sub_roads ADD COLUMN IF NOT EXISTS subroad_code text UNIQUE;

-- Ensure delivery_schedule column exists on areas
ALTER TABLE public.areas ADD COLUMN IF NOT EXISTS delivery_schedule jsonb NOT NULL DEFAULT '[]'::jsonb;

-- Ensure name column has UNIQUE constraint (safe idempotent)
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'areas_name_key' AND conrelid = 'public.areas'::regclass
  ) THEN
    ALTER TABLE public.areas ADD CONSTRAINT areas_name_key UNIQUE (name);
  END IF;
END $$;

-- 4. Insert Areas
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'AREA-000001', 'North Zone Sector 1', '["Monday", "Thursday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'AREA-000002', 'South Point Colony', '["Tuesday", "Friday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'AREA-000003', 'East Ridge Heights', '["Wednesday", "Saturday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'AREA-000004', 'West End Enclave', '["Monday", "Wednesday", "Friday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('d6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'AREA-000005', 'Central Business Hub', '["Tuesday", "Thursday", "Saturday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'AREA-000006', 'Metro Greens Phase 1', '["Monday", "Thursday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('d2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'AREA-000007', 'Riverside Boulevard', '["Tuesday", "Friday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'AREA-000008', 'Sunrise Gardens', '["Wednesday", "Saturday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'AREA-000009', 'Royal Palms Estate', '["Monday", "Wednesday", "Friday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;
INSERT INTO public.areas (id, area_code, name, delivery_schedule) VALUES ('f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'AREA-000010', 'Valley View Towers', '["Tuesday", "Thursday", "Saturday"]'::jsonb) ON CONFLICT (name) DO UPDATE SET delivery_schedule = excluded.delivery_schedule;

-- 5. Insert Roads
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'ROAD-000001', '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'Market Road 1') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, 'ROAD-000002', '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'MG Road 1') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'ROAD-000003', '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'Station Street 1') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'ROAD-000004', '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'Park Avenue 1') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'ROAD-000005', '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'Green Lane 1') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'ROAD-000006', '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'Market Road 2') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'ROAD-000007', '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'MG Road 2') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'ROAD-000008', '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'Station Street 2') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'ROAD-000009', '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'Park Avenue 2') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'ROAD-000010', '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'Green Lane 2') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'ROAD-000011', 'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'Market Road 3') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'ROAD-000012', 'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'MG Road 3') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'ROAD-000013', 'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'Station Street 3') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'ROAD-000014', 'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'Park Avenue 3') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'ROAD-000015', 'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'Green Lane 3') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'ROAD-000016', '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'Market Road 4') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'ROAD-000017', '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'MG Road 4') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'ROAD-000018', '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'Station Street 4') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'ROAD-000019', '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'Park Avenue 4') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'ROAD-000020', '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'Green Lane 4') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'ROAD-000021', 'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'Market Road 5') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'ROAD-000022', 'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'MG Road 5') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'ROAD-000023', 'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'Station Street 5') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'ROAD-000024', 'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'Park Avenue 5') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'ROAD-000025', 'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'Green Lane 5') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'ROAD-000026', '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'Market Road 6') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'ROAD-000027', '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'MG Road 6') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'ROAD-000028', '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'Station Street 6') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'ROAD-000029', '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'Park Avenue 6') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'ROAD-000030', '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, 'Green Lane 6') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'ROAD-000031', 'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'Market Road 7') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'ROAD-000032', 'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'MG Road 7') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'ROAD-000033', 'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'Station Street 7') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'ROAD-000034', 'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'Park Avenue 7') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('d2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'ROAD-000035', 'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'Green Lane 7') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'ROAD-000036', '675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'Market Road 8') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'ROAD-000037', '675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'MG Road 8') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'ROAD-000038', '675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'Station Street 8') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'ROAD-000039', '675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'Park Avenue 8') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'ROAD-000040', '675396a6-8cac-5e18-a301-63a79185a559'::uuid, 'Green Lane 8') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'ROAD-000041', '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'Market Road 9') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'ROAD-000042', '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'MG Road 9') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'ROAD-000043', '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'Station Street 9') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'ROAD-000044', '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'Park Avenue 9') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'ROAD-000045', '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'Green Lane 9') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'ROAD-000046', 'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'Market Road 10') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'ROAD-000047', 'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'MG Road 10') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'ROAD-000048', 'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'Station Street 10') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'ROAD-000049', 'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'Park Avenue 10') ON CONFLICT (area_id, name) DO NOTHING;
INSERT INTO public.roads (id, road_code, area_id, name) VALUES ('c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'ROAD-000050', 'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'Green Lane 10') ON CONFLICT (area_id, name) DO NOTHING;

-- 6. Insert Sub-Roads
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3277938c-ab09-58dc-a776-dcd04f226bee'::uuid, 'SUBROAD-000001', '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('82b66d11-7e48-56fe-a843-533fd6f3bc3b'::uuid, 'SUBROAD-000002', '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6b373846-5318-5145-94ca-52f3e00901b2'::uuid, 'SUBROAD-000003', '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('719703c2-54d8-5e9f-ac25-70d8b0dd52d8'::uuid, 'SUBROAD-000004', '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b23a8449-94d7-533c-a9ff-db38690ef0e6'::uuid, 'SUBROAD-000005', '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid, 'SUBROAD-000006', '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6a291000-cc07-5689-a277-c157c00ec43d'::uuid, 'SUBROAD-000007', '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1e431754-d901-56d8-8a82-019a602486b2'::uuid, 'SUBROAD-000008', '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('819e1033-f045-53d7-8f3b-1b903a7a7790'::uuid, 'SUBROAD-000009', '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('43ba9670-63ca-51ec-8fe5-28652c7fed4c'::uuid, 'SUBROAD-000010', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('cc60cbad-c815-5aec-b04d-516a59dbaaa8'::uuid, 'SUBROAD-000011', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8e8f3985-a103-5c01-a6a9-384fffc652c7'::uuid, 'SUBROAD-000012', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('28684c0e-8063-5a2b-8bc2-54487d032466'::uuid, 'SUBROAD-000013', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8c289a24-920d-53e2-9932-7a2e85a151dc'::uuid, 'SUBROAD-000014', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f781b721-b98f-590b-8237-9cc25b4f605b'::uuid, 'SUBROAD-000015', '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('bd42f9be-4352-5909-8400-623c8ff7cae2'::uuid, 'SUBROAD-000016', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a82e6235-892d-5222-aae2-5d1691a4a5d9'::uuid, 'SUBROAD-000017', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('bafb7a5d-a2a3-5da5-b792-aa4288d731a6'::uuid, 'SUBROAD-000018', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('166f958c-0de3-522a-80d6-db586828c322'::uuid, 'SUBROAD-000019', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('89153a2b-db6b-5af5-a22b-18d32e2c2edb'::uuid, 'SUBROAD-000020', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d19bac53-8c22-5b7d-9f55-7363b36937ee'::uuid, 'SUBROAD-000021', 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a59eacea-4d0d-5072-b751-d24b06cde523'::uuid, 'SUBROAD-000022', '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('845f7a42-f9ed-5dc8-9918-fa7712029d7a'::uuid, 'SUBROAD-000023', '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('52c5e9cf-8422-5b7a-a17b-b95affe2cb06'::uuid, 'SUBROAD-000024', '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('17666bae-5a2a-5cd1-a03e-dd2adad4246a'::uuid, 'SUBROAD-000025', '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3ec14cf4-6163-5feb-9ce1-c1c3d40693e8'::uuid, 'SUBROAD-000026', '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid, 'SUBROAD-000027', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('685c6e8f-d5e0-57b1-afd0-fd89514cb6cf'::uuid, 'SUBROAD-000028', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('14a9cf03-d6f9-5775-a504-3e838444174a'::uuid, 'SUBROAD-000029', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7d6e5e0e-9d2f-5c14-b192-0016cdfe02b8'::uuid, 'SUBROAD-000030', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('536bb67c-9326-5363-8ec3-6a04e97f29e3'::uuid, 'SUBROAD-000031', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f65657f2-a930-54a1-ad3c-424e693caf0e'::uuid, 'SUBROAD-000032', '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5ce81b87-a8c3-58f9-bdc0-599b0a5640e9'::uuid, 'SUBROAD-000033', 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('29fa61e4-3b25-544a-8156-59e833a88b98'::uuid, 'SUBROAD-000034', 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ea581510-9fb3-5e90-a264-f72224f7e5f8'::uuid, 'SUBROAD-000035', 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4fdd2448-e521-5407-a290-c430c33c8dcb'::uuid, 'SUBROAD-000036', 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('90573fdb-a8a7-5c73-ac42-6070403b8d80'::uuid, 'SUBROAD-000037', 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0754cd11-5456-532a-b189-09b3b69fcbf7'::uuid, 'SUBROAD-000038', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1bc3fb04-40fd-5106-8713-4cf8e9bac075'::uuid, 'SUBROAD-000039', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ae3ffecd-1f46-5720-8aec-4c042cd901f4'::uuid, 'SUBROAD-000040', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('36785d50-31f5-5211-90f5-890befda43f1'::uuid, 'SUBROAD-000041', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6478a79d-7fab-562e-8b91-6689eafd24c5'::uuid, 'SUBROAD-000042', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('cc540375-cda8-537c-aeca-615982740fa1'::uuid, 'SUBROAD-000043', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0a3a397e-04d5-5995-ae82-fc1c03b78f49'::uuid, 'SUBROAD-000044', '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3cdbcc50-e439-54a5-ad5e-0e27f486baba'::uuid, 'SUBROAD-000045', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1d66aca5-2827-5562-a5f5-eb2521eb5336'::uuid, 'SUBROAD-000046', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('678f753e-bdd1-5893-bb17-e136955d33d0'::uuid, 'SUBROAD-000047', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3c6ce167-9a0d-53a1-8aa5-e7b853f0c104'::uuid, 'SUBROAD-000048', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2449301c-137b-5acb-bdd2-926b36b29ac5'::uuid, 'SUBROAD-000049', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1a699fa9-fa3f-5caf-a247-4007f5aab0bf'::uuid, 'SUBROAD-000050', '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('863c332f-b5b9-546b-85f8-b90a092f06a8'::uuid, 'SUBROAD-000051', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7a700e3e-322c-5e92-a525-931d66b7b8f6'::uuid, 'SUBROAD-000052', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3b19a2fa-de38-5cb3-8393-467cdcc59cf3'::uuid, 'SUBROAD-000053', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e131be8a-83ee-5013-a071-dca9c4798088'::uuid, 'SUBROAD-000054', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f392402a-18c2-5d17-b74f-376bbc06d7b8'::uuid, 'SUBROAD-000055', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9b2442e2-8198-5061-8d2d-0fc7480a9f96'::uuid, 'SUBROAD-000056', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9c32fc3f-4afe-5238-86bb-2ec8237e82ef'::uuid, 'SUBROAD-000057', '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('25eb8366-e6e8-5a7e-858e-5262488cbb9f'::uuid, 'SUBROAD-000058', '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ba3bc466-0a1d-5874-8ec4-ef4c5853c2f9'::uuid, 'SUBROAD-000059', '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('344d1a7b-af94-5acf-a3ce-3d01ea763a20'::uuid, 'SUBROAD-000060', '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a3728839-2e51-5b85-a6ef-7ff185fc1ad6'::uuid, 'SUBROAD-000061', '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('66184c50-54d5-59ef-b670-938ff017ae55'::uuid, 'SUBROAD-000062', '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7e56f822-9a46-54a6-8d3a-9a43cc99d20a'::uuid, 'SUBROAD-000063', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('525fd2b1-aef9-5b0b-bf45-e74c18a7a478'::uuid, 'SUBROAD-000064', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ef78a6c7-25f1-5993-90cc-d4226eea5539'::uuid, 'SUBROAD-000065', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e45cc303-2147-5d1a-b482-e3ca7a83fbe5'::uuid, 'SUBROAD-000066', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ce027fa0-838d-51f1-83df-c43e7b98d961'::uuid, 'SUBROAD-000067', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('57c8a56a-eeea-5f5c-9ba9-bc395ac5be9e'::uuid, 'SUBROAD-000068', '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid, 'SUBROAD-000069', 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('af3caaf0-9d10-52b5-bc20-5ba6d497a425'::uuid, 'SUBROAD-000070', 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ec86a6fc-b49a-511d-958b-4ffc3f57ce5a'::uuid, 'SUBROAD-000071', 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0be59f8d-4530-5e6c-87bb-2e7413e27642'::uuid, 'SUBROAD-000072', 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9c6a00c1-27e8-5850-b2bf-a36b36351a83'::uuid, 'SUBROAD-000073', 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1f68750b-c99e-5610-83f0-363ca48a087a'::uuid, 'SUBROAD-000074', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('75249b45-b839-5048-9f64-f29ee0fd9110'::uuid, 'SUBROAD-000075', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c1fd1119-f4bf-5dcd-a257-f9b253c01cf2'::uuid, 'SUBROAD-000076', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('95542163-045c-5f09-96d0-1580795fe0c5'::uuid, 'SUBROAD-000077', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5f0ec478-eb77-56ad-9c0e-566059447826'::uuid, 'SUBROAD-000078', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3f7ad402-15c1-50f8-9073-0ffc2e9f6b1c'::uuid, 'SUBROAD-000079', '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6a91c638-e58e-5057-b5db-9d4790596339'::uuid, 'SUBROAD-000080', '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7c60e3d6-819b-5bb4-9fbc-038c4494df83'::uuid, 'SUBROAD-000081', '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3a8e6ae0-d981-5496-90dc-984bd35e77a8'::uuid, 'SUBROAD-000082', '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1efcba63-c8a1-509b-bb34-3e3a58f0e9be'::uuid, 'SUBROAD-000083', '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1dea2a85-5ca4-5faf-a0ac-a316cc31184a'::uuid, 'SUBROAD-000084', '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f40d967e-c4ba-56bb-8feb-28e81cebb72b'::uuid, 'SUBROAD-000085', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e03f4081-47e2-5140-bdd3-87a440664aca'::uuid, 'SUBROAD-000086', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d788b40e-b298-5d09-9fe4-72b2565bc9a3'::uuid, 'SUBROAD-000087', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a576a1ba-6601-5d52-860c-f1bb878ffe8c'::uuid, 'SUBROAD-000088', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e86b0c12-42f6-51f4-9984-63132e0fa3aa'::uuid, 'SUBROAD-000089', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2887c767-5cfb-5813-bd0e-2c01e9f6259d'::uuid, 'SUBROAD-000090', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5bb8cfa2-7f4b-5dae-9ab4-dea3243cbc4a'::uuid, 'SUBROAD-000091', 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('90bb1b4a-2bab-5442-b83c-02c7ff1d674b'::uuid, 'SUBROAD-000092', '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('32d0eb60-88b2-5bd2-a3b7-f3dbab8295cf'::uuid, 'SUBROAD-000093', '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ce5c3d3f-1e9b-51b7-8353-0c7bd5db592e'::uuid, 'SUBROAD-000094', '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('31edd6db-8d15-5b62-81db-9c9421f65731'::uuid, 'SUBROAD-000095', '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f3b97dae-0199-5202-ac8c-67118d48aee8'::uuid, 'SUBROAD-000096', '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('dbd27461-e8a3-5f8a-b823-be5c16971f8d'::uuid, 'SUBROAD-000097', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('656bd47f-64d7-57e9-b747-9ee6cda95ec9'::uuid, 'SUBROAD-000098', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('dd176b88-64ca-5f60-8e11-4512491f0c95'::uuid, 'SUBROAD-000099', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('dd82701a-21a7-5cc1-b1c1-65986eb9a656'::uuid, 'SUBROAD-000100', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6e2f69df-7fb7-5f3b-8bd3-5374acb88452'::uuid, 'SUBROAD-000101', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('bf6ee8af-4094-5ef0-925f-d85253bf0ac3'::uuid, 'SUBROAD-000102', '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a7e36d0c-f67a-593f-b00d-4d6e32e1b3a1'::uuid, 'SUBROAD-000103', '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid, 'SUBROAD-000104', '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0f193e98-1383-5b6a-9836-b2dfc60a3e40'::uuid, 'SUBROAD-000105', '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e2a5a33c-5f05-54b9-baa1-c5b01aa890d2'::uuid, 'SUBROAD-000106', '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('33b376c8-6c8d-5086-8769-ca00a0458c72'::uuid, 'SUBROAD-000107', '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd'::uuid, 'SUBROAD-000108', '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('51ed8a57-6d6b-5199-bc39-830dccd63fb6'::uuid, 'SUBROAD-000109', '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('60acc646-7e20-5718-be9a-5a46a3a2bb77'::uuid, 'SUBROAD-000110', '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c60fb7ab-dd8d-5c31-a1aa-fb434eef6ff5'::uuid, 'SUBROAD-000111', '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2c39f865-b40a-57a9-adf8-fe05f128fec3'::uuid, 'SUBROAD-000112', '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('902f7c9f-1b2b-5745-8202-1ba42d2b5e4b'::uuid, 'SUBROAD-000113', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b2dae5f5-aab9-507a-ad05-bc3c2ff24b34'::uuid, 'SUBROAD-000114', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7e507346-e2a0-52db-91aa-780b1b799bff'::uuid, 'SUBROAD-000115', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3fad5aa3-3c52-5257-8199-334398712f4f'::uuid, 'SUBROAD-000116', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6f039085-20fd-55d6-b8b0-1212695b2eea'::uuid, 'SUBROAD-000117', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a96aaa19-7140-5e78-877e-ea747b12996e'::uuid, 'SUBROAD-000118', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('89b50c3e-b470-51b4-baab-28eb8d3d6c35'::uuid, 'SUBROAD-000119', 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7c9bfe22-663e-5ad6-994b-9bc2831de66e'::uuid, 'SUBROAD-000120', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('643c1ae6-ee79-586e-ad58-aaf327e678b5'::uuid, 'SUBROAD-000121', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b9df424e-61c6-50c5-8940-0c1a6bc27068'::uuid, 'SUBROAD-000122', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5cf1a001-1f17-5af1-9961-3efd7ecfa28d'::uuid, 'SUBROAD-000123', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('56f85075-aeab-5069-afbe-eeb4f9be100d'::uuid, 'SUBROAD-000124', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('980be9ec-5854-5053-b768-9ec3c181b376'::uuid, 'SUBROAD-000125', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('15201ef2-e936-5925-bb8a-ebbc62a1a398'::uuid, 'SUBROAD-000126', '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6ac8c80d-32fc-5696-af81-a556029ce605'::uuid, 'SUBROAD-000127', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3ab32271-6fa0-531b-83bf-6f6b829090e7'::uuid, 'SUBROAD-000128', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b3e34dac-e5fc-50a8-8c47-0cfe0648b408'::uuid, 'SUBROAD-000129', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('84369228-d22d-51a1-8b81-03a23ee28866'::uuid, 'SUBROAD-000130', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f835a007-d34f-586c-ba44-66ab03027863'::uuid, 'SUBROAD-000131', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('de12e01b-5c06-59bf-8665-ec3db544988f'::uuid, 'SUBROAD-000132', '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4f0063bd-53b4-5ed0-9d62-716410f46947'::uuid, 'SUBROAD-000133', '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a84df336-e632-559e-86c6-613fd4fc966a'::uuid, 'SUBROAD-000134', '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2fb4e837-8761-5903-b6a0-ff1fc6f1effa'::uuid, 'SUBROAD-000135', '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3a004e2a-02b3-59f4-bba1-bd5a37762b76'::uuid, 'SUBROAD-000136', '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('289e83c7-788e-5c67-9042-e251099033aa'::uuid, 'SUBROAD-000137', '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9739083c-9112-5bfb-9481-2b1260ee86dc'::uuid, 'SUBROAD-000138', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f0b8ae5a-dc42-5668-b275-279391af3fcc'::uuid, 'SUBROAD-000139', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a686f8c6-e2ff-5732-971a-582575fd9414'::uuid, 'SUBROAD-000140', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a0621bda-9c7f-5920-b617-b50274615f0c'::uuid, 'SUBROAD-000141', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('45a5ed93-765d-5cfd-b5a4-7131b4353002'::uuid, 'SUBROAD-000142', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0b0a4ea4-9337-5cc4-9bf0-c44094e99b8e'::uuid, 'SUBROAD-000143', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e89e9186-3ff3-5e2d-9ed7-43a8e9d8bb24'::uuid, 'SUBROAD-000144', '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6af17ffb-a486-5383-8f57-aa32d173ca5e'::uuid, 'SUBROAD-000145', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3882b257-5e34-5eba-a709-bfefc8bdf96d'::uuid, 'SUBROAD-000146', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d6a9e642-2a96-50ef-ae9f-1b8ecd4eb43e'::uuid, 'SUBROAD-000147', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('eb66495a-ebc2-5167-84be-aa1b24ae5131'::uuid, 'SUBROAD-000148', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e7606618-c542-510d-b5a3-c2e8a9d71be9'::uuid, 'SUBROAD-000149', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('21c859fd-0e10-55e8-8aae-85d38c977642'::uuid, 'SUBROAD-000150', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7ece6e2f-a68d-57e1-9f3c-c6fdd846911b'::uuid, 'SUBROAD-000151', '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('be8130f3-6e70-5e3b-afa5-ef07287e2547'::uuid, 'SUBROAD-000152', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a2a8b568-358d-58f8-aeda-ee5328eab142'::uuid, 'SUBROAD-000153', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c4508b9f-8b87-52f1-97c9-b5b0efc05466'::uuid, 'SUBROAD-000154', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0e5eadf0-ced1-52ac-9fc7-677646d9d49e'::uuid, 'SUBROAD-000155', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('db42c96e-1817-54ca-a012-004e49e22585'::uuid, 'SUBROAD-000156', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e5eacebd-0b18-5084-a45d-8d353b250f1f'::uuid, 'SUBROAD-000157', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b5d0b86b-3c95-53a3-a448-5c3847b15d6c'::uuid, 'SUBROAD-000158', '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('af4d9cde-1415-5155-b02c-fbbe869b00f9'::uuid, 'SUBROAD-000159', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('48c471cc-1d7b-541b-8d4f-6f3b5421ef9f'::uuid, 'SUBROAD-000160', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('418d8a92-9a98-5079-b89a-58455c6fc57c'::uuid, 'SUBROAD-000161', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('152cd6f0-af72-59c5-b0d7-b225c30d21a0'::uuid, 'SUBROAD-000162', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e0627714-cd73-5317-a629-8ebf2f20eca9'::uuid, 'SUBROAD-000163', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6bdd78b5-19a3-5f9e-8f43-92a091f419b7'::uuid, 'SUBROAD-000164', '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8b0d4127-f7f1-5657-97ef-1dce0f0007af'::uuid, 'SUBROAD-000165', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3c7f9bc5-6195-5b91-a0ee-5e692b105d76'::uuid, 'SUBROAD-000166', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8eb773d8-8ab2-509b-addb-34301e7f328e'::uuid, 'SUBROAD-000167', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3bd10c6c-d27b-57d5-a3e1-6775979060d8'::uuid, 'SUBROAD-000168', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4ebc7efd-ddbe-570b-a38b-e0fa25e3b514'::uuid, 'SUBROAD-000169', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b42dbc29-9997-5846-9a20-985f8ef14f9b'::uuid, 'SUBROAD-000170', '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ba7c5155-f69c-5c81-842c-bea415d6bb00'::uuid, 'SUBROAD-000171', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9d04c833-f01f-534f-a7c2-ec3370118a69'::uuid, 'SUBROAD-000172', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('eb2dee1a-bf63-5fe1-803b-c54eed0bd885'::uuid, 'SUBROAD-000173', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2145e6c2-4cb9-543f-8a27-bd9ac46f0235'::uuid, 'SUBROAD-000174', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c34b975b-567f-593b-a5bc-290f5d92096c'::uuid, 'SUBROAD-000175', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('cd18adf5-f7be-59be-91db-5619ebf3c691'::uuid, 'SUBROAD-000176', '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c8e94d9e-a42d-5f17-a526-2ad6ae53203a'::uuid, 'SUBROAD-000177', '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2d4d5764-87f4-554e-969a-8e1b3ca11531'::uuid, 'SUBROAD-000178', '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('34099f71-c2ab-5e2d-9742-8d14a4d42b67'::uuid, 'SUBROAD-000179', '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('95c4d76a-b2c2-5dd9-837a-973f92f7fc7e'::uuid, 'SUBROAD-000180', '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('274aa88c-8bca-5d9c-b29b-cdf4ce3fe6bb'::uuid, 'SUBROAD-000181', '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('31d1e228-2aec-5912-845a-1062c6060e11'::uuid, 'SUBROAD-000182', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4f4544ee-100b-52b2-96a2-5b20cd6761fe'::uuid, 'SUBROAD-000183', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6200b5ae-e6e8-5a4a-a316-d4a1e220a6e7'::uuid, 'SUBROAD-000184', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('38cd675a-c9bb-503d-b7d7-dfab64e4a2f1'::uuid, 'SUBROAD-000185', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b94e52d1-e671-55c7-8c76-4f20d1dbced0'::uuid, 'SUBROAD-000186', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('03512892-9b6f-59df-9da0-d5a39628cd3d'::uuid, 'SUBROAD-000187', 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a8b0348b-df13-5f1c-93b1-6e589449f99f'::uuid, 'SUBROAD-000188', '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1fa44a68-cdd4-5658-aa21-fdef4e2838f4'::uuid, 'SUBROAD-000189', '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('60aaf9e0-9f9a-50ec-a9aa-828726651a24'::uuid, 'SUBROAD-000190', '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e6c9a1e6-6490-5e18-8bd1-b43e64bf9e98'::uuid, 'SUBROAD-000191', '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e6ec2ee9-b487-5e2d-a1d9-9bf2535ba0c9'::uuid, 'SUBROAD-000192', '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6b782fb6-23ff-5edb-818b-de105d090acf'::uuid, 'SUBROAD-000193', '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3e046e0d-4eb2-5c30-9a63-7f042484b32c'::uuid, 'SUBROAD-000194', '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('baf26981-9006-5be9-9ce9-0d1dac042d53'::uuid, 'SUBROAD-000195', '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4253205f-83bf-5f55-9642-79ff32804cfb'::uuid, 'SUBROAD-000196', '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0ed8f6ff-f706-5a73-ad13-d146a60b6ff9'::uuid, 'SUBROAD-000197', '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3eb39a5b-5135-515a-b6fe-6d5612978e79'::uuid, 'SUBROAD-000198', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('fb8f4d14-6148-5f02-8e42-e655f1878a82'::uuid, 'SUBROAD-000199', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('87ad9267-8d06-5dd4-b2aa-62d5b94ecde9'::uuid, 'SUBROAD-000200', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('de0edabf-ed43-5106-bb31-1ca055938213'::uuid, 'SUBROAD-000201', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('073e5bf4-ebbb-5fd5-a090-646987c6aa36'::uuid, 'SUBROAD-000202', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('36adc9d8-1e67-5f8a-8882-dc0a1c0b70d6'::uuid, 'SUBROAD-000203', 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('29534439-db5f-55cc-a6ab-2a7c355efb5f'::uuid, 'SUBROAD-000204', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('74c5954b-1de0-5dda-a891-1710e377da5c'::uuid, 'SUBROAD-000205', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('cf64d3f2-e857-5ac5-a22a-8c3cd5613f95'::uuid, 'SUBROAD-000206', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('bf1480b8-6b17-5a96-9ab5-0eddf4b4704b'::uuid, 'SUBROAD-000207', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('618b85a8-38e5-5188-aeed-5a7e44db5f15'::uuid, 'SUBROAD-000208', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5046aad7-bbdd-576d-9c34-dd69b7257adf'::uuid, 'SUBROAD-000209', '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('96288f00-00e2-5377-90cc-b55c3e980a3d'::uuid, 'SUBROAD-000210', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5eaea5ca-310f-5ddd-9d20-c38d65fdd818'::uuid, 'SUBROAD-000211', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('59660098-8ee7-526c-8954-f452b1151e3a'::uuid, 'SUBROAD-000212', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('fb3b28bb-ffd2-5af6-b4b4-0ddebce432f8'::uuid, 'SUBROAD-000213', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('74ba855b-bccf-53f8-ba87-72425480d292'::uuid, 'SUBROAD-000214', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('38deba4a-5240-56c3-9653-a77cd9e4c66c'::uuid, 'SUBROAD-000215', '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ed8cec98-fb3d-5b80-a2dc-f8f6ca2c9791'::uuid, 'SUBROAD-000216', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('09956a33-e1c6-5d96-b6b4-7247453355f2'::uuid, 'SUBROAD-000217', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d2575613-8628-5e12-a432-fb925b23daba'::uuid, 'SUBROAD-000218', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('94b91c5c-f498-526f-b9f5-293d87d9f4d0'::uuid, 'SUBROAD-000219', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('11ff76c6-351d-5105-a26f-a0090c823235'::uuid, 'SUBROAD-000220', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('41852b80-0e5f-551f-9d7d-29742d1aab6d'::uuid, 'SUBROAD-000221', '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a0a1c6f3-c1c1-56ca-b087-eea0669cdbab'::uuid, 'SUBROAD-000222', '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid, 'SUBROAD-000223', '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c9c767a1-b892-5dc6-a3cd-3ff723433409'::uuid, 'SUBROAD-000224', '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c1b9f9e5-0a00-5ac4-a0af-ba6bbf41900d'::uuid, 'SUBROAD-000225', '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c112dc8a-9703-5f0b-b1b6-b3653aeb91af'::uuid, 'SUBROAD-000226', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('38c5695b-9636-583e-8f36-3387434430c8'::uuid, 'SUBROAD-000227', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('56bc8d5c-f97c-5022-8969-fdcdd3f8706a'::uuid, 'SUBROAD-000228', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f486b2f7-8ba5-5b6f-8730-c0b39999e0c1'::uuid, 'SUBROAD-000229', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4fdc13b1-cf67-5c7e-a73a-2121a1e24d80'::uuid, 'SUBROAD-000230', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('012e8356-2f7f-556d-9efb-0c4abe416d35'::uuid, 'SUBROAD-000231', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f3dd618f-878d-5449-b0de-7cc96e9d427b'::uuid, 'SUBROAD-000232', '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('a66957b7-5433-57f5-ad15-2838c088315f'::uuid, 'SUBROAD-000233', '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e181c86f-d8c5-5c49-8627-82fa07c857ec'::uuid, 'SUBROAD-000234', '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b67d8daa-156b-52ac-a618-2e2451509142'::uuid, 'SUBROAD-000235', '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d48b8e11-c0f2-5404-95f0-d5d7459c4323'::uuid, 'SUBROAD-000236', '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('418f3f4d-0d20-50f9-8b53-6a52e8230316'::uuid, 'SUBROAD-000237', '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8d47e0e9-edec-5748-ab50-7ca414907808'::uuid, 'SUBROAD-000238', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d9cb2203-1ccb-5f56-83d4-1f71db714e90'::uuid, 'SUBROAD-000239', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('8e6d9cd1-2434-510f-82f0-6a9fcc3a3519'::uuid, 'SUBROAD-000240', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9cba1288-0235-54c4-ad60-1ab83e429bab'::uuid, 'SUBROAD-000241', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7939e55b-be68-5e93-b28d-d83d681ca639'::uuid, 'SUBROAD-000242', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('64d77408-59ad-5484-a6e9-05792232abd6'::uuid, 'SUBROAD-000243', '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f7b7f811-ffde-510a-b2da-150f3f7e64ec'::uuid, 'SUBROAD-000244', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2b08aa54-9e60-5712-b543-dfcf25004e56'::uuid, 'SUBROAD-000245', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('298d73bb-3adc-53c7-8d4f-7231fb02c803'::uuid, 'SUBROAD-000246', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('767f3099-d50c-5fa7-b863-c4f780aa6348'::uuid, 'SUBROAD-000247', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('322e0a98-0765-5483-a011-1dde9e7f7ab2'::uuid, 'SUBROAD-000248', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('98b3165f-0032-5872-b528-d517c81cc0d7'::uuid, 'SUBROAD-000249', 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('845954dc-4d95-55f9-bed1-3262a6e623ba'::uuid, 'SUBROAD-000250', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6940fc5d-6582-500c-be09-f624b23f6615'::uuid, 'SUBROAD-000251', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('035734b6-855d-5bba-91d3-06b851c0ae25'::uuid, 'SUBROAD-000252', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('c520b532-05a5-5a46-81f4-e9f51cb0ff5b'::uuid, 'SUBROAD-000253', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4b3817c7-6211-5e6d-9461-9899e293d723'::uuid, 'SUBROAD-000254', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5f712bbc-b0c8-500b-a2d5-96f319c0f6b9'::uuid, 'SUBROAD-000255', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('aeadde06-48c4-5cdb-88ba-c843f5722320'::uuid, 'SUBROAD-000256', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('d3743f56-9259-5524-b8a2-8531af509ab8'::uuid, 'SUBROAD-000257', 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5a8e923f-eb15-513b-b28e-e87b55ad4a78'::uuid, 'SUBROAD-000258', 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f43f4b50-2237-528b-81a2-6d34c671ebd5'::uuid, 'SUBROAD-000259', 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('83d465fd-b961-5e9c-be5a-6cc8bd2dfe96'::uuid, 'SUBROAD-000260', 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('4eef933a-088f-57fe-952a-3c86864b3301'::uuid, 'SUBROAD-000261', 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('be7f15e9-5e1d-5d85-a10e-d7e52ab430c0'::uuid, 'SUBROAD-000262', 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9e61ed5a-b893-5bfe-b6c8-aebb11e0ea5e'::uuid, 'SUBROAD-000263', 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('0b10bf49-6867-5ab8-8124-8a8706e31f37'::uuid, 'SUBROAD-000264', 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('03750ca1-20ac-5e9c-bb36-974ddab1f608'::uuid, 'SUBROAD-000265', 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('3171804c-9c66-5583-8fed-fe5af9592c18'::uuid, 'SUBROAD-000266', 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('fc60eb08-c2c5-54a7-9778-9cb811a91b6f'::uuid, 'SUBROAD-000267', 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e1f6720c-7abc-54b2-9d3c-242154ba1f70'::uuid, 'SUBROAD-000268', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('40285b98-b4d3-5c32-b26c-1ba3e2ef55f7'::uuid, 'SUBROAD-000269', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('b87171f4-eef5-58c7-8a15-0ff770444d85'::uuid, 'SUBROAD-000270', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6d6396cb-a8a3-5f4c-950a-28bcae06710a'::uuid, 'SUBROAD-000271', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('81701a3f-836e-5a07-a8ff-3dd33bafb195'::uuid, 'SUBROAD-000272', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('7e20fdae-c4ff-5355-b4a5-1aedbcd1a99f'::uuid, 'SUBROAD-000273', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f330fc21-298e-575d-a073-a1747175eaca'::uuid, 'SUBROAD-000274', '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e7a47294-607a-5bae-820c-163c79d52831'::uuid, 'SUBROAD-000275', 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('9cb96b62-f2fa-52fd-b9ec-fa580300075e'::uuid, 'SUBROAD-000276', 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('dda835d0-097b-575f-9d12-bf4aeeac5795'::uuid, 'SUBROAD-000277', 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('23cffbca-c5d1-5748-a30c-aa4bc1349af8'::uuid, 'SUBROAD-000278', 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('ca1253cc-f4f2-5272-a093-c050ca3b663f'::uuid, 'SUBROAD-000279', 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('e2c50f2d-4fb8-5d46-9641-c1a0c1b57700'::uuid, 'SUBROAD-000280', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('5502a197-691b-56f7-8d69-804f9a6a30e9'::uuid, 'SUBROAD-000281', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6eb78452-ce88-57a6-a0c3-d3f32923a817'::uuid, 'SUBROAD-000282', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('cc0350d0-191a-57d5-88e7-4985eadd2acc'::uuid, 'SUBROAD-000283', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('15c7e698-86d7-5670-9399-000432987b4d'::uuid, 'SUBROAD-000284', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 8') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('04322682-343c-57ef-b738-6a434245b392'::uuid, 'SUBROAD-000285', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('1069b58f-6e4d-5b81-ad0d-9c0ae5b92e5a'::uuid, 'SUBROAD-000286', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 5') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('741cd65e-3309-58e2-86fe-c0a2b16ab43e'::uuid, 'SUBROAD-000287', 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('911546fc-0ee4-583d-9bc6-79b74384be7f'::uuid, 'SUBROAD-000288', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 4') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('50c35e47-9045-5701-acbc-28f6e2099e75'::uuid, 'SUBROAD-000289', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 1') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('6d26ba4c-096d-5b2b-b54d-0dc5776be700'::uuid, 'SUBROAD-000290', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 2') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('f7c04f62-1e4e-5655-9823-466ce9c99136'::uuid, 'SUBROAD-000291', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 3') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('62ab0aa8-28cd-5410-88d2-db78ae975c19'::uuid, 'SUBROAD-000292', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 7') ON CONFLICT (road_id, name) DO NOTHING;
INSERT INTO public.sub_roads (id, subroad_code, road_id, name) VALUES ('2031493b-05fb-51fc-9e7f-5cd4e8f02e3a'::uuid, 'SUBROAD-000293', 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'Block 6') ON CONFLICT (road_id, name) DO NOTHING;

-- 7. Insert Customers (Auth Users & Customer Profiles)
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8a5864e9-bc1c-5242-a48c-557fa54387cf'::uuid, 'authenticated', 'authenticated',
  'customer-000001@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Reddy", "phone": "9826088008", "address": "#186, Block 6, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "3277938c-ab09-58dc-a776-dcd04f226bee"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8a5864e9-bc1c-5242-a48c-557fa54387cf'::uuid, 'Sneha Reddy', 'cust-1', 'customer-000001@aplibhaji.com', '#186, Block 6, Market Road 1, North Zone Sector 1', 'CUSTOMER-000001',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '3277938c-ab09-58dc-a776-dcd04f226bee'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '66f94078-f707-540f-955c-5496c80b78ca'::uuid, 'authenticated', 'authenticated',
  'customer-000002@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Chawla", "phone": "9865151487", "address": "#320, Block 4, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "82b66d11-7e48-56fe-a843-533fd6f3bc3b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '66f94078-f707-540f-955c-5496c80b78ca'::uuid, 'Anita Chawla', 'cust-2', 'customer-000002@aplibhaji.com', '#320, Block 4, Market Road 1, North Zone Sector 1', 'CUSTOMER-000002',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '82b66d11-7e48-56fe-a843-533fd6f3bc3b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8c8d17f3-f1b1-5240-8aa3-87030012f095'::uuid, 'authenticated', 'authenticated',
  'customer-000003@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Reddy", "phone": "9833094583", "address": "#271, Block 8, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "6b373846-5318-5145-94ca-52f3e00901b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8c8d17f3-f1b1-5240-8aa3-87030012f095'::uuid, 'Amit Reddy', 'cust-3', 'customer-000003@aplibhaji.com', '#271, Block 8, Market Road 1, North Zone Sector 1', 'CUSTOMER-000003',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '6b373846-5318-5145-94ca-52f3e00901b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'bf5c6acd-284f-5f43-940c-671de2da41c3'::uuid, 'authenticated', 'authenticated',
  'customer-000004@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Sharma", "phone": "9896072701", "address": "#341, Block 5, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "719703c2-54d8-5e9f-ac25-70d8b0dd52d8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'bf5c6acd-284f-5f43-940c-671de2da41c3'::uuid, 'Ramesh Sharma', 'cust-4', 'customer-000004@aplibhaji.com', '#341, Block 5, Market Road 1, North Zone Sector 1', 'CUSTOMER-000004',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '719703c2-54d8-5e9f-ac25-70d8b0dd52d8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4c36c5d8-4d35-560a-82e1-35d3765466cc'::uuid, 'authenticated', 'authenticated',
  'customer-000005@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Mehta", "phone": "9864959286", "address": "#300, Block 4, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "82b66d11-7e48-56fe-a843-533fd6f3bc3b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4c36c5d8-4d35-560a-82e1-35d3765466cc'::uuid, 'Geeta Mehta', 'cust-5', 'customer-000005@aplibhaji.com', '#300, Block 4, Market Road 1, North Zone Sector 1', 'CUSTOMER-000005',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '82b66d11-7e48-56fe-a843-533fd6f3bc3b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8cc00001-7e41-52a2-84ca-b69773248456'::uuid, 'authenticated', 'authenticated',
  'customer-000006@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Jain", "phone": "9836300418", "address": "#240, Block 8, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "6b373846-5318-5145-94ca-52f3e00901b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8cc00001-7e41-52a2-84ca-b69773248456'::uuid, 'Suresh Jain', 'cust-6', 'customer-000006@aplibhaji.com', '#240, Block 8, Market Road 1, North Zone Sector 1', 'CUSTOMER-000006',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '6b373846-5318-5145-94ca-52f3e00901b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5628cab2-2ce0-5cc9-b8b3-ce45201b5567'::uuid, 'authenticated', 'authenticated',
  'customer-000007@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Kulkarni", "phone": "9817894211", "address": "#214, Block 8, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "6b373846-5318-5145-94ca-52f3e00901b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5628cab2-2ce0-5cc9-b8b3-ce45201b5567'::uuid, 'Neha Kulkarni', 'cust-7', 'customer-000007@aplibhaji.com', '#214, Block 8, Market Road 1, North Zone Sector 1', 'CUSTOMER-000007',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '6b373846-5318-5145-94ca-52f3e00901b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b7cf987b-164f-56d9-b650-b6fd97ece966'::uuid, 'authenticated', 'authenticated',
  'customer-000008@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Joshi", "phone": "9819015744", "address": "#158, Block 7, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "b23a8449-94d7-533c-a9ff-db38690ef0e6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b7cf987b-164f-56d9-b650-b6fd97ece966'::uuid, 'Vijay Joshi', 'cust-8', 'customer-000008@aplibhaji.com', '#158, Block 7, Market Road 1, North Zone Sector 1', 'CUSTOMER-000008',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'b23a8449-94d7-533c-a9ff-db38690ef0e6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '41312510-9a9d-59c3-8122-097d7d2aa34f'::uuid, 'authenticated', 'authenticated',
  'customer-000009@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Agarwal", "phone": "9813274555", "address": "#229, Block 8, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "6b373846-5318-5145-94ca-52f3e00901b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '41312510-9a9d-59c3-8122-097d7d2aa34f'::uuid, 'Amit Agarwal', 'cust-9', 'customer-000009@aplibhaji.com', '#229, Block 8, Market Road 1, North Zone Sector 1', 'CUSTOMER-000009',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, '6b373846-5318-5145-94ca-52f3e00901b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd1b2730b-fa0c-53d2-8407-5147ec2312f7'::uuid, 'authenticated', 'authenticated',
  'customer-000010@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Patel", "phone": "9872871278", "address": "#382, Block 7, Market Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "8d1494b3-140f-572e-bae8-ad766b961a76", "sub_road_id": "b23a8449-94d7-533c-a9ff-db38690ef0e6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd1b2730b-fa0c-53d2-8407-5147ec2312f7'::uuid, 'Arun Patel', 'cust-10', 'customer-000010@aplibhaji.com', '#382, Block 7, Market Road 1, North Zone Sector 1', 'CUSTOMER-000010',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '8d1494b3-140f-572e-bae8-ad766b961a76'::uuid, 'b23a8449-94d7-533c-a9ff-db38690ef0e6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b9e93584-8ed1-5246-b6c4-404aadc3382d'::uuid, 'authenticated', 'authenticated',
  'customer-000011@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Chawla", "phone": "9857754827", "address": "#342, Block 1, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6d6bcd77-0c92-50ae-9fea-e04f112a46c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b9e93584-8ed1-5246-b6c4-404aadc3382d'::uuid, 'Kavita Chawla', 'cust-11', 'customer-000011@aplibhaji.com', '#342, Block 1, MG Road 1, North Zone Sector 1', 'CUSTOMER-000011',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0b56a001-95ec-532d-8ef6-e4af761247c2'::uuid, 'authenticated', 'authenticated',
  'customer-000012@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Reddy", "phone": "9846151192", "address": "#295, Block 1, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6d6bcd77-0c92-50ae-9fea-e04f112a46c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0b56a001-95ec-532d-8ef6-e4af761247c2'::uuid, 'Ramesh Reddy', 'cust-12', 'customer-000012@aplibhaji.com', '#295, Block 1, MG Road 1, North Zone Sector 1', 'CUSTOMER-000012',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '487aa1ec-6ce0-5623-8bb2-5cbe1b71cd29'::uuid, 'authenticated', 'authenticated',
  'customer-000013@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Joshi", "phone": "9824035902", "address": "#318, Block 2, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6a291000-cc07-5689-a277-c157c00ec43d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '487aa1ec-6ce0-5623-8bb2-5cbe1b71cd29'::uuid, 'Vikram Joshi', 'cust-13', 'customer-000013@aplibhaji.com', '#318, Block 2, MG Road 1, North Zone Sector 1', 'CUSTOMER-000013',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6a291000-cc07-5689-a277-c157c00ec43d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd00ad241-822d-536d-9b46-f020caa8bd38'::uuid, 'authenticated', 'authenticated',
  'customer-000014@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Singh", "phone": "9870212081", "address": "#377, Block 1, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6d6bcd77-0c92-50ae-9fea-e04f112a46c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd00ad241-822d-536d-9b46-f020caa8bd38'::uuid, 'Rohan Singh', 'cust-14', 'customer-000014@aplibhaji.com', '#377, Block 1, MG Road 1, North Zone Sector 1', 'CUSTOMER-000014',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8911cfcf-91cd-5f3a-893e-f9f834673e37'::uuid, 'authenticated', 'authenticated',
  'customer-000015@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Deshmukh", "phone": "9854074082", "address": "#242, Block 6, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "1e431754-d901-56d8-8a82-019a602486b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8911cfcf-91cd-5f3a-893e-f9f834673e37'::uuid, 'Rohan Deshmukh', 'cust-15', 'customer-000015@aplibhaji.com', '#242, Block 6, MG Road 1, North Zone Sector 1', 'CUSTOMER-000015',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '1e431754-d901-56d8-8a82-019a602486b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5c82106c-9a5d-541e-8024-7fe7124d4beb'::uuid, 'authenticated', 'authenticated',
  'customer-000016@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Rao", "phone": "9838110587", "address": "#221, Block 1, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6d6bcd77-0c92-50ae-9fea-e04f112a46c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5c82106c-9a5d-541e-8024-7fe7124d4beb'::uuid, 'Deepak Rao', 'cust-16', 'customer-000016@aplibhaji.com', '#221, Block 1, MG Road 1, North Zone Sector 1', 'CUSTOMER-000016',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4c33f5b4-2223-5d56-aee6-37d1df26be1c'::uuid, 'authenticated', 'authenticated',
  'customer-000017@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Gupta", "phone": "9866023341", "address": "#379, Block 5, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "819e1033-f045-53d7-8f3b-1b903a7a7790"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4c33f5b4-2223-5d56-aee6-37d1df26be1c'::uuid, 'Arun Gupta', 'cust-17', 'customer-000017@aplibhaji.com', '#379, Block 5, MG Road 1, North Zone Sector 1', 'CUSTOMER-000017',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '819e1033-f045-53d7-8f3b-1b903a7a7790'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8f860b84-2162-577e-9f8b-ae4287594101'::uuid, 'authenticated', 'authenticated',
  'customer-000018@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Reddy", "phone": "9854058068", "address": "#114, Block 5, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "819e1033-f045-53d7-8f3b-1b903a7a7790"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8f860b84-2162-577e-9f8b-ae4287594101'::uuid, 'Manish Reddy', 'cust-18', 'customer-000018@aplibhaji.com', '#114, Block 5, MG Road 1, North Zone Sector 1', 'CUSTOMER-000018',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '819e1033-f045-53d7-8f3b-1b903a7a7790'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '29bee4b4-56a0-54ed-9bdd-9e727d9d59ad'::uuid, 'authenticated', 'authenticated',
  'customer-000019@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Patel", "phone": "9812672999", "address": "#323, Block 1, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "6d6bcd77-0c92-50ae-9fea-e04f112a46c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '29bee4b4-56a0-54ed-9bdd-9e727d9d59ad'::uuid, 'Sanjay Patel', 'cust-19', 'customer-000019@aplibhaji.com', '#323, Block 1, MG Road 1, North Zone Sector 1', 'CUSTOMER-000019',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '6d6bcd77-0c92-50ae-9fea-e04f112a46c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '095d205a-6c9e-54bf-8b60-07ccedab7c3e'::uuid, 'authenticated', 'authenticated',
  'customer-000020@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Kumar", "phone": "9872295848", "address": "#130, Block 6, MG Road 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "12b44830-bc47-5f45-b8d9-aa18885a54b0", "sub_road_id": "1e431754-d901-56d8-8a82-019a602486b2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '095d205a-6c9e-54bf-8b60-07ccedab7c3e'::uuid, 'Ananya Kumar', 'cust-20', 'customer-000020@aplibhaji.com', '#130, Block 6, MG Road 1, North Zone Sector 1', 'CUSTOMER-000020',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '12b44830-bc47-5f45-b8d9-aa18885a54b0'::uuid, '1e431754-d901-56d8-8a82-019a602486b2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c72e95e1-c127-5566-9fa2-1cadbe4e8c0f'::uuid, 'authenticated', 'authenticated',
  'customer-000021@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Kumar", "phone": "9810973700", "address": "#199, Block 5, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "43ba9670-63ca-51ec-8fe5-28652c7fed4c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c72e95e1-c127-5566-9fa2-1cadbe4e8c0f'::uuid, 'Sunita Kumar', 'cust-21', 'customer-000021@aplibhaji.com', '#199, Block 5, Station Street 1, North Zone Sector 1', 'CUSTOMER-000021',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '43ba9670-63ca-51ec-8fe5-28652c7fed4c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd2101947-ce3b-56a3-a495-c6c283497e81'::uuid, 'authenticated', 'authenticated',
  'customer-000022@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Jain", "phone": "9865925935", "address": "#232, Block 5, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "43ba9670-63ca-51ec-8fe5-28652c7fed4c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd2101947-ce3b-56a3-a495-c6c283497e81'::uuid, 'Sneha Jain', 'cust-22', 'customer-000022@aplibhaji.com', '#232, Block 5, Station Street 1, North Zone Sector 1', 'CUSTOMER-000022',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '43ba9670-63ca-51ec-8fe5-28652c7fed4c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2e4006b0-b19c-531a-8e1f-4639b7a6d586'::uuid, 'authenticated', 'authenticated',
  'customer-000023@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Kulkarni", "phone": "9826046777", "address": "#119, Block 3, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "cc60cbad-c815-5aec-b04d-516a59dbaaa8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2e4006b0-b19c-531a-8e1f-4639b7a6d586'::uuid, 'Ajay Kulkarni', 'cust-23', 'customer-000023@aplibhaji.com', '#119, Block 3, Station Street 1, North Zone Sector 1', 'CUSTOMER-000023',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'cc60cbad-c815-5aec-b04d-516a59dbaaa8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2be16c22-9ee3-524d-81be-78723e85e739'::uuid, 'authenticated', 'authenticated',
  'customer-000024@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Agarwal", "phone": "9849027691", "address": "#334, Block 6, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "8e8f3985-a103-5c01-a6a9-384fffc652c7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2be16c22-9ee3-524d-81be-78723e85e739'::uuid, 'Kavita Agarwal', 'cust-24', 'customer-000024@aplibhaji.com', '#334, Block 6, Station Street 1, North Zone Sector 1', 'CUSTOMER-000024',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '8e8f3985-a103-5c01-a6a9-384fffc652c7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ddedcd65-ef2d-5dd5-bdc4-0f4fef3e1a05'::uuid, 'authenticated', 'authenticated',
  'customer-000025@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Gupta", "phone": "9811870101", "address": "#113, Block 2, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "28684c0e-8063-5a2b-8bc2-54487d032466"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ddedcd65-ef2d-5dd5-bdc4-0f4fef3e1a05'::uuid, 'Geeta Gupta', 'cust-25', 'customer-000025@aplibhaji.com', '#113, Block 2, Station Street 1, North Zone Sector 1', 'CUSTOMER-000025',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '28684c0e-8063-5a2b-8bc2-54487d032466'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '956448d4-5fd9-556a-b165-3c750b910bc5'::uuid, 'authenticated', 'authenticated',
  'customer-000026@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Jain", "phone": "9869123789", "address": "#160, Block 5, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "43ba9670-63ca-51ec-8fe5-28652c7fed4c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '956448d4-5fd9-556a-b165-3c750b910bc5'::uuid, 'Rajesh Jain', 'cust-26', 'customer-000026@aplibhaji.com', '#160, Block 5, Station Street 1, North Zone Sector 1', 'CUSTOMER-000026',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '43ba9670-63ca-51ec-8fe5-28652c7fed4c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '982ecf72-0791-5434-af53-5096442355f7'::uuid, 'authenticated', 'authenticated',
  'customer-000027@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Joshi", "phone": "9874446832", "address": "#192, Block 7, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "8c289a24-920d-53e2-9932-7a2e85a151dc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '982ecf72-0791-5434-af53-5096442355f7'::uuid, 'Neha Joshi', 'cust-27', 'customer-000027@aplibhaji.com', '#192, Block 7, Station Street 1, North Zone Sector 1', 'CUSTOMER-000027',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '8c289a24-920d-53e2-9932-7a2e85a151dc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a82e0554-96db-50a7-b40b-4271c655dee5'::uuid, 'authenticated', 'authenticated',
  'customer-000028@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Mehta", "phone": "9820064524", "address": "#114, Block 1, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "f781b721-b98f-590b-8237-9cc25b4f605b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a82e0554-96db-50a7-b40b-4271c655dee5'::uuid, 'Arun Mehta', 'cust-28', 'customer-000028@aplibhaji.com', '#114, Block 1, Station Street 1, North Zone Sector 1', 'CUSTOMER-000028',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, 'f781b721-b98f-590b-8237-9cc25b4f605b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9d2aa886-dd93-57f4-a216-fc491eb9fdbc'::uuid, 'authenticated', 'authenticated',
  'customer-000029@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Rao", "phone": "9862881980", "address": "#200, Block 7, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "8c289a24-920d-53e2-9932-7a2e85a151dc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9d2aa886-dd93-57f4-a216-fc491eb9fdbc'::uuid, 'Meena Rao', 'cust-29', 'customer-000029@aplibhaji.com', '#200, Block 7, Station Street 1, North Zone Sector 1', 'CUSTOMER-000029',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '8c289a24-920d-53e2-9932-7a2e85a151dc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '863e227f-4aad-59c7-95af-758f2b6fdb95'::uuid, 'authenticated', 'authenticated',
  'customer-000030@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Kumar", "phone": "9896076861", "address": "#181, Block 2, Station Street 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "3c6ebc49-df22-587b-9443-f91f61d3fefb", "sub_road_id": "28684c0e-8063-5a2b-8bc2-54487d032466"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '863e227f-4aad-59c7-95af-758f2b6fdb95'::uuid, 'Deepak Kumar', 'cust-30', 'customer-000030@aplibhaji.com', '#181, Block 2, Station Street 1, North Zone Sector 1', 'CUSTOMER-000030',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '3c6ebc49-df22-587b-9443-f91f61d3fefb'::uuid, '28684c0e-8063-5a2b-8bc2-54487d032466'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '75a42aff-2c74-586d-aade-1fce573497d3'::uuid, 'authenticated', 'authenticated',
  'customer-000031@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Gupta", "phone": "9810311821", "address": "#271, Block 1, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "bd42f9be-4352-5909-8400-623c8ff7cae2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '75a42aff-2c74-586d-aade-1fce573497d3'::uuid, 'Deepak Gupta', 'cust-31', 'customer-000031@aplibhaji.com', '#271, Block 1, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000031',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'bd42f9be-4352-5909-8400-623c8ff7cae2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6ef2d046-8f4d-5620-9ce0-93e5dcb359d8'::uuid, 'authenticated', 'authenticated',
  'customer-000032@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Sharma", "phone": "9826324867", "address": "#282, Block 1, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "bd42f9be-4352-5909-8400-623c8ff7cae2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6ef2d046-8f4d-5620-9ce0-93e5dcb359d8'::uuid, 'Vijay Sharma', 'cust-32', 'customer-000032@aplibhaji.com', '#282, Block 1, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000032',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'bd42f9be-4352-5909-8400-623c8ff7cae2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4653c712-ee71-5e8e-8fa4-3c2a341865f7'::uuid, 'authenticated', 'authenticated',
  'customer-000033@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Singh", "phone": "9831891600", "address": "#364, Block 6, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "a82e6235-892d-5222-aae2-5d1691a4a5d9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4653c712-ee71-5e8e-8fa4-3c2a341865f7'::uuid, 'Ananya Singh', 'cust-33', 'customer-000033@aplibhaji.com', '#364, Block 6, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000033',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'a82e6235-892d-5222-aae2-5d1691a4a5d9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fc50678d-e458-5ef6-b7a7-b0789f7ace65'::uuid, 'authenticated', 'authenticated',
  'customer-000034@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Singh", "phone": "9878416489", "address": "#145, Block 7, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "bafb7a5d-a2a3-5da5-b792-aa4288d731a6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fc50678d-e458-5ef6-b7a7-b0789f7ace65'::uuid, 'Sneha Singh', 'cust-34', 'customer-000034@aplibhaji.com', '#145, Block 7, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000034',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'bafb7a5d-a2a3-5da5-b792-aa4288d731a6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '61eb9540-7699-5bbc-bea2-0f17cf06a953'::uuid, 'authenticated', 'authenticated',
  'customer-000035@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Verma", "phone": "9839601597", "address": "#345, Block 2, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "166f958c-0de3-522a-80d6-db586828c322"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '61eb9540-7699-5bbc-bea2-0f17cf06a953'::uuid, 'Pooja Verma', 'cust-35', 'customer-000035@aplibhaji.com', '#345, Block 2, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000035',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, '166f958c-0de3-522a-80d6-db586828c322'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '74665374-c3f8-5b80-b83c-a5e47c249987'::uuid, 'authenticated', 'authenticated',
  'customer-000036@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Patel", "phone": "9826040884", "address": "#354, Block 3, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "89153a2b-db6b-5af5-a22b-18d32e2c2edb"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '74665374-c3f8-5b80-b83c-a5e47c249987'::uuid, 'Sunita Patel', 'cust-36', 'customer-000036@aplibhaji.com', '#354, Block 3, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000036',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, '89153a2b-db6b-5af5-a22b-18d32e2c2edb'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a67fef9b-56e2-57ed-a212-0270bd93c975'::uuid, 'authenticated', 'authenticated',
  'customer-000037@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Joshi", "phone": "9868629301", "address": "#119, Block 4, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "d19bac53-8c22-5b7d-9f55-7363b36937ee"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a67fef9b-56e2-57ed-a212-0270bd93c975'::uuid, 'Rajesh Joshi', 'cust-37', 'customer-000037@aplibhaji.com', '#119, Block 4, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000037',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'd19bac53-8c22-5b7d-9f55-7363b36937ee'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4b39eca6-d630-5c8e-970f-e2c99f201afa'::uuid, 'authenticated', 'authenticated',
  'customer-000038@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Kumar", "phone": "9838247462", "address": "#157, Block 6, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "a82e6235-892d-5222-aae2-5d1691a4a5d9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4b39eca6-d630-5c8e-970f-e2c99f201afa'::uuid, 'Priya Kumar', 'cust-38', 'customer-000038@aplibhaji.com', '#157, Block 6, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000038',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'a82e6235-892d-5222-aae2-5d1691a4a5d9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c59f687b-1ddd-5afb-b6f2-691c2afc0f59'::uuid, 'authenticated', 'authenticated',
  'customer-000039@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Gupta", "phone": "9884020157", "address": "#321, Block 7, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "bafb7a5d-a2a3-5da5-b792-aa4288d731a6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c59f687b-1ddd-5afb-b6f2-691c2afc0f59'::uuid, 'Arun Gupta', 'cust-39', 'customer-000039@aplibhaji.com', '#321, Block 7, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000039',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'bafb7a5d-a2a3-5da5-b792-aa4288d731a6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2a15a95d-7f5f-5e52-b78f-61e567ebcd7b'::uuid, 'authenticated', 'authenticated',
  'customer-000040@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Verma", "phone": "9897657533", "address": "#357, Block 6, Park Avenue 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "e513ef36-ea94-5d0e-aeeb-14a121029173", "sub_road_id": "a82e6235-892d-5222-aae2-5d1691a4a5d9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2a15a95d-7f5f-5e52-b78f-61e567ebcd7b'::uuid, 'Meena Verma', 'cust-40', 'customer-000040@aplibhaji.com', '#357, Block 6, Park Avenue 1, North Zone Sector 1', 'CUSTOMER-000040',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, 'e513ef36-ea94-5d0e-aeeb-14a121029173'::uuid, 'a82e6235-892d-5222-aae2-5d1691a4a5d9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '840ab454-d6b6-5508-9f9b-4e77f9b10016'::uuid, 'authenticated', 'authenticated',
  'customer-000041@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Agarwal", "phone": "9848766919", "address": "#253, Block 8, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "a59eacea-4d0d-5072-b751-d24b06cde523"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '840ab454-d6b6-5508-9f9b-4e77f9b10016'::uuid, 'Sneha Agarwal', 'cust-41', 'customer-000041@aplibhaji.com', '#253, Block 8, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000041',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'a59eacea-4d0d-5072-b751-d24b06cde523'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0917d684-0b6d-5dbb-893d-87a647c5fa8f'::uuid, 'authenticated', 'authenticated',
  'customer-000042@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Jain", "phone": "9895438747", "address": "#309, Block 7, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "845f7a42-f9ed-5dc8-9918-fa7712029d7a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0917d684-0b6d-5dbb-893d-87a647c5fa8f'::uuid, 'Meena Jain', 'cust-42', 'customer-000042@aplibhaji.com', '#309, Block 7, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000042',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '845f7a42-f9ed-5dc8-9918-fa7712029d7a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '27cea9df-6a91-5c84-a1a6-94484f4f3553'::uuid, 'authenticated', 'authenticated',
  'customer-000043@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Chawla", "phone": "9811563817", "address": "#188, Block 7, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "845f7a42-f9ed-5dc8-9918-fa7712029d7a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '27cea9df-6a91-5c84-a1a6-94484f4f3553'::uuid, 'Neha Chawla', 'cust-43', 'customer-000043@aplibhaji.com', '#188, Block 7, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000043',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '845f7a42-f9ed-5dc8-9918-fa7712029d7a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1589547f-856e-5ca6-8e9b-798c970d079e'::uuid, 'authenticated', 'authenticated',
  'customer-000044@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Sharma", "phone": "9879501561", "address": "#314, Block 8, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "a59eacea-4d0d-5072-b751-d24b06cde523"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1589547f-856e-5ca6-8e9b-798c970d079e'::uuid, 'Amit Sharma', 'cust-44', 'customer-000044@aplibhaji.com', '#314, Block 8, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000044',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'a59eacea-4d0d-5072-b751-d24b06cde523'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9990bdc7-f884-5bd5-9d3d-1602bf2e1b9e'::uuid, 'authenticated', 'authenticated',
  'customer-000045@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Gupta", "phone": "9882838081", "address": "#209, Block 2, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "52c5e9cf-8422-5b7a-a17b-b95affe2cb06"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9990bdc7-f884-5bd5-9d3d-1602bf2e1b9e'::uuid, 'Amit Gupta', 'cust-45', 'customer-000045@aplibhaji.com', '#209, Block 2, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000045',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '52c5e9cf-8422-5b7a-a17b-b95affe2cb06'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e5406151-6a7f-570e-a80f-0fb335b57cd7'::uuid, 'authenticated', 'authenticated',
  'customer-000046@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Gupta", "phone": "9862339827", "address": "#311, Block 2, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "52c5e9cf-8422-5b7a-a17b-b95affe2cb06"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e5406151-6a7f-570e-a80f-0fb335b57cd7'::uuid, 'Sanjay Gupta', 'cust-46', 'customer-000046@aplibhaji.com', '#311, Block 2, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000046',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '52c5e9cf-8422-5b7a-a17b-b95affe2cb06'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '538fcdd9-2fde-58ae-a6b5-d7d3ceb145bf'::uuid, 'authenticated', 'authenticated',
  'customer-000047@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Deshmukh", "phone": "9888800467", "address": "#135, Block 8, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "a59eacea-4d0d-5072-b751-d24b06cde523"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '538fcdd9-2fde-58ae-a6b5-d7d3ceb145bf'::uuid, 'Sunita Deshmukh', 'cust-47', 'customer-000047@aplibhaji.com', '#135, Block 8, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000047',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, 'a59eacea-4d0d-5072-b751-d24b06cde523'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0e24178d-670f-5450-bcd2-29e0449c505d'::uuid, 'authenticated', 'authenticated',
  'customer-000048@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Deshmukh", "phone": "9849835216", "address": "#267, Block 4, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "17666bae-5a2a-5cd1-a03e-dd2adad4246a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0e24178d-670f-5450-bcd2-29e0449c505d'::uuid, 'Swati Deshmukh', 'cust-48', 'customer-000048@aplibhaji.com', '#267, Block 4, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000048',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '17666bae-5a2a-5cd1-a03e-dd2adad4246a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c07cb2a7-3645-530c-8219-f2309be18824'::uuid, 'authenticated', 'authenticated',
  'customer-000049@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Sharma", "phone": "9883774264", "address": "#113, Block 2, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "52c5e9cf-8422-5b7a-a17b-b95affe2cb06"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c07cb2a7-3645-530c-8219-f2309be18824'::uuid, 'Amit Sharma', 'cust-49', 'customer-000049@aplibhaji.com', '#113, Block 2, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000049',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '52c5e9cf-8422-5b7a-a17b-b95affe2cb06'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dbc34f70-9116-50fe-a418-63642d9732b5'::uuid, 'authenticated', 'authenticated',
  'customer-000050@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Agarwal", "phone": "9840261395", "address": "#140, Block 3, Green Lane 1, North Zone Sector 1", "area_id": "51271cc0-ee66-5b3c-b608-ba4fdb0b296a", "road_id": "19aaefa6-836d-50b2-858e-3c002e058bbd", "sub_road_id": "3ec14cf4-6163-5feb-9ce1-c1c3d40693e8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dbc34f70-9116-50fe-a418-63642d9732b5'::uuid, 'Swati Agarwal', 'cust-50', 'customer-000050@aplibhaji.com', '#140, Block 3, Green Lane 1, North Zone Sector 1', 'CUSTOMER-000050',
  '51271cc0-ee66-5b3c-b608-ba4fdb0b296a'::uuid, '19aaefa6-836d-50b2-858e-3c002e058bbd'::uuid, '3ec14cf4-6163-5feb-9ce1-c1c3d40693e8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '17af11a4-dc81-5864-9281-27f522d17997'::uuid, 'authenticated', 'authenticated',
  'customer-000051@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Deshmukh", "phone": "9832615145", "address": "#272, Block 2, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "661c173e-e0e8-5ca8-aee5-e3b9c03d02b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '17af11a4-dc81-5864-9281-27f522d17997'::uuid, 'Sneha Deshmukh', 'cust-51', 'customer-000051@aplibhaji.com', '#272, Block 2, Market Road 2, South Point Colony', 'CUSTOMER-000051',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '374a0ea6-17a4-542c-93b1-90a3842075df'::uuid, 'authenticated', 'authenticated',
  'customer-000052@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Chawla", "phone": "9847035146", "address": "#341, Block 6, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "685c6e8f-d5e0-57b1-afd0-fd89514cb6cf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '374a0ea6-17a4-542c-93b1-90a3842075df'::uuid, 'Kavita Chawla', 'cust-52', 'customer-000052@aplibhaji.com', '#341, Block 6, Market Road 2, South Point Colony', 'CUSTOMER-000052',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '685c6e8f-d5e0-57b1-afd0-fd89514cb6cf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c8f8922b-b8d5-519e-a488-bdec504b4b61'::uuid, 'authenticated', 'authenticated',
  'customer-000053@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Rao", "phone": "9860856622", "address": "#368, Block 2, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "661c173e-e0e8-5ca8-aee5-e3b9c03d02b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c8f8922b-b8d5-519e-a488-bdec504b4b61'::uuid, 'Swati Rao', 'cust-53', 'customer-000053@aplibhaji.com', '#368, Block 2, Market Road 2, South Point Colony', 'CUSTOMER-000053',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7d422a69-2793-56f9-b654-1d2cb09ddb66'::uuid, 'authenticated', 'authenticated',
  'customer-000054@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Joshi", "phone": "9889491776", "address": "#218, Block 2, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "661c173e-e0e8-5ca8-aee5-e3b9c03d02b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7d422a69-2793-56f9-b654-1d2cb09ddb66'::uuid, 'Swati Joshi', 'cust-54', 'customer-000054@aplibhaji.com', '#218, Block 2, Market Road 2, South Point Colony', 'CUSTOMER-000054',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '25f34832-4a28-520d-ba37-e34088021578'::uuid, 'authenticated', 'authenticated',
  'customer-000055@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Kumar", "phone": "9868441808", "address": "#330, Block 2, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "661c173e-e0e8-5ca8-aee5-e3b9c03d02b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '25f34832-4a28-520d-ba37-e34088021578'::uuid, 'Kavita Kumar', 'cust-55', 'customer-000055@aplibhaji.com', '#330, Block 2, Market Road 2, South Point Colony', 'CUSTOMER-000055',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9bad21d9-bcd4-5acd-8aa6-f5c4fadb5b8a'::uuid, 'authenticated', 'authenticated',
  'customer-000056@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Gupta", "phone": "9858325552", "address": "#357, Block 2, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "661c173e-e0e8-5ca8-aee5-e3b9c03d02b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9bad21d9-bcd4-5acd-8aa6-f5c4fadb5b8a'::uuid, 'Anita Gupta', 'cust-56', 'customer-000056@aplibhaji.com', '#357, Block 2, Market Road 2, South Point Colony', 'CUSTOMER-000056',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '661c173e-e0e8-5ca8-aee5-e3b9c03d02b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'db686f06-4e3b-5835-a45e-f428d3afd4e9'::uuid, 'authenticated', 'authenticated',
  'customer-000057@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Kulkarni", "phone": "9828970004", "address": "#181, Block 3, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "14a9cf03-d6f9-5775-a504-3e838444174a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'db686f06-4e3b-5835-a45e-f428d3afd4e9'::uuid, 'Amit Kulkarni', 'cust-57', 'customer-000057@aplibhaji.com', '#181, Block 3, Market Road 2, South Point Colony', 'CUSTOMER-000057',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '14a9cf03-d6f9-5775-a504-3e838444174a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '08df3b02-e806-5dcf-9822-c8ce423821f7'::uuid, 'authenticated', 'authenticated',
  'customer-000058@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Nair", "phone": "9849899870", "address": "#320, Block 4, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "7d6e5e0e-9d2f-5c14-b192-0016cdfe02b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '08df3b02-e806-5dcf-9822-c8ce423821f7'::uuid, 'Sneha Nair', 'cust-58', 'customer-000058@aplibhaji.com', '#320, Block 4, Market Road 2, South Point Colony', 'CUSTOMER-000058',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '7d6e5e0e-9d2f-5c14-b192-0016cdfe02b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '655f153e-92f6-55f4-ad1f-c0e8a7b67864'::uuid, 'authenticated', 'authenticated',
  'customer-000059@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Patel", "phone": "9846647209", "address": "#335, Block 7, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "536bb67c-9326-5363-8ec3-6a04e97f29e3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '655f153e-92f6-55f4-ad1f-c0e8a7b67864'::uuid, 'Priya Patel', 'cust-59', 'customer-000059@aplibhaji.com', '#335, Block 7, Market Road 2, South Point Colony', 'CUSTOMER-000059',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, '536bb67c-9326-5363-8ec3-6a04e97f29e3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '533d2d19-b114-5a88-ab62-898c64a62cbb'::uuid, 'authenticated', 'authenticated',
  'customer-000060@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Verma", "phone": "9840975955", "address": "#303, Block 8, Market Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "9cdce41e-a8d7-564b-bf0f-edf5e1a58de8", "sub_road_id": "f65657f2-a930-54a1-ad3c-424e693caf0e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '533d2d19-b114-5a88-ab62-898c64a62cbb'::uuid, 'Sanjay Verma', 'cust-60', 'customer-000060@aplibhaji.com', '#303, Block 8, Market Road 2, South Point Colony', 'CUSTOMER-000060',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '9cdce41e-a8d7-564b-bf0f-edf5e1a58de8'::uuid, 'f65657f2-a930-54a1-ad3c-424e693caf0e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'da5322aa-4990-5bd3-ba3a-0555a5aa3d19'::uuid, 'authenticated', 'authenticated',
  'customer-000061@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Nair", "phone": "9819716577", "address": "#154, Block 2, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "5ce81b87-a8c3-58f9-bdc0-599b0a5640e9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'da5322aa-4990-5bd3-ba3a-0555a5aa3d19'::uuid, 'Swati Nair', 'cust-61', 'customer-000061@aplibhaji.com', '#154, Block 2, MG Road 2, South Point Colony', 'CUSTOMER-000061',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '5ce81b87-a8c3-58f9-bdc0-599b0a5640e9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2294677b-9a10-5e6c-86a5-c17eaa0f0b66'::uuid, 'authenticated', 'authenticated',
  'customer-000062@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Kulkarni", "phone": "9858590456", "address": "#364, Block 5, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "29fa61e4-3b25-544a-8156-59e833a88b98"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2294677b-9a10-5e6c-86a5-c17eaa0f0b66'::uuid, 'Rajesh Kulkarni', 'cust-62', 'customer-000062@aplibhaji.com', '#364, Block 5, MG Road 2, South Point Colony', 'CUSTOMER-000062',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '29fa61e4-3b25-544a-8156-59e833a88b98'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd2ff21cc-785c-5e6b-9277-b1dee14e5a11'::uuid, 'authenticated', 'authenticated',
  'customer-000063@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Agarwal", "phone": "9857020915", "address": "#278, Block 5, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "29fa61e4-3b25-544a-8156-59e833a88b98"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd2ff21cc-785c-5e6b-9277-b1dee14e5a11'::uuid, 'Deepak Agarwal', 'cust-63', 'customer-000063@aplibhaji.com', '#278, Block 5, MG Road 2, South Point Colony', 'CUSTOMER-000063',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '29fa61e4-3b25-544a-8156-59e833a88b98'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '611c27c7-1481-5c9f-911b-9c214840b879'::uuid, 'authenticated', 'authenticated',
  'customer-000064@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Rao", "phone": "9824869077", "address": "#164, Block 2, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "5ce81b87-a8c3-58f9-bdc0-599b0a5640e9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '611c27c7-1481-5c9f-911b-9c214840b879'::uuid, 'Sunita Rao', 'cust-64', 'customer-000064@aplibhaji.com', '#164, Block 2, MG Road 2, South Point Colony', 'CUSTOMER-000064',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '5ce81b87-a8c3-58f9-bdc0-599b0a5640e9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fcaa7fe4-e0d0-58a5-b8ec-9fbde3933e1b'::uuid, 'authenticated', 'authenticated',
  'customer-000065@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Reddy", "phone": "9859035482", "address": "#396, Block 6, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "ea581510-9fb3-5e90-a264-f72224f7e5f8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fcaa7fe4-e0d0-58a5-b8ec-9fbde3933e1b'::uuid, 'Deepak Reddy', 'cust-65', 'customer-000065@aplibhaji.com', '#396, Block 6, MG Road 2, South Point Colony', 'CUSTOMER-000065',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'ea581510-9fb3-5e90-a264-f72224f7e5f8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '760b03d3-4103-5d0c-8627-33a9c2b3288b'::uuid, 'authenticated', 'authenticated',
  'customer-000066@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kulkarni", "phone": "9824060990", "address": "#104, Block 1, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "4fdd2448-e521-5407-a290-c430c33c8dcb"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '760b03d3-4103-5d0c-8627-33a9c2b3288b'::uuid, 'Rohan Kulkarni', 'cust-66', 'customer-000066@aplibhaji.com', '#104, Block 1, MG Road 2, South Point Colony', 'CUSTOMER-000066',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '4fdd2448-e521-5407-a290-c430c33c8dcb'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '53a716d2-c3c6-5750-87ff-10e51c38f3e0'::uuid, 'authenticated', 'authenticated',
  'customer-000067@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Verma", "phone": "9865701812", "address": "#225, Block 6, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "ea581510-9fb3-5e90-a264-f72224f7e5f8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '53a716d2-c3c6-5750-87ff-10e51c38f3e0'::uuid, 'Vikram Verma', 'cust-67', 'customer-000067@aplibhaji.com', '#225, Block 6, MG Road 2, South Point Colony', 'CUSTOMER-000067',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'ea581510-9fb3-5e90-a264-f72224f7e5f8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '16d18704-0d2a-55de-8cdb-57e11acb1312'::uuid, 'authenticated', 'authenticated',
  'customer-000068@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Joshi", "phone": "9873678031", "address": "#234, Block 8, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "90573fdb-a8a7-5c73-ac42-6070403b8d80"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '16d18704-0d2a-55de-8cdb-57e11acb1312'::uuid, 'Vijay Joshi', 'cust-68', 'customer-000068@aplibhaji.com', '#234, Block 8, MG Road 2, South Point Colony', 'CUSTOMER-000068',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '90573fdb-a8a7-5c73-ac42-6070403b8d80'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dd5e26ae-032c-5a9c-8249-2fd7ea2f0278'::uuid, 'authenticated', 'authenticated',
  'customer-000069@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Kumar", "phone": "9870687153", "address": "#274, Block 8, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "90573fdb-a8a7-5c73-ac42-6070403b8d80"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dd5e26ae-032c-5a9c-8249-2fd7ea2f0278'::uuid, 'Ajay Kumar', 'cust-69', 'customer-000069@aplibhaji.com', '#274, Block 8, MG Road 2, South Point Colony', 'CUSTOMER-000069',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, '90573fdb-a8a7-5c73-ac42-6070403b8d80'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7a6e3cc8-9b9b-56e0-9367-498aeee3da5c'::uuid, 'authenticated', 'authenticated',
  'customer-000070@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Deshmukh", "phone": "9848482496", "address": "#198, Block 6, MG Road 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "e88cd7e3-e1c1-5995-8d02-06fcf987f912", "sub_road_id": "ea581510-9fb3-5e90-a264-f72224f7e5f8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7a6e3cc8-9b9b-56e0-9367-498aeee3da5c'::uuid, 'Rajesh Deshmukh', 'cust-70', 'customer-000070@aplibhaji.com', '#198, Block 6, MG Road 2, South Point Colony', 'CUSTOMER-000070',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, 'e88cd7e3-e1c1-5995-8d02-06fcf987f912'::uuid, 'ea581510-9fb3-5e90-a264-f72224f7e5f8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '10b03e28-adf7-55d9-884e-7bf6d94ff226'::uuid, 'authenticated', 'authenticated',
  'customer-000071@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Kulkarni", "phone": "9846364879", "address": "#320, Block 2, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "0754cd11-5456-532a-b189-09b3b69fcbf7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '10b03e28-adf7-55d9-884e-7bf6d94ff226'::uuid, 'Anita Kulkarni', 'cust-71', 'customer-000071@aplibhaji.com', '#320, Block 2, Station Street 2, South Point Colony', 'CUSTOMER-000071',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '0754cd11-5456-532a-b189-09b3b69fcbf7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '50030034-ccf1-5833-afcc-2904a4e2a008'::uuid, 'authenticated', 'authenticated',
  'customer-000072@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Jain", "phone": "9816606278", "address": "#167, Block 5, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "1bc3fb04-40fd-5106-8713-4cf8e9bac075"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '50030034-ccf1-5833-afcc-2904a4e2a008'::uuid, 'Suresh Jain', 'cust-72', 'customer-000072@aplibhaji.com', '#167, Block 5, Station Street 2, South Point Colony', 'CUSTOMER-000072',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '1bc3fb04-40fd-5106-8713-4cf8e9bac075'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7607d3ad-7a52-562d-bc22-8b44297f3162'::uuid, 'authenticated', 'authenticated',
  'customer-000073@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Patel", "phone": "9830917818", "address": "#139, Block 7, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "ae3ffecd-1f46-5720-8aec-4c042cd901f4"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7607d3ad-7a52-562d-bc22-8b44297f3162'::uuid, 'Sneha Patel', 'cust-73', 'customer-000073@aplibhaji.com', '#139, Block 7, Station Street 2, South Point Colony', 'CUSTOMER-000073',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'ae3ffecd-1f46-5720-8aec-4c042cd901f4'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '96f1ba67-9de3-5af0-80a3-4f3a2e53e0b7'::uuid, 'authenticated', 'authenticated',
  'customer-000074@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Nair", "phone": "9868944761", "address": "#277, Block 8, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "36785d50-31f5-5211-90f5-890befda43f1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '96f1ba67-9de3-5af0-80a3-4f3a2e53e0b7'::uuid, 'Pooja Nair', 'cust-74', 'customer-000074@aplibhaji.com', '#277, Block 8, Station Street 2, South Point Colony', 'CUSTOMER-000074',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '36785d50-31f5-5211-90f5-890befda43f1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '200188f8-e24a-51ce-9639-370286669920'::uuid, 'authenticated', 'authenticated',
  'customer-000075@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Reddy", "phone": "9844852647", "address": "#121, Block 8, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "36785d50-31f5-5211-90f5-890befda43f1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '200188f8-e24a-51ce-9639-370286669920'::uuid, 'Rajesh Reddy', 'cust-75', 'customer-000075@aplibhaji.com', '#121, Block 8, Station Street 2, South Point Colony', 'CUSTOMER-000075',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '36785d50-31f5-5211-90f5-890befda43f1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4f4ec211-0f4a-5121-aba1-b2553511ef1f'::uuid, 'authenticated', 'authenticated',
  'customer-000076@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kumar", "phone": "9867211131", "address": "#154, Block 5, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "1bc3fb04-40fd-5106-8713-4cf8e9bac075"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4f4ec211-0f4a-5121-aba1-b2553511ef1f'::uuid, 'Rohan Kumar', 'cust-76', 'customer-000076@aplibhaji.com', '#154, Block 5, Station Street 2, South Point Colony', 'CUSTOMER-000076',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '1bc3fb04-40fd-5106-8713-4cf8e9bac075'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '113fe501-1040-5296-ab14-a64a5b8b2023'::uuid, 'authenticated', 'authenticated',
  'customer-000077@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Patel", "phone": "9853334957", "address": "#328, Block 6, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "6478a79d-7fab-562e-8b91-6689eafd24c5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '113fe501-1040-5296-ab14-a64a5b8b2023'::uuid, 'Anita Patel', 'cust-77', 'customer-000077@aplibhaji.com', '#328, Block 6, Station Street 2, South Point Colony', 'CUSTOMER-000077',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '6478a79d-7fab-562e-8b91-6689eafd24c5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4b41f2f6-e30c-5d1b-b49a-0c8463a384f8'::uuid, 'authenticated', 'authenticated',
  'customer-000078@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Nair", "phone": "9842828611", "address": "#263, Block 4, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "cc540375-cda8-537c-aeca-615982740fa1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4b41f2f6-e30c-5d1b-b49a-0c8463a384f8'::uuid, 'Suresh Nair', 'cust-78', 'customer-000078@aplibhaji.com', '#263, Block 4, Station Street 2, South Point Colony', 'CUSTOMER-000078',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, 'cc540375-cda8-537c-aeca-615982740fa1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9175b15b-24d6-5074-9fdd-188de26d09e5'::uuid, 'authenticated', 'authenticated',
  'customer-000079@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Gupta", "phone": "9810190674", "address": "#226, Block 6, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "6478a79d-7fab-562e-8b91-6689eafd24c5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9175b15b-24d6-5074-9fdd-188de26d09e5'::uuid, 'Deepak Gupta', 'cust-79', 'customer-000079@aplibhaji.com', '#226, Block 6, Station Street 2, South Point Colony', 'CUSTOMER-000079',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '6478a79d-7fab-562e-8b91-6689eafd24c5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '073ae62a-5d63-5f2b-8bcc-d9ef990b06a1'::uuid, 'authenticated', 'authenticated',
  'customer-000080@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Chawla", "phone": "9845552991", "address": "#179, Block 3, Station Street 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7bfd4a07-63b0-5cf5-9249-a19dddae07bd", "sub_road_id": "0a3a397e-04d5-5995-ae82-fc1c03b78f49"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '073ae62a-5d63-5f2b-8bcc-d9ef990b06a1'::uuid, 'Ajay Chawla', 'cust-80', 'customer-000080@aplibhaji.com', '#179, Block 3, Station Street 2, South Point Colony', 'CUSTOMER-000080',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7bfd4a07-63b0-5cf5-9249-a19dddae07bd'::uuid, '0a3a397e-04d5-5995-ae82-fc1c03b78f49'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '76d3c8e6-e40f-58cb-930d-ab436b02ded7'::uuid, 'authenticated', 'authenticated',
  'customer-000081@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Verma", "phone": "9852973255", "address": "#333, Block 5, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "3cdbcc50-e439-54a5-ad5e-0e27f486baba"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '76d3c8e6-e40f-58cb-930d-ab436b02ded7'::uuid, 'Meena Verma', 'cust-81', 'customer-000081@aplibhaji.com', '#333, Block 5, Park Avenue 2, South Point Colony', 'CUSTOMER-000081',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '3cdbcc50-e439-54a5-ad5e-0e27f486baba'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4ab47153-45c7-59f7-bca0-2ffdd83bb717'::uuid, 'authenticated', 'authenticated',
  'customer-000082@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Joshi", "phone": "9893931918", "address": "#112, Block 6, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "1d66aca5-2827-5562-a5f5-eb2521eb5336"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4ab47153-45c7-59f7-bca0-2ffdd83bb717'::uuid, 'Vikram Joshi', 'cust-82', 'customer-000082@aplibhaji.com', '#112, Block 6, Park Avenue 2, South Point Colony', 'CUSTOMER-000082',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '1d66aca5-2827-5562-a5f5-eb2521eb5336'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '869c951d-d118-5596-a467-06473d9bccdf'::uuid, 'authenticated', 'authenticated',
  'customer-000083@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Verma", "phone": "9859577785", "address": "#250, Block 7, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "678f753e-bdd1-5893-bb17-e136955d33d0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '869c951d-d118-5596-a467-06473d9bccdf'::uuid, 'Rajesh Verma', 'cust-83', 'customer-000083@aplibhaji.com', '#250, Block 7, Park Avenue 2, South Point Colony', 'CUSTOMER-000083',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '678f753e-bdd1-5893-bb17-e136955d33d0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '23eb317b-ebb6-5a8c-bcfd-5db116725326'::uuid, 'authenticated', 'authenticated',
  'customer-000084@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Patel", "phone": "9871810616", "address": "#110, Block 1, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "3c6ce167-9a0d-53a1-8aa5-e7b853f0c104"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '23eb317b-ebb6-5a8c-bcfd-5db116725326'::uuid, 'Swati Patel', 'cust-84', 'customer-000084@aplibhaji.com', '#110, Block 1, Park Avenue 2, South Point Colony', 'CUSTOMER-000084',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '3c6ce167-9a0d-53a1-8aa5-e7b853f0c104'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fc3f0330-88cc-544b-8b5c-06fd2010b4c7'::uuid, 'authenticated', 'authenticated',
  'customer-000085@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Mehta", "phone": "9881654810", "address": "#269, Block 8, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "2449301c-137b-5acb-bdd2-926b36b29ac5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fc3f0330-88cc-544b-8b5c-06fd2010b4c7'::uuid, 'Neha Mehta', 'cust-85', 'customer-000085@aplibhaji.com', '#269, Block 8, Park Avenue 2, South Point Colony', 'CUSTOMER-000085',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '2449301c-137b-5acb-bdd2-926b36b29ac5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dc7d2a53-accc-5f18-b317-65bb5f79921e'::uuid, 'authenticated', 'authenticated',
  'customer-000086@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Chawla", "phone": "9876224519", "address": "#104, Block 8, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "2449301c-137b-5acb-bdd2-926b36b29ac5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dc7d2a53-accc-5f18-b317-65bb5f79921e'::uuid, 'Rahul Chawla', 'cust-86', 'customer-000086@aplibhaji.com', '#104, Block 8, Park Avenue 2, South Point Colony', 'CUSTOMER-000086',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '2449301c-137b-5acb-bdd2-926b36b29ac5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '97bc8122-9103-5fb0-b51d-c6a5b8c39cb4'::uuid, 'authenticated', 'authenticated',
  'customer-000087@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Nair", "phone": "9895881146", "address": "#281, Block 6, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "1d66aca5-2827-5562-a5f5-eb2521eb5336"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '97bc8122-9103-5fb0-b51d-c6a5b8c39cb4'::uuid, 'Vijay Nair', 'cust-87', 'customer-000087@aplibhaji.com', '#281, Block 6, Park Avenue 2, South Point Colony', 'CUSTOMER-000087',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '1d66aca5-2827-5562-a5f5-eb2521eb5336'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '540ce43f-54cc-5f5c-b7ff-d12bf47ea589'::uuid, 'authenticated', 'authenticated',
  'customer-000088@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Sharma", "phone": "9891603034", "address": "#232, Block 7, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "678f753e-bdd1-5893-bb17-e136955d33d0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '540ce43f-54cc-5f5c-b7ff-d12bf47ea589'::uuid, 'Suresh Sharma', 'cust-88', 'customer-000088@aplibhaji.com', '#232, Block 7, Park Avenue 2, South Point Colony', 'CUSTOMER-000088',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '678f753e-bdd1-5893-bb17-e136955d33d0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3f88ecfb-db66-5744-ade9-6e4089debe0d'::uuid, 'authenticated', 'authenticated',
  'customer-000089@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Mehta", "phone": "9819088776", "address": "#212, Block 7, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "678f753e-bdd1-5893-bb17-e136955d33d0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3f88ecfb-db66-5744-ade9-6e4089debe0d'::uuid, 'Pooja Mehta', 'cust-89', 'customer-000089@aplibhaji.com', '#212, Block 7, Park Avenue 2, South Point Colony', 'CUSTOMER-000089',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '678f753e-bdd1-5893-bb17-e136955d33d0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9b516937-2221-5309-9e85-d171e6b54a71'::uuid, 'authenticated', 'authenticated',
  'customer-000090@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Gupta", "phone": "9847689881", "address": "#211, Block 3, Park Avenue 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "7145a56c-9483-5668-a547-8e955ce579b6", "sub_road_id": "1a699fa9-fa3f-5caf-a247-4007f5aab0bf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9b516937-2221-5309-9e85-d171e6b54a71'::uuid, 'Ramesh Gupta', 'cust-90', 'customer-000090@aplibhaji.com', '#211, Block 3, Park Avenue 2, South Point Colony', 'CUSTOMER-000090',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '7145a56c-9483-5668-a547-8e955ce579b6'::uuid, '1a699fa9-fa3f-5caf-a247-4007f5aab0bf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '691dab64-705f-5341-b88f-0c48a2d3c829'::uuid, 'authenticated', 'authenticated',
  'customer-000091@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Verma", "phone": "9895981214", "address": "#280, Block 3, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "863c332f-b5b9-546b-85f8-b90a092f06a8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '691dab64-705f-5341-b88f-0c48a2d3c829'::uuid, 'Vijay Verma', 'cust-91', 'customer-000091@aplibhaji.com', '#280, Block 3, Green Lane 2, South Point Colony', 'CUSTOMER-000091',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '863c332f-b5b9-546b-85f8-b90a092f06a8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '07d68988-7805-56e8-9523-c42c83308f4b'::uuid, 'authenticated', 'authenticated',
  'customer-000092@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Sharma", "phone": "9845356711", "address": "#267, Block 8, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "7a700e3e-322c-5e92-a525-931d66b7b8f6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '07d68988-7805-56e8-9523-c42c83308f4b'::uuid, 'Geeta Sharma', 'cust-92', 'customer-000092@aplibhaji.com', '#267, Block 8, Green Lane 2, South Point Colony', 'CUSTOMER-000092',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '7a700e3e-322c-5e92-a525-931d66b7b8f6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c1839d47-f95e-5973-98ee-616e24f89e56'::uuid, 'authenticated', 'authenticated',
  'customer-000093@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Reddy", "phone": "9887716242", "address": "#239, Block 7, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "3b19a2fa-de38-5cb3-8393-467cdcc59cf3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c1839d47-f95e-5973-98ee-616e24f89e56'::uuid, 'Swati Reddy', 'cust-93', 'customer-000093@aplibhaji.com', '#239, Block 7, Green Lane 2, South Point Colony', 'CUSTOMER-000093',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '3b19a2fa-de38-5cb3-8393-467cdcc59cf3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8a5702f4-3afb-5046-9261-999fa71ccfe6'::uuid, 'authenticated', 'authenticated',
  'customer-000094@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Singh", "phone": "9830010638", "address": "#151, Block 8, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "7a700e3e-322c-5e92-a525-931d66b7b8f6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8a5702f4-3afb-5046-9261-999fa71ccfe6'::uuid, 'Arun Singh', 'cust-94', 'customer-000094@aplibhaji.com', '#151, Block 8, Green Lane 2, South Point Colony', 'CUSTOMER-000094',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '7a700e3e-322c-5e92-a525-931d66b7b8f6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e44a94bd-d848-5d47-adbd-efb00b1c3587'::uuid, 'authenticated', 'authenticated',
  'customer-000095@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Kumar", "phone": "9820027365", "address": "#311, Block 6, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "e131be8a-83ee-5013-a071-dca9c4798088"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e44a94bd-d848-5d47-adbd-efb00b1c3587'::uuid, 'Manish Kumar', 'cust-95', 'customer-000095@aplibhaji.com', '#311, Block 6, Green Lane 2, South Point Colony', 'CUSTOMER-000095',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'e131be8a-83ee-5013-a071-dca9c4798088'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ee610905-459a-5ee0-a953-a16ef466e8ed'::uuid, 'authenticated', 'authenticated',
  'customer-000096@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Jain", "phone": "9859987696", "address": "#109, Block 4, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "f392402a-18c2-5d17-b74f-376bbc06d7b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ee610905-459a-5ee0-a953-a16ef466e8ed'::uuid, 'Vikram Jain', 'cust-96', 'customer-000096@aplibhaji.com', '#109, Block 4, Green Lane 2, South Point Colony', 'CUSTOMER-000096',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'f392402a-18c2-5d17-b74f-376bbc06d7b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6152cc6b-29c4-5bff-bd1c-4e578807f8bb'::uuid, 'authenticated', 'authenticated',
  'customer-000097@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Kulkarni", "phone": "9883282253", "address": "#209, Block 2, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "9b2442e2-8198-5061-8d2d-0fc7480a9f96"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6152cc6b-29c4-5bff-bd1c-4e578807f8bb'::uuid, 'Sneha Kulkarni', 'cust-97', 'customer-000097@aplibhaji.com', '#209, Block 2, Green Lane 2, South Point Colony', 'CUSTOMER-000097',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '9b2442e2-8198-5061-8d2d-0fc7480a9f96'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f6922c9b-3974-5c0e-867c-5711911ec99c'::uuid, 'authenticated', 'authenticated',
  'customer-000098@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Sharma", "phone": "9834915833", "address": "#218, Block 3, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "863c332f-b5b9-546b-85f8-b90a092f06a8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f6922c9b-3974-5c0e-867c-5711911ec99c'::uuid, 'Arun Sharma', 'cust-98', 'customer-000098@aplibhaji.com', '#218, Block 3, Green Lane 2, South Point Colony', 'CUSTOMER-000098',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '863c332f-b5b9-546b-85f8-b90a092f06a8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9e580d6a-9cf5-51d8-b951-d3617e04de44'::uuid, 'authenticated', 'authenticated',
  'customer-000099@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Chawla", "phone": "9826755616", "address": "#183, Block 1, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "9c32fc3f-4afe-5238-86bb-2ec8237e82ef"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9e580d6a-9cf5-51d8-b951-d3617e04de44'::uuid, 'Neha Chawla', 'cust-99', 'customer-000099@aplibhaji.com', '#183, Block 1, Green Lane 2, South Point Colony', 'CUSTOMER-000099',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, '9c32fc3f-4afe-5238-86bb-2ec8237e82ef'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '460c6e9c-23b4-5878-81e7-77fe35566f7d'::uuid, 'authenticated', 'authenticated',
  'customer-000100@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Sharma", "phone": "9870077550", "address": "#220, Block 6, Green Lane 2, South Point Colony", "area_id": "4a03c1a4-4b33-5275-bbe5-3379c9825c63", "road_id": "51b385ee-e7ac-56da-a0e8-9d6b75b45b66", "sub_road_id": "e131be8a-83ee-5013-a071-dca9c4798088"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '460c6e9c-23b4-5878-81e7-77fe35566f7d'::uuid, 'Sneha Sharma', 'cust-100', 'customer-000100@aplibhaji.com', '#220, Block 6, Green Lane 2, South Point Colony', 'CUSTOMER-000100',
  '4a03c1a4-4b33-5275-bbe5-3379c9825c63'::uuid, '51b385ee-e7ac-56da-a0e8-9d6b75b45b66'::uuid, 'e131be8a-83ee-5013-a071-dca9c4798088'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f735adcc-7468-51f4-8a27-d68ce79eb2f5'::uuid, 'authenticated', 'authenticated',
  'customer-000101@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Mehta", "phone": "9854394837", "address": "#154, Block 7, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "25eb8366-e6e8-5a7e-858e-5262488cbb9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f735adcc-7468-51f4-8a27-d68ce79eb2f5'::uuid, 'Rohan Mehta', 'cust-101', 'customer-000101@aplibhaji.com', '#154, Block 7, Market Road 3, East Ridge Heights', 'CUSTOMER-000101',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '25eb8366-e6e8-5a7e-858e-5262488cbb9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '79d0d8fe-29ae-5976-b7b2-479ba3f82672'::uuid, 'authenticated', 'authenticated',
  'customer-000102@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Nair", "phone": "9858108669", "address": "#391, Block 5, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "ba3bc466-0a1d-5874-8ec4-ef4c5853c2f9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '79d0d8fe-29ae-5976-b7b2-479ba3f82672'::uuid, 'Amit Nair', 'cust-102', 'customer-000102@aplibhaji.com', '#391, Block 5, Market Road 3, East Ridge Heights', 'CUSTOMER-000102',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'ba3bc466-0a1d-5874-8ec4-ef4c5853c2f9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '55298bda-68ce-5695-a120-b0f09f5f4b50'::uuid, 'authenticated', 'authenticated',
  'customer-000103@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Agarwal", "phone": "9866316081", "address": "#158, Block 7, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "25eb8366-e6e8-5a7e-858e-5262488cbb9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '55298bda-68ce-5695-a120-b0f09f5f4b50'::uuid, 'Rajesh Agarwal', 'cust-103', 'customer-000103@aplibhaji.com', '#158, Block 7, Market Road 3, East Ridge Heights', 'CUSTOMER-000103',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '25eb8366-e6e8-5a7e-858e-5262488cbb9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0bfd991b-0335-5aa2-8103-6f135383b627'::uuid, 'authenticated', 'authenticated',
  'customer-000104@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Chawla", "phone": "9880404053", "address": "#345, Block 7, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "25eb8366-e6e8-5a7e-858e-5262488cbb9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0bfd991b-0335-5aa2-8103-6f135383b627'::uuid, 'Anita Chawla', 'cust-104', 'customer-000104@aplibhaji.com', '#345, Block 7, Market Road 3, East Ridge Heights', 'CUSTOMER-000104',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '25eb8366-e6e8-5a7e-858e-5262488cbb9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '01479710-a291-5d6b-b72d-88ec3a7858fe'::uuid, 'authenticated', 'authenticated',
  'customer-000105@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Kumar", "phone": "9881082036", "address": "#288, Block 7, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "25eb8366-e6e8-5a7e-858e-5262488cbb9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '01479710-a291-5d6b-b72d-88ec3a7858fe'::uuid, 'Priya Kumar', 'cust-105', 'customer-000105@aplibhaji.com', '#288, Block 7, Market Road 3, East Ridge Heights', 'CUSTOMER-000105',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '25eb8366-e6e8-5a7e-858e-5262488cbb9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c21cfea0-a167-57ff-9f26-262220367d13'::uuid, 'authenticated', 'authenticated',
  'customer-000106@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Reddy", "phone": "9860367092", "address": "#396, Block 5, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "ba3bc466-0a1d-5874-8ec4-ef4c5853c2f9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c21cfea0-a167-57ff-9f26-262220367d13'::uuid, 'Geeta Reddy', 'cust-106', 'customer-000106@aplibhaji.com', '#396, Block 5, Market Road 3, East Ridge Heights', 'CUSTOMER-000106',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'ba3bc466-0a1d-5874-8ec4-ef4c5853c2f9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '09ffe75f-1ece-56e5-9ca2-2ebcf3cc972b'::uuid, 'authenticated', 'authenticated',
  'customer-000107@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Joshi", "phone": "9814328404", "address": "#332, Block 8, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "344d1a7b-af94-5acf-a3ce-3d01ea763a20"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '09ffe75f-1ece-56e5-9ca2-2ebcf3cc972b'::uuid, 'Arun Joshi', 'cust-107', 'customer-000107@aplibhaji.com', '#332, Block 8, Market Road 3, East Ridge Heights', 'CUSTOMER-000107',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '344d1a7b-af94-5acf-a3ce-3d01ea763a20'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '440d0d1a-191d-583d-815f-9da78555e93c'::uuid, 'authenticated', 'authenticated',
  'customer-000108@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Mehta", "phone": "9837389473", "address": "#276, Block 1, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "a3728839-2e51-5b85-a6ef-7ff185fc1ad6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '440d0d1a-191d-583d-815f-9da78555e93c'::uuid, 'Meena Mehta', 'cust-108', 'customer-000108@aplibhaji.com', '#276, Block 1, Market Road 3, East Ridge Heights', 'CUSTOMER-000108',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'a3728839-2e51-5b85-a6ef-7ff185fc1ad6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cc9ef29f-acc2-58b0-92f5-cfe69dd3b67b'::uuid, 'authenticated', 'authenticated',
  'customer-000109@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Nair", "phone": "9833324863", "address": "#144, Block 1, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "a3728839-2e51-5b85-a6ef-7ff185fc1ad6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cc9ef29f-acc2-58b0-92f5-cfe69dd3b67b'::uuid, 'Anita Nair', 'cust-109', 'customer-000109@aplibhaji.com', '#144, Block 1, Market Road 3, East Ridge Heights', 'CUSTOMER-000109',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, 'a3728839-2e51-5b85-a6ef-7ff185fc1ad6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'bafb82e0-2a8f-5139-a0f3-a5019b525ae3'::uuid, 'authenticated', 'authenticated',
  'customer-000110@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Singh", "phone": "9881320449", "address": "#320, Block 2, Market Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6ef02e96-e0c6-500b-8f52-453e786d9479", "sub_road_id": "66184c50-54d5-59ef-b670-938ff017ae55"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'bafb82e0-2a8f-5139-a0f3-a5019b525ae3'::uuid, 'Sanjay Singh', 'cust-110', 'customer-000110@aplibhaji.com', '#320, Block 2, Market Road 3, East Ridge Heights', 'CUSTOMER-000110',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6ef02e96-e0c6-500b-8f52-453e786d9479'::uuid, '66184c50-54d5-59ef-b670-938ff017ae55'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '357694b4-ef43-5d06-b6e4-c4fd7510a788'::uuid, 'authenticated', 'authenticated',
  'customer-000111@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Deshmukh", "phone": "9812646424", "address": "#328, Block 7, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "7e56f822-9a46-54a6-8d3a-9a43cc99d20a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '357694b4-ef43-5d06-b6e4-c4fd7510a788'::uuid, 'Ramesh Deshmukh', 'cust-111', 'customer-000111@aplibhaji.com', '#328, Block 7, MG Road 3, East Ridge Heights', 'CUSTOMER-000111',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '7e56f822-9a46-54a6-8d3a-9a43cc99d20a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '736e4677-3568-5797-89cf-2982f2c30fd3'::uuid, 'authenticated', 'authenticated',
  'customer-000112@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Rao", "phone": "9896582936", "address": "#353, Block 3, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "525fd2b1-aef9-5b0b-bf45-e74c18a7a478"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '736e4677-3568-5797-89cf-2982f2c30fd3'::uuid, 'Rahul Rao', 'cust-112', 'customer-000112@aplibhaji.com', '#353, Block 3, MG Road 3, East Ridge Heights', 'CUSTOMER-000112',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '525fd2b1-aef9-5b0b-bf45-e74c18a7a478'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '84a420cb-cb65-5d8d-9dc4-3fb29fb96560'::uuid, 'authenticated', 'authenticated',
  'customer-000113@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Joshi", "phone": "9858914409", "address": "#173, Block 7, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "7e56f822-9a46-54a6-8d3a-9a43cc99d20a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '84a420cb-cb65-5d8d-9dc4-3fb29fb96560'::uuid, 'Kavita Joshi', 'cust-113', 'customer-000113@aplibhaji.com', '#173, Block 7, MG Road 3, East Ridge Heights', 'CUSTOMER-000113',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '7e56f822-9a46-54a6-8d3a-9a43cc99d20a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0176487c-c549-5d9b-aa52-830328e98671'::uuid, 'authenticated', 'authenticated',
  'customer-000114@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Chawla", "phone": "9833091440", "address": "#199, Block 1, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "ef78a6c7-25f1-5993-90cc-d4226eea5539"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0176487c-c549-5d9b-aa52-830328e98671'::uuid, 'Ananya Chawla', 'cust-114', 'customer-000114@aplibhaji.com', '#199, Block 1, MG Road 3, East Ridge Heights', 'CUSTOMER-000114',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'ef78a6c7-25f1-5993-90cc-d4226eea5539'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '843e0f9e-03c4-59eb-af50-0683201ab978'::uuid, 'authenticated', 'authenticated',
  'customer-000115@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Sharma", "phone": "9881230433", "address": "#224, Block 4, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "e45cc303-2147-5d1a-b482-e3ca7a83fbe5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '843e0f9e-03c4-59eb-af50-0683201ab978'::uuid, 'Sanjay Sharma', 'cust-115', 'customer-000115@aplibhaji.com', '#224, Block 4, MG Road 3, East Ridge Heights', 'CUSTOMER-000115',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'e45cc303-2147-5d1a-b482-e3ca7a83fbe5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6610529e-6195-570e-8555-879ecc253736'::uuid, 'authenticated', 'authenticated',
  'customer-000116@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Jain", "phone": "9879243018", "address": "#177, Block 3, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "525fd2b1-aef9-5b0b-bf45-e74c18a7a478"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6610529e-6195-570e-8555-879ecc253736'::uuid, 'Sanjay Jain', 'cust-116', 'customer-000116@aplibhaji.com', '#177, Block 3, MG Road 3, East Ridge Heights', 'CUSTOMER-000116',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '525fd2b1-aef9-5b0b-bf45-e74c18a7a478'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2cef0b7b-aebb-59b8-964a-65e03ed792ba'::uuid, 'authenticated', 'authenticated',
  'customer-000117@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Joshi", "phone": "9814551453", "address": "#389, Block 2, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "ce027fa0-838d-51f1-83df-c43e7b98d961"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2cef0b7b-aebb-59b8-964a-65e03ed792ba'::uuid, 'Sanjay Joshi', 'cust-117', 'customer-000117@aplibhaji.com', '#389, Block 2, MG Road 3, East Ridge Heights', 'CUSTOMER-000117',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'ce027fa0-838d-51f1-83df-c43e7b98d961'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e5c41f6b-686f-535d-8a29-533b909ac5db'::uuid, 'authenticated', 'authenticated',
  'customer-000118@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Deshmukh", "phone": "9869364692", "address": "#248, Block 1, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "ef78a6c7-25f1-5993-90cc-d4226eea5539"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e5c41f6b-686f-535d-8a29-533b909ac5db'::uuid, 'Rahul Deshmukh', 'cust-118', 'customer-000118@aplibhaji.com', '#248, Block 1, MG Road 3, East Ridge Heights', 'CUSTOMER-000118',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, 'ef78a6c7-25f1-5993-90cc-d4226eea5539'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7837ca75-8567-5ba6-9be3-35b036e66c98'::uuid, 'authenticated', 'authenticated',
  'customer-000119@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Gupta", "phone": "9821492805", "address": "#281, Block 5, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "57c8a56a-eeea-5f5c-9ba9-bc395ac5be9e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7837ca75-8567-5ba6-9be3-35b036e66c98'::uuid, 'Priya Gupta', 'cust-119', 'customer-000119@aplibhaji.com', '#281, Block 5, MG Road 3, East Ridge Heights', 'CUSTOMER-000119',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '57c8a56a-eeea-5f5c-9ba9-bc395ac5be9e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '383febc7-00ec-5451-b20f-f7bf41e05b9e'::uuid, 'authenticated', 'authenticated',
  'customer-000120@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Joshi", "phone": "9859530889", "address": "#120, Block 7, MG Road 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "690511e9-0afb-5a67-9cfe-d293270cc406", "sub_road_id": "7e56f822-9a46-54a6-8d3a-9a43cc99d20a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '383febc7-00ec-5451-b20f-f7bf41e05b9e'::uuid, 'Vikram Joshi', 'cust-120', 'customer-000120@aplibhaji.com', '#120, Block 7, MG Road 3, East Ridge Heights', 'CUSTOMER-000120',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '690511e9-0afb-5a67-9cfe-d293270cc406'::uuid, '7e56f822-9a46-54a6-8d3a-9a43cc99d20a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '727ef6f0-8108-509c-87dc-1a18f4089b4f'::uuid, 'authenticated', 'authenticated',
  'customer-000121@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Mehta", "phone": "9853818608", "address": "#242, Block 2, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "a325e6e7-2105-5e9c-b06f-85b7ff7a4cce"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '727ef6f0-8108-509c-87dc-1a18f4089b4f'::uuid, 'Rahul Mehta', 'cust-121', 'customer-000121@aplibhaji.com', '#242, Block 2, Station Street 3, East Ridge Heights', 'CUSTOMER-000121',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd0aa1601-f1a0-5342-9f1d-5edcc26a6907'::uuid, 'authenticated', 'authenticated',
  'customer-000122@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Gupta", "phone": "9841452055", "address": "#388, Block 2, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "a325e6e7-2105-5e9c-b06f-85b7ff7a4cce"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd0aa1601-f1a0-5342-9f1d-5edcc26a6907'::uuid, 'Manish Gupta', 'cust-122', 'customer-000122@aplibhaji.com', '#388, Block 2, Station Street 3, East Ridge Heights', 'CUSTOMER-000122',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9ef0df01-df90-5318-9aea-b19ef5d11f09'::uuid, 'authenticated', 'authenticated',
  'customer-000123@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Nair", "phone": "9865944683", "address": "#284, Block 2, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "a325e6e7-2105-5e9c-b06f-85b7ff7a4cce"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9ef0df01-df90-5318-9aea-b19ef5d11f09'::uuid, 'Deepak Nair', 'cust-123', 'customer-000123@aplibhaji.com', '#284, Block 2, Station Street 3, East Ridge Heights', 'CUSTOMER-000123',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '59008cf9-ec7c-55d2-a904-ec10d9d664d3'::uuid, 'authenticated', 'authenticated',
  'customer-000124@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Mehta", "phone": "9885586929", "address": "#112, Block 8, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "af3caaf0-9d10-52b5-bc20-5ba6d497a425"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '59008cf9-ec7c-55d2-a904-ec10d9d664d3'::uuid, 'Ananya Mehta', 'cust-124', 'customer-000124@aplibhaji.com', '#112, Block 8, Station Street 3, East Ridge Heights', 'CUSTOMER-000124',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'af3caaf0-9d10-52b5-bc20-5ba6d497a425'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fdca5788-a46d-5953-a899-ff37f46fc026'::uuid, 'authenticated', 'authenticated',
  'customer-000125@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Deshmukh", "phone": "9866592290", "address": "#160, Block 4, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "ec86a6fc-b49a-511d-958b-4ffc3f57ce5a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fdca5788-a46d-5953-a899-ff37f46fc026'::uuid, 'Manish Deshmukh', 'cust-125', 'customer-000125@aplibhaji.com', '#160, Block 4, Station Street 3, East Ridge Heights', 'CUSTOMER-000125',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'ec86a6fc-b49a-511d-958b-4ffc3f57ce5a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '344ca40b-0a7d-5931-a141-d9a758c0845c'::uuid, 'authenticated', 'authenticated',
  'customer-000126@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Sharma", "phone": "9845600758", "address": "#293, Block 2, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "a325e6e7-2105-5e9c-b06f-85b7ff7a4cce"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '344ca40b-0a7d-5931-a141-d9a758c0845c'::uuid, 'Vijay Sharma', 'cust-126', 'customer-000126@aplibhaji.com', '#293, Block 2, Station Street 3, East Ridge Heights', 'CUSTOMER-000126',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0fabfad8-25c5-5f89-bed5-0e85415da7ad'::uuid, 'authenticated', 'authenticated',
  'customer-000127@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Kulkarni", "phone": "9884269742", "address": "#242, Block 4, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "ec86a6fc-b49a-511d-958b-4ffc3f57ce5a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0fabfad8-25c5-5f89-bed5-0e85415da7ad'::uuid, 'Anita Kulkarni', 'cust-127', 'customer-000127@aplibhaji.com', '#242, Block 4, Station Street 3, East Ridge Heights', 'CUSTOMER-000127',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'ec86a6fc-b49a-511d-958b-4ffc3f57ce5a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4f71952a-99de-56a8-9a70-1197344cbeb6'::uuid, 'authenticated', 'authenticated',
  'customer-000128@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Joshi", "phone": "9840519708", "address": "#180, Block 7, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "0be59f8d-4530-5e6c-87bb-2e7413e27642"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4f71952a-99de-56a8-9a70-1197344cbeb6'::uuid, 'Deepak Joshi', 'cust-128', 'customer-000128@aplibhaji.com', '#180, Block 7, Station Street 3, East Ridge Heights', 'CUSTOMER-000128',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, '0be59f8d-4530-5e6c-87bb-2e7413e27642'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '494daa8d-1207-5b95-9657-fe8ca7d0a031'::uuid, 'authenticated', 'authenticated',
  'customer-000129@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Deshmukh", "phone": "9875730219", "address": "#127, Block 3, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "9c6a00c1-27e8-5850-b2bf-a36b36351a83"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '494daa8d-1207-5b95-9657-fe8ca7d0a031'::uuid, 'Deepak Deshmukh', 'cust-129', 'customer-000129@aplibhaji.com', '#127, Block 3, Station Street 3, East Ridge Heights', 'CUSTOMER-000129',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, '9c6a00c1-27e8-5850-b2bf-a36b36351a83'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1ba297fc-4bd4-5b55-bca4-d57d9b5ca7e4'::uuid, 'authenticated', 'authenticated',
  'customer-000130@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Kulkarni", "phone": "9811957622", "address": "#373, Block 2, Station Street 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "a640a136-d71c-5c63-94b0-64f5046516b1", "sub_road_id": "a325e6e7-2105-5e9c-b06f-85b7ff7a4cce"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1ba297fc-4bd4-5b55-bca4-d57d9b5ca7e4'::uuid, 'Manish Kulkarni', 'cust-130', 'customer-000130@aplibhaji.com', '#373, Block 2, Station Street 3, East Ridge Heights', 'CUSTOMER-000130',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, 'a640a136-d71c-5c63-94b0-64f5046516b1'::uuid, 'a325e6e7-2105-5e9c-b06f-85b7ff7a4cce'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8255eedc-b9a2-5eae-b175-a049c4944f4e'::uuid, 'authenticated', 'authenticated',
  'customer-000131@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Verma", "phone": "9866379667", "address": "#348, Block 3, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "1f68750b-c99e-5610-83f0-363ca48a087a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8255eedc-b9a2-5eae-b175-a049c4944f4e'::uuid, 'Neha Verma', 'cust-131', 'customer-000131@aplibhaji.com', '#348, Block 3, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000131',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '1f68750b-c99e-5610-83f0-363ca48a087a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '795a3c3b-54f3-5ec8-a9ce-c5be776afb40'::uuid, 'authenticated', 'authenticated',
  'customer-000132@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Joshi", "phone": "9875270926", "address": "#149, Block 3, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "1f68750b-c99e-5610-83f0-363ca48a087a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '795a3c3b-54f3-5ec8-a9ce-c5be776afb40'::uuid, 'Pooja Joshi', 'cust-132', 'customer-000132@aplibhaji.com', '#149, Block 3, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000132',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '1f68750b-c99e-5610-83f0-363ca48a087a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7446b6d6-9164-5c9a-a29a-9d1594006d22'::uuid, 'authenticated', 'authenticated',
  'customer-000133@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Singh", "phone": "9885275675", "address": "#261, Block 5, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "75249b45-b839-5048-9f64-f29ee0fd9110"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7446b6d6-9164-5c9a-a29a-9d1594006d22'::uuid, 'Manish Singh', 'cust-133', 'customer-000133@aplibhaji.com', '#261, Block 5, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000133',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '75249b45-b839-5048-9f64-f29ee0fd9110'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dbefb13e-9e0e-5f7a-81f7-3667f37221a8'::uuid, 'authenticated', 'authenticated',
  'customer-000134@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Patel", "phone": "9811576626", "address": "#277, Block 8, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "c1fd1119-f4bf-5dcd-a257-f9b253c01cf2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dbefb13e-9e0e-5f7a-81f7-3667f37221a8'::uuid, 'Vikram Patel', 'cust-134', 'customer-000134@aplibhaji.com', '#277, Block 8, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000134',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, 'c1fd1119-f4bf-5dcd-a257-f9b253c01cf2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2cd15a72-a96a-5590-9895-21968562427e'::uuid, 'authenticated', 'authenticated',
  'customer-000135@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Patel", "phone": "9838432677", "address": "#145, Block 6, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "95542163-045c-5f09-96d0-1580795fe0c5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2cd15a72-a96a-5590-9895-21968562427e'::uuid, 'Swati Patel', 'cust-135', 'customer-000135@aplibhaji.com', '#145, Block 6, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000135',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '95542163-045c-5f09-96d0-1580795fe0c5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'be8c5443-a5e3-5e16-b997-9d12629dd01a'::uuid, 'authenticated', 'authenticated',
  'customer-000136@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Patel", "phone": "9879184633", "address": "#278, Block 4, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "5f0ec478-eb77-56ad-9c0e-566059447826"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'be8c5443-a5e3-5e16-b997-9d12629dd01a'::uuid, 'Sanjay Patel', 'cust-136', 'customer-000136@aplibhaji.com', '#278, Block 4, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000136',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '5f0ec478-eb77-56ad-9c0e-566059447826'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '393881a2-90af-50bd-b262-79d80ec86d01'::uuid, 'authenticated', 'authenticated',
  'customer-000137@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Singh", "phone": "9868939368", "address": "#209, Block 7, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "3f7ad402-15c1-50f8-9073-0ffc2e9f6b1c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '393881a2-90af-50bd-b262-79d80ec86d01'::uuid, 'Manish Singh', 'cust-137', 'customer-000137@aplibhaji.com', '#209, Block 7, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000137',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '3f7ad402-15c1-50f8-9073-0ffc2e9f6b1c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4ab84f61-2ddf-5047-bcfd-3daa99f7ce36'::uuid, 'authenticated', 'authenticated',
  'customer-000138@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Gupta", "phone": "9864178548", "address": "#201, Block 4, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "5f0ec478-eb77-56ad-9c0e-566059447826"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4ab84f61-2ddf-5047-bcfd-3daa99f7ce36'::uuid, 'Deepak Gupta', 'cust-138', 'customer-000138@aplibhaji.com', '#201, Block 4, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000138',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '5f0ec478-eb77-56ad-9c0e-566059447826'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9e84a25f-4783-5331-8722-bd3dee1e7864'::uuid, 'authenticated', 'authenticated',
  'customer-000139@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Verma", "phone": "9876611971", "address": "#195, Block 7, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "3f7ad402-15c1-50f8-9073-0ffc2e9f6b1c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9e84a25f-4783-5331-8722-bd3dee1e7864'::uuid, 'Anita Verma', 'cust-139', 'customer-000139@aplibhaji.com', '#195, Block 7, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000139',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '3f7ad402-15c1-50f8-9073-0ffc2e9f6b1c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '27cafda3-4785-51d0-93f2-e69b7f979b70'::uuid, 'authenticated', 'authenticated',
  'customer-000140@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Rao", "phone": "9813643689", "address": "#190, Block 4, Park Avenue 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "28ed80fe-f3bf-538d-a1e7-c5d63dbd7795", "sub_road_id": "5f0ec478-eb77-56ad-9c0e-566059447826"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '27cafda3-4785-51d0-93f2-e69b7f979b70'::uuid, 'Vikram Rao', 'cust-140', 'customer-000140@aplibhaji.com', '#190, Block 4, Park Avenue 3, East Ridge Heights', 'CUSTOMER-000140',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '28ed80fe-f3bf-538d-a1e7-c5d63dbd7795'::uuid, '5f0ec478-eb77-56ad-9c0e-566059447826'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '151c7747-d27d-55e3-afff-ef1a0f113e08'::uuid, 'authenticated', 'authenticated',
  'customer-000141@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Mehta", "phone": "9876766482", "address": "#368, Block 2, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "6a91c638-e58e-5057-b5db-9d4790596339"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '151c7747-d27d-55e3-afff-ef1a0f113e08'::uuid, 'Rajesh Mehta', 'cust-141', 'customer-000141@aplibhaji.com', '#368, Block 2, Green Lane 3, East Ridge Heights', 'CUSTOMER-000141',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '6a91c638-e58e-5057-b5db-9d4790596339'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '74eeae66-c586-5623-a518-67abab09c0e0'::uuid, 'authenticated', 'authenticated',
  'customer-000142@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Kumar", "phone": "9881350511", "address": "#195, Block 2, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "6a91c638-e58e-5057-b5db-9d4790596339"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '74eeae66-c586-5623-a518-67abab09c0e0'::uuid, 'Suresh Kumar', 'cust-142', 'customer-000142@aplibhaji.com', '#195, Block 2, Green Lane 3, East Ridge Heights', 'CUSTOMER-000142',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '6a91c638-e58e-5057-b5db-9d4790596339'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8cd58792-05d0-584b-9691-9b5bad474774'::uuid, 'authenticated', 'authenticated',
  'customer-000143@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Nair", "phone": "9836623547", "address": "#295, Block 4, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "7c60e3d6-819b-5bb4-9fbc-038c4494df83"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8cd58792-05d0-584b-9691-9b5bad474774'::uuid, 'Geeta Nair', 'cust-143', 'customer-000143@aplibhaji.com', '#295, Block 4, Green Lane 3, East Ridge Heights', 'CUSTOMER-000143',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '7c60e3d6-819b-5bb4-9fbc-038c4494df83'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '77b4e04c-c105-5330-9ac3-a215de91e5c4'::uuid, 'authenticated', 'authenticated',
  'customer-000144@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Nair", "phone": "9846381518", "address": "#119, Block 4, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "7c60e3d6-819b-5bb4-9fbc-038c4494df83"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '77b4e04c-c105-5330-9ac3-a215de91e5c4'::uuid, 'Arun Nair', 'cust-144', 'customer-000144@aplibhaji.com', '#119, Block 4, Green Lane 3, East Ridge Heights', 'CUSTOMER-000144',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '7c60e3d6-819b-5bb4-9fbc-038c4494df83'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f71f0e8a-a575-5ab5-ae13-8eb4e523f6dc'::uuid, 'authenticated', 'authenticated',
  'customer-000145@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Nair", "phone": "9848257273", "address": "#392, Block 5, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "3a8e6ae0-d981-5496-90dc-984bd35e77a8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f71f0e8a-a575-5ab5-ae13-8eb4e523f6dc'::uuid, 'Manish Nair', 'cust-145', 'customer-000145@aplibhaji.com', '#392, Block 5, Green Lane 3, East Ridge Heights', 'CUSTOMER-000145',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '3a8e6ae0-d981-5496-90dc-984bd35e77a8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a707bebf-959b-5f54-83aa-ffb0e2f3056a'::uuid, 'authenticated', 'authenticated',
  'customer-000146@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Verma", "phone": "9898105896", "address": "#258, Block 1, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "1efcba63-c8a1-509b-bb34-3e3a58f0e9be"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a707bebf-959b-5f54-83aa-ffb0e2f3056a'::uuid, 'Amit Verma', 'cust-146', 'customer-000146@aplibhaji.com', '#258, Block 1, Green Lane 3, East Ridge Heights', 'CUSTOMER-000146',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '1efcba63-c8a1-509b-bb34-3e3a58f0e9be'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ee0c8a7e-47fe-5fef-b5f1-caefe6c2bad8'::uuid, 'authenticated', 'authenticated',
  'customer-000147@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Nair", "phone": "9816152286", "address": "#254, Block 5, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "3a8e6ae0-d981-5496-90dc-984bd35e77a8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ee0c8a7e-47fe-5fef-b5f1-caefe6c2bad8'::uuid, 'Priya Nair', 'cust-147', 'customer-000147@aplibhaji.com', '#254, Block 5, Green Lane 3, East Ridge Heights', 'CUSTOMER-000147',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '3a8e6ae0-d981-5496-90dc-984bd35e77a8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6a717e0c-68ea-5443-83b8-f044ab31921e'::uuid, 'authenticated', 'authenticated',
  'customer-000148@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Joshi", "phone": "9871589921", "address": "#323, Block 4, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "7c60e3d6-819b-5bb4-9fbc-038c4494df83"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6a717e0c-68ea-5443-83b8-f044ab31921e'::uuid, 'Geeta Joshi', 'cust-148', 'customer-000148@aplibhaji.com', '#323, Block 4, Green Lane 3, East Ridge Heights', 'CUSTOMER-000148',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '7c60e3d6-819b-5bb4-9fbc-038c4494df83'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dbd3d459-f73b-57f4-b616-957b1127e62c'::uuid, 'authenticated', 'authenticated',
  'customer-000149@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Joshi", "phone": "9849886771", "address": "#242, Block 3, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "1dea2a85-5ca4-5faf-a0ac-a316cc31184a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dbd3d459-f73b-57f4-b616-957b1127e62c'::uuid, 'Sneha Joshi', 'cust-149', 'customer-000149@aplibhaji.com', '#242, Block 3, Green Lane 3, East Ridge Heights', 'CUSTOMER-000149',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '1dea2a85-5ca4-5faf-a0ac-a316cc31184a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ff298d6d-4aa8-561e-9fc2-d3c260c8aeb1'::uuid, 'authenticated', 'authenticated',
  'customer-000150@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Mehta", "phone": "9850296154", "address": "#187, Block 4, Green Lane 3, East Ridge Heights", "area_id": "eda20b21-061b-54f7-82e9-e415c11e5aaa", "road_id": "6cd675b7-d026-599e-becd-69b443d8cd25", "sub_road_id": "7c60e3d6-819b-5bb4-9fbc-038c4494df83"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ff298d6d-4aa8-561e-9fc2-d3c260c8aeb1'::uuid, 'Meena Mehta', 'cust-150', 'customer-000150@aplibhaji.com', '#187, Block 4, Green Lane 3, East Ridge Heights', 'CUSTOMER-000150',
  'eda20b21-061b-54f7-82e9-e415c11e5aaa'::uuid, '6cd675b7-d026-599e-becd-69b443d8cd25'::uuid, '7c60e3d6-819b-5bb4-9fbc-038c4494df83'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9cb3e0a9-fbd4-5997-b2e4-8bbe91d329ff'::uuid, 'authenticated', 'authenticated',
  'customer-000151@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Nair", "phone": "9865444059", "address": "#213, Block 6, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "f40d967e-c4ba-56bb-8feb-28e81cebb72b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9cb3e0a9-fbd4-5997-b2e4-8bbe91d329ff'::uuid, 'Rohan Nair', 'cust-151', 'customer-000151@aplibhaji.com', '#213, Block 6, Market Road 4, West End Enclave', 'CUSTOMER-000151',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'f40d967e-c4ba-56bb-8feb-28e81cebb72b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0d116e17-2cb5-5860-9d85-f476197740b6'::uuid, 'authenticated', 'authenticated',
  'customer-000152@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Deshmukh", "phone": "9866288315", "address": "#146, Block 8, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "e03f4081-47e2-5140-bdd3-87a440664aca"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0d116e17-2cb5-5860-9d85-f476197740b6'::uuid, 'Swati Deshmukh', 'cust-152', 'customer-000152@aplibhaji.com', '#146, Block 8, Market Road 4, West End Enclave', 'CUSTOMER-000152',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'e03f4081-47e2-5140-bdd3-87a440664aca'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ad2e0625-abff-54bc-b09c-8202955660ff'::uuid, 'authenticated', 'authenticated',
  'customer-000153@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Chawla", "phone": "9830399737", "address": "#268, Block 7, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "d788b40e-b298-5d09-9fe4-72b2565bc9a3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ad2e0625-abff-54bc-b09c-8202955660ff'::uuid, 'Suresh Chawla', 'cust-153', 'customer-000153@aplibhaji.com', '#268, Block 7, Market Road 4, West End Enclave', 'CUSTOMER-000153',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'd788b40e-b298-5d09-9fe4-72b2565bc9a3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '30604340-06eb-57d1-bd6b-80dc2cdcfddb'::uuid, 'authenticated', 'authenticated',
  'customer-000154@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Deshmukh", "phone": "9810366509", "address": "#194, Block 5, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "a576a1ba-6601-5d52-860c-f1bb878ffe8c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '30604340-06eb-57d1-bd6b-80dc2cdcfddb'::uuid, 'Kavita Deshmukh', 'cust-154', 'customer-000154@aplibhaji.com', '#194, Block 5, Market Road 4, West End Enclave', 'CUSTOMER-000154',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'a576a1ba-6601-5d52-860c-f1bb878ffe8c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9fca2335-d72f-52b1-9952-c51c1838033b'::uuid, 'authenticated', 'authenticated',
  'customer-000155@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Patel", "phone": "9888856795", "address": "#344, Block 2, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "e86b0c12-42f6-51f4-9984-63132e0fa3aa"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9fca2335-d72f-52b1-9952-c51c1838033b'::uuid, 'Meena Patel', 'cust-155', 'customer-000155@aplibhaji.com', '#344, Block 2, Market Road 4, West End Enclave', 'CUSTOMER-000155',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'e86b0c12-42f6-51f4-9984-63132e0fa3aa'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fcb0f026-625a-5a71-a3e4-0f1ce56ad694'::uuid, 'authenticated', 'authenticated',
  'customer-000156@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Mehta", "phone": "9869101929", "address": "#105, Block 3, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "2887c767-5cfb-5813-bd0e-2c01e9f6259d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fcb0f026-625a-5a71-a3e4-0f1ce56ad694'::uuid, 'Swati Mehta', 'cust-156', 'customer-000156@aplibhaji.com', '#105, Block 3, Market Road 4, West End Enclave', 'CUSTOMER-000156',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, '2887c767-5cfb-5813-bd0e-2c01e9f6259d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ec7cd2a9-efab-5368-8f92-d3cdda7ba611'::uuid, 'authenticated', 'authenticated',
  'customer-000157@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Deshmukh", "phone": "9866464986", "address": "#307, Block 3, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "2887c767-5cfb-5813-bd0e-2c01e9f6259d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ec7cd2a9-efab-5368-8f92-d3cdda7ba611'::uuid, 'Amit Deshmukh', 'cust-157', 'customer-000157@aplibhaji.com', '#307, Block 3, Market Road 4, West End Enclave', 'CUSTOMER-000157',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, '2887c767-5cfb-5813-bd0e-2c01e9f6259d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0923a9ec-0112-5da7-ae76-cc20ad775fb4'::uuid, 'authenticated', 'authenticated',
  'customer-000158@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Patel", "phone": "9846071474", "address": "#188, Block 3, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "2887c767-5cfb-5813-bd0e-2c01e9f6259d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0923a9ec-0112-5da7-ae76-cc20ad775fb4'::uuid, 'Ananya Patel', 'cust-158', 'customer-000158@aplibhaji.com', '#188, Block 3, Market Road 4, West End Enclave', 'CUSTOMER-000158',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, '2887c767-5cfb-5813-bd0e-2c01e9f6259d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd257331c-7a85-51a9-a0e3-8fd8c92e6a35'::uuid, 'authenticated', 'authenticated',
  'customer-000159@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Chawla", "phone": "9867599362", "address": "#345, Block 7, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "d788b40e-b298-5d09-9fe4-72b2565bc9a3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd257331c-7a85-51a9-a0e3-8fd8c92e6a35'::uuid, 'Rohan Chawla', 'cust-159', 'customer-000159@aplibhaji.com', '#345, Block 7, Market Road 4, West End Enclave', 'CUSTOMER-000159',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, 'd788b40e-b298-5d09-9fe4-72b2565bc9a3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e0f3ca05-d83f-5346-98d3-fa71727a69aa'::uuid, 'authenticated', 'authenticated',
  'customer-000160@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kulkarni", "phone": "9862147979", "address": "#115, Block 1, Market Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "edfaf619-b0b0-5032-aa17-ef5c84c72707", "sub_road_id": "5bb8cfa2-7f4b-5dae-9ab4-dea3243cbc4a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e0f3ca05-d83f-5346-98d3-fa71727a69aa'::uuid, 'Rohan Kulkarni', 'cust-160', 'customer-000160@aplibhaji.com', '#115, Block 1, Market Road 4, West End Enclave', 'CUSTOMER-000160',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, 'edfaf619-b0b0-5032-aa17-ef5c84c72707'::uuid, '5bb8cfa2-7f4b-5dae-9ab4-dea3243cbc4a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '307d431b-47a1-5b22-865f-49ae4e5fd13c'::uuid, 'authenticated', 'authenticated',
  'customer-000161@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Verma", "phone": "9878911476", "address": "#194, Block 1, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "90bb1b4a-2bab-5442-b83c-02c7ff1d674b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '307d431b-47a1-5b22-865f-49ae4e5fd13c'::uuid, 'Manish Verma', 'cust-161', 'customer-000161@aplibhaji.com', '#194, Block 1, MG Road 4, West End Enclave', 'CUSTOMER-000161',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '90bb1b4a-2bab-5442-b83c-02c7ff1d674b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '67af1b63-e67d-5615-8828-04bc0c474b12'::uuid, 'authenticated', 'authenticated',
  'customer-000162@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Mehta", "phone": "9892374043", "address": "#141, Block 4, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "32d0eb60-88b2-5bd2-a3b7-f3dbab8295cf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '67af1b63-e67d-5615-8828-04bc0c474b12'::uuid, 'Meena Mehta', 'cust-162', 'customer-000162@aplibhaji.com', '#141, Block 4, MG Road 4, West End Enclave', 'CUSTOMER-000162',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '32d0eb60-88b2-5bd2-a3b7-f3dbab8295cf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8cbd8899-e17d-504c-b3c7-5bd09406223a'::uuid, 'authenticated', 'authenticated',
  'customer-000163@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Agarwal", "phone": "9868347844", "address": "#355, Block 1, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "90bb1b4a-2bab-5442-b83c-02c7ff1d674b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8cbd8899-e17d-504c-b3c7-5bd09406223a'::uuid, 'Anita Agarwal', 'cust-163', 'customer-000163@aplibhaji.com', '#355, Block 1, MG Road 4, West End Enclave', 'CUSTOMER-000163',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '90bb1b4a-2bab-5442-b83c-02c7ff1d674b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '577ba997-afa3-5786-9031-840c901512c1'::uuid, 'authenticated', 'authenticated',
  'customer-000164@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Agarwal", "phone": "9836613598", "address": "#364, Block 2, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "ce5c3d3f-1e9b-51b7-8353-0c7bd5db592e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '577ba997-afa3-5786-9031-840c901512c1'::uuid, 'Sunita Agarwal', 'cust-164', 'customer-000164@aplibhaji.com', '#364, Block 2, MG Road 4, West End Enclave', 'CUSTOMER-000164',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'ce5c3d3f-1e9b-51b7-8353-0c7bd5db592e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4845c07d-66ed-58c5-8283-e6f401fdb73e'::uuid, 'authenticated', 'authenticated',
  'customer-000165@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Chawla", "phone": "9828152117", "address": "#140, Block 5, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "31edd6db-8d15-5b62-81db-9c9421f65731"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4845c07d-66ed-58c5-8283-e6f401fdb73e'::uuid, 'Amit Chawla', 'cust-165', 'customer-000165@aplibhaji.com', '#140, Block 5, MG Road 4, West End Enclave', 'CUSTOMER-000165',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '31edd6db-8d15-5b62-81db-9c9421f65731'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cd93025e-fa89-5d59-bc93-995f9a0b157b'::uuid, 'authenticated', 'authenticated',
  'customer-000166@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Kumar", "phone": "9838632469", "address": "#353, Block 1, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "90bb1b4a-2bab-5442-b83c-02c7ff1d674b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cd93025e-fa89-5d59-bc93-995f9a0b157b'::uuid, 'Sneha Kumar', 'cust-166', 'customer-000166@aplibhaji.com', '#353, Block 1, MG Road 4, West End Enclave', 'CUSTOMER-000166',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '90bb1b4a-2bab-5442-b83c-02c7ff1d674b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f28bb360-f2c0-5769-a4a3-9cf691dfd5fb'::uuid, 'authenticated', 'authenticated',
  'customer-000167@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Kumar", "phone": "9822014896", "address": "#304, Block 4, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "32d0eb60-88b2-5bd2-a3b7-f3dbab8295cf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f28bb360-f2c0-5769-a4a3-9cf691dfd5fb'::uuid, 'Rahul Kumar', 'cust-167', 'customer-000167@aplibhaji.com', '#304, Block 4, MG Road 4, West End Enclave', 'CUSTOMER-000167',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '32d0eb60-88b2-5bd2-a3b7-f3dbab8295cf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b75506f1-de34-55c4-8ee9-d4a19d12aea9'::uuid, 'authenticated', 'authenticated',
  'customer-000168@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Joshi", "phone": "9833926013", "address": "#299, Block 5, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "31edd6db-8d15-5b62-81db-9c9421f65731"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b75506f1-de34-55c4-8ee9-d4a19d12aea9'::uuid, 'Meena Joshi', 'cust-168', 'customer-000168@aplibhaji.com', '#299, Block 5, MG Road 4, West End Enclave', 'CUSTOMER-000168',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '31edd6db-8d15-5b62-81db-9c9421f65731'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f1328680-9df7-58fe-9460-8f888249ea2c'::uuid, 'authenticated', 'authenticated',
  'customer-000169@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Sharma", "phone": "9844362060", "address": "#200, Block 6, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "f3b97dae-0199-5202-ac8c-67118d48aee8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f1328680-9df7-58fe-9460-8f888249ea2c'::uuid, 'Ramesh Sharma', 'cust-169', 'customer-000169@aplibhaji.com', '#200, Block 6, MG Road 4, West End Enclave', 'CUSTOMER-000169',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, 'f3b97dae-0199-5202-ac8c-67118d48aee8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c6851d5a-28dd-51e3-889e-89a27709c083'::uuid, 'authenticated', 'authenticated',
  'customer-000170@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Gupta", "phone": "9831243654", "address": "#362, Block 1, MG Road 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "8d997165-c759-502e-ab84-c6ecb5a150b0", "sub_road_id": "90bb1b4a-2bab-5442-b83c-02c7ff1d674b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c6851d5a-28dd-51e3-889e-89a27709c083'::uuid, 'Rahul Gupta', 'cust-170', 'customer-000170@aplibhaji.com', '#362, Block 1, MG Road 4, West End Enclave', 'CUSTOMER-000170',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '8d997165-c759-502e-ab84-c6ecb5a150b0'::uuid, '90bb1b4a-2bab-5442-b83c-02c7ff1d674b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '29278b4a-8a5b-5f17-9f79-3b500f18cf50'::uuid, 'authenticated', 'authenticated',
  'customer-000171@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Kumar", "phone": "9891191390", "address": "#297, Block 3, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dbd27461-e8a3-5f8a-b823-be5c16971f8d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '29278b4a-8a5b-5f17-9f79-3b500f18cf50'::uuid, 'Vikram Kumar', 'cust-171', 'customer-000171@aplibhaji.com', '#297, Block 3, Station Street 4, West End Enclave', 'CUSTOMER-000171',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dbd27461-e8a3-5f8a-b823-be5c16971f8d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9e9fd12c-328d-539b-8241-4c5c0cf544b8'::uuid, 'authenticated', 'authenticated',
  'customer-000172@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Singh", "phone": "9873432499", "address": "#132, Block 6, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "656bd47f-64d7-57e9-b747-9ee6cda95ec9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9e9fd12c-328d-539b-8241-4c5c0cf544b8'::uuid, 'Rahul Singh', 'cust-172', 'customer-000172@aplibhaji.com', '#132, Block 6, Station Street 4, West End Enclave', 'CUSTOMER-000172',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, '656bd47f-64d7-57e9-b747-9ee6cda95ec9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cde77f28-1dc8-595d-91a1-19eba1ffc70a'::uuid, 'authenticated', 'authenticated',
  'customer-000173@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Nair", "phone": "9898043713", "address": "#328, Block 3, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dbd27461-e8a3-5f8a-b823-be5c16971f8d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cde77f28-1dc8-595d-91a1-19eba1ffc70a'::uuid, 'Ajay Nair', 'cust-173', 'customer-000173@aplibhaji.com', '#328, Block 3, Station Street 4, West End Enclave', 'CUSTOMER-000173',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dbd27461-e8a3-5f8a-b823-be5c16971f8d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6b8a7d4f-8c4f-5565-8af0-177d0ebc62f7'::uuid, 'authenticated', 'authenticated',
  'customer-000174@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Rao", "phone": "9813104400", "address": "#131, Block 2, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dd176b88-64ca-5f60-8e11-4512491f0c95"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6b8a7d4f-8c4f-5565-8af0-177d0ebc62f7'::uuid, 'Amit Rao', 'cust-174', 'customer-000174@aplibhaji.com', '#131, Block 2, Station Street 4, West End Enclave', 'CUSTOMER-000174',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dd176b88-64ca-5f60-8e11-4512491f0c95'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '72c55a1e-1f2d-5428-8d18-f3ce17bc2764'::uuid, 'authenticated', 'authenticated',
  'customer-000175@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Nair", "phone": "9891701044", "address": "#392, Block 7, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dd82701a-21a7-5cc1-b1c1-65986eb9a656"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '72c55a1e-1f2d-5428-8d18-f3ce17bc2764'::uuid, 'Vikram Nair', 'cust-175', 'customer-000175@aplibhaji.com', '#392, Block 7, Station Street 4, West End Enclave', 'CUSTOMER-000175',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dd82701a-21a7-5cc1-b1c1-65986eb9a656'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '207f3062-d108-562e-bb84-a55fbbc0b54f'::uuid, 'authenticated', 'authenticated',
  'customer-000176@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Gupta", "phone": "9883401392", "address": "#209, Block 5, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "6e2f69df-7fb7-5f3b-8bd3-5374acb88452"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '207f3062-d108-562e-bb84-a55fbbc0b54f'::uuid, 'Sanjay Gupta', 'cust-176', 'customer-000176@aplibhaji.com', '#209, Block 5, Station Street 4, West End Enclave', 'CUSTOMER-000176',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, '6e2f69df-7fb7-5f3b-8bd3-5374acb88452'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4874d5d6-8f7a-5c97-abcc-8c36613a924b'::uuid, 'authenticated', 'authenticated',
  'customer-000177@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Joshi", "phone": "9871345063", "address": "#171, Block 7, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dd82701a-21a7-5cc1-b1c1-65986eb9a656"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4874d5d6-8f7a-5c97-abcc-8c36613a924b'::uuid, 'Anita Joshi', 'cust-177', 'customer-000177@aplibhaji.com', '#171, Block 7, Station Street 4, West End Enclave', 'CUSTOMER-000177',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dd82701a-21a7-5cc1-b1c1-65986eb9a656'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '24f55285-3da8-570c-beb9-d8e880648334'::uuid, 'authenticated', 'authenticated',
  'customer-000178@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Rao", "phone": "9875534453", "address": "#102, Block 2, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dd176b88-64ca-5f60-8e11-4512491f0c95"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '24f55285-3da8-570c-beb9-d8e880648334'::uuid, 'Sunita Rao', 'cust-178', 'customer-000178@aplibhaji.com', '#102, Block 2, Station Street 4, West End Enclave', 'CUSTOMER-000178',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dd176b88-64ca-5f60-8e11-4512491f0c95'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dab085ff-49e9-5438-b419-2b8ae9318c6e'::uuid, 'authenticated', 'authenticated',
  'customer-000179@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Deshmukh", "phone": "9888741924", "address": "#168, Block 3, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "dbd27461-e8a3-5f8a-b823-be5c16971f8d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dab085ff-49e9-5438-b419-2b8ae9318c6e'::uuid, 'Geeta Deshmukh', 'cust-179', 'customer-000179@aplibhaji.com', '#168, Block 3, Station Street 4, West End Enclave', 'CUSTOMER-000179',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'dbd27461-e8a3-5f8a-b823-be5c16971f8d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '575dd089-9e0f-59cf-93ff-4faf9f72d85d'::uuid, 'authenticated', 'authenticated',
  'customer-000180@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Agarwal", "phone": "9840865122", "address": "#274, Block 8, Station Street 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "3b8cfde1-a601-511c-901f-6ce55169b233", "sub_road_id": "bf6ee8af-4094-5ef0-925f-d85253bf0ac3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '575dd089-9e0f-59cf-93ff-4faf9f72d85d'::uuid, 'Geeta Agarwal', 'cust-180', 'customer-000180@aplibhaji.com', '#274, Block 8, Station Street 4, West End Enclave', 'CUSTOMER-000180',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '3b8cfde1-a601-511c-901f-6ce55169b233'::uuid, 'bf6ee8af-4094-5ef0-925f-d85253bf0ac3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '31ca962f-7fd2-5245-b3fe-fa63ecea0737'::uuid, 'authenticated', 'authenticated',
  'customer-000181@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Sharma", "phone": "9877969938", "address": "#273, Block 1, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "a7e36d0c-f67a-593f-b00d-4d6e32e1b3a1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '31ca962f-7fd2-5245-b3fe-fa63ecea0737'::uuid, 'Deepak Sharma', 'cust-181', 'customer-000181@aplibhaji.com', '#273, Block 1, Park Avenue 4, West End Enclave', 'CUSTOMER-000181',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'a7e36d0c-f67a-593f-b00d-4d6e32e1b3a1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7f63e6fd-463c-5dda-9688-1e4c056952f7'::uuid, 'authenticated', 'authenticated',
  'customer-000182@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Verma", "phone": "9869349951", "address": "#146, Block 8, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "fc6482fe-1356-594a-9cb6-56bdf0f2d4b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7f63e6fd-463c-5dda-9688-1e4c056952f7'::uuid, 'Rahul Verma', 'cust-182', 'customer-000182@aplibhaji.com', '#146, Block 8, Park Avenue 4, West End Enclave', 'CUSTOMER-000182',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '187bb014-378b-5eb3-bd15-3223666f8d94'::uuid, 'authenticated', 'authenticated',
  'customer-000183@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Rao", "phone": "9898195576", "address": "#269, Block 8, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "fc6482fe-1356-594a-9cb6-56bdf0f2d4b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '187bb014-378b-5eb3-bd15-3223666f8d94'::uuid, 'Priya Rao', 'cust-183', 'customer-000183@aplibhaji.com', '#269, Block 8, Park Avenue 4, West End Enclave', 'CUSTOMER-000183',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '395b31a4-a59e-5f25-9c8c-eff42630375d'::uuid, 'authenticated', 'authenticated',
  'customer-000184@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Gupta", "phone": "9894795962", "address": "#293, Block 1, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "a7e36d0c-f67a-593f-b00d-4d6e32e1b3a1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '395b31a4-a59e-5f25-9c8c-eff42630375d'::uuid, 'Pooja Gupta', 'cust-184', 'customer-000184@aplibhaji.com', '#293, Block 1, Park Avenue 4, West End Enclave', 'CUSTOMER-000184',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'a7e36d0c-f67a-593f-b00d-4d6e32e1b3a1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9022ac39-0004-5714-bf2b-3ac5357f6e24'::uuid, 'authenticated', 'authenticated',
  'customer-000185@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Rao", "phone": "9839205143", "address": "#154, Block 3, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "0f193e98-1383-5b6a-9836-b2dfc60a3e40"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9022ac39-0004-5714-bf2b-3ac5357f6e24'::uuid, 'Vikram Rao', 'cust-185', 'customer-000185@aplibhaji.com', '#154, Block 3, Park Avenue 4, West End Enclave', 'CUSTOMER-000185',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, '0f193e98-1383-5b6a-9836-b2dfc60a3e40'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5db84879-986c-52fd-9341-781aad0b235d'::uuid, 'authenticated', 'authenticated',
  'customer-000186@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Chawla", "phone": "9869865105", "address": "#302, Block 5, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "e2a5a33c-5f05-54b9-baa1-c5b01aa890d2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5db84879-986c-52fd-9341-781aad0b235d'::uuid, 'Anita Chawla', 'cust-186', 'customer-000186@aplibhaji.com', '#302, Block 5, Park Avenue 4, West End Enclave', 'CUSTOMER-000186',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'e2a5a33c-5f05-54b9-baa1-c5b01aa890d2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'af0e9419-9d56-5e4d-b16a-09a673271aec'::uuid, 'authenticated', 'authenticated',
  'customer-000187@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Jain", "phone": "9885822294", "address": "#369, Block 8, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "fc6482fe-1356-594a-9cb6-56bdf0f2d4b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'af0e9419-9d56-5e4d-b16a-09a673271aec'::uuid, 'Amit Jain', 'cust-187', 'customer-000187@aplibhaji.com', '#369, Block 8, Park Avenue 4, West End Enclave', 'CUSTOMER-000187',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b49bcd7c-a01b-5806-80fe-e65966c7defe'::uuid, 'authenticated', 'authenticated',
  'customer-000188@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Kulkarni", "phone": "9874735346", "address": "#298, Block 6, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "33b376c8-6c8d-5086-8769-ca00a0458c72"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b49bcd7c-a01b-5806-80fe-e65966c7defe'::uuid, 'Amit Kulkarni', 'cust-188', 'customer-000188@aplibhaji.com', '#298, Block 6, Park Avenue 4, West End Enclave', 'CUSTOMER-000188',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, '33b376c8-6c8d-5086-8769-ca00a0458c72'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'bf65ca21-f475-5bf3-9799-a0a818464cea'::uuid, 'authenticated', 'authenticated',
  'customer-000189@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Singh", "phone": "9862001248", "address": "#273, Block 8, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "fc6482fe-1356-594a-9cb6-56bdf0f2d4b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'bf65ca21-f475-5bf3-9799-a0a818464cea'::uuid, 'Rohan Singh', 'cust-189', 'customer-000189@aplibhaji.com', '#273, Block 8, Park Avenue 4, West End Enclave', 'CUSTOMER-000189',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '406f2c38-e812-57e7-9696-033a4da8e9c9'::uuid, 'authenticated', 'authenticated',
  'customer-000190@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Kumar", "phone": "9856891744", "address": "#391, Block 8, Park Avenue 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "6ec9ef28-0996-5e64-8586-8286a884b49d", "sub_road_id": "fc6482fe-1356-594a-9cb6-56bdf0f2d4b8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '406f2c38-e812-57e7-9696-033a4da8e9c9'::uuid, 'Manish Kumar', 'cust-190', 'customer-000190@aplibhaji.com', '#391, Block 8, Park Avenue 4, West End Enclave', 'CUSTOMER-000190',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '6ec9ef28-0996-5e64-8586-8286a884b49d'::uuid, 'fc6482fe-1356-594a-9cb6-56bdf0f2d4b8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ba06c231-ee8a-56b7-bc5f-6b6a4698b868'::uuid, 'authenticated', 'authenticated',
  'customer-000191@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Joshi", "phone": "9854067050", "address": "#335, Block 8, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ba06c231-ee8a-56b7-bc5f-6b6a4698b868'::uuid, 'Suresh Joshi', 'cust-191', 'customer-000191@aplibhaji.com', '#335, Block 8, Green Lane 4, West End Enclave', 'CUSTOMER-000191',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '92661397-031a-569b-bdf9-d6c0c37d550f'::uuid, 'authenticated', 'authenticated',
  'customer-000192@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Patel", "phone": "9888707184", "address": "#375, Block 3, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "51ed8a57-6d6b-5199-bc39-830dccd63fb6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '92661397-031a-569b-bdf9-d6c0c37d550f'::uuid, 'Amit Patel', 'cust-192', 'customer-000192@aplibhaji.com', '#375, Block 3, Green Lane 4, West End Enclave', 'CUSTOMER-000192',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '51ed8a57-6d6b-5199-bc39-830dccd63fb6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9345b387-892f-547c-b525-fda9ff1269c1'::uuid, 'authenticated', 'authenticated',
  'customer-000193@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Sharma", "phone": "9881747143", "address": "#138, Block 3, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "51ed8a57-6d6b-5199-bc39-830dccd63fb6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9345b387-892f-547c-b525-fda9ff1269c1'::uuid, 'Pooja Sharma', 'cust-193', 'customer-000193@aplibhaji.com', '#138, Block 3, Green Lane 4, West End Enclave', 'CUSTOMER-000193',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '51ed8a57-6d6b-5199-bc39-830dccd63fb6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0180734f-4b46-51f4-b003-adb487339351'::uuid, 'authenticated', 'authenticated',
  'customer-000194@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Gupta", "phone": "9830076109", "address": "#179, Block 7, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "60acc646-7e20-5718-be9a-5a46a3a2bb77"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0180734f-4b46-51f4-b003-adb487339351'::uuid, 'Geeta Gupta', 'cust-194', 'customer-000194@aplibhaji.com', '#179, Block 7, Green Lane 4, West End Enclave', 'CUSTOMER-000194',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '60acc646-7e20-5718-be9a-5a46a3a2bb77'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0069d94f-be80-54c0-a46a-909cb025f368'::uuid, 'authenticated', 'authenticated',
  'customer-000195@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Patel", "phone": "9862977119", "address": "#116, Block 8, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0069d94f-be80-54c0-a46a-909cb025f368'::uuid, 'Vikram Patel', 'cust-195', 'customer-000195@aplibhaji.com', '#116, Block 8, Green Lane 4, West End Enclave', 'CUSTOMER-000195',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2e294051-2302-55da-8772-eb864f325010'::uuid, 'authenticated', 'authenticated',
  'customer-000196@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Reddy", "phone": "9862023146", "address": "#343, Block 8, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2e294051-2302-55da-8772-eb864f325010'::uuid, 'Geeta Reddy', 'cust-196', 'customer-000196@aplibhaji.com', '#343, Block 8, Green Lane 4, West End Enclave', 'CUSTOMER-000196',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '42f7a9e3-0dbd-53a9-82d1-9671d4aa05cd'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4a054e34-f660-5996-8f01-1aa25c9fa62d'::uuid, 'authenticated', 'authenticated',
  'customer-000197@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Sharma", "phone": "9845302880", "address": "#104, Block 3, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "51ed8a57-6d6b-5199-bc39-830dccd63fb6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4a054e34-f660-5996-8f01-1aa25c9fa62d'::uuid, 'Geeta Sharma', 'cust-197', 'customer-000197@aplibhaji.com', '#104, Block 3, Green Lane 4, West End Enclave', 'CUSTOMER-000197',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '51ed8a57-6d6b-5199-bc39-830dccd63fb6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '38d1eba4-a6b9-5eac-994b-7f2ad03d15e7'::uuid, 'authenticated', 'authenticated',
  'customer-000198@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Mehta", "phone": "9888887485", "address": "#166, Block 4, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "c60fb7ab-dd8d-5c31-a1aa-fb434eef6ff5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '38d1eba4-a6b9-5eac-994b-7f2ad03d15e7'::uuid, 'Amit Mehta', 'cust-198', 'customer-000198@aplibhaji.com', '#166, Block 4, Green Lane 4, West End Enclave', 'CUSTOMER-000198',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, 'c60fb7ab-dd8d-5c31-a1aa-fb434eef6ff5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '157caa3c-0842-57b1-b7b5-557683d06f61'::uuid, 'authenticated', 'authenticated',
  'customer-000199@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Agarwal", "phone": "9837335659", "address": "#178, Block 5, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "2c39f865-b40a-57a9-adf8-fe05f128fec3"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '157caa3c-0842-57b1-b7b5-557683d06f61'::uuid, 'Manish Agarwal', 'cust-199', 'customer-000199@aplibhaji.com', '#178, Block 5, Green Lane 4, West End Enclave', 'CUSTOMER-000199',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '2c39f865-b40a-57a9-adf8-fe05f128fec3'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0532b632-0dcd-540f-8209-ca07bdc012ba'::uuid, 'authenticated', 'authenticated',
  'customer-000200@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Sharma", "phone": "9812800122", "address": "#251, Block 7, Green Lane 4, West End Enclave", "area_id": "9963692f-e1b2-5938-9bfa-a83ddadd1b7e", "road_id": "26892f4a-a26d-5148-88dd-b739763d75f0", "sub_road_id": "60acc646-7e20-5718-be9a-5a46a3a2bb77"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0532b632-0dcd-540f-8209-ca07bdc012ba'::uuid, 'Kavita Sharma', 'cust-200', 'customer-000200@aplibhaji.com', '#251, Block 7, Green Lane 4, West End Enclave', 'CUSTOMER-000200',
  '9963692f-e1b2-5938-9bfa-a83ddadd1b7e'::uuid, '26892f4a-a26d-5148-88dd-b739763d75f0'::uuid, '60acc646-7e20-5718-be9a-5a46a3a2bb77'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '30779468-e9e8-5088-824e-ad22a633b2aa'::uuid, 'authenticated', 'authenticated',
  'customer-000201@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Joshi", "phone": "9866560799", "address": "#262, Block 6, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "902f7c9f-1b2b-5745-8202-1ba42d2b5e4b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '30779468-e9e8-5088-824e-ad22a633b2aa'::uuid, 'Swati Joshi', 'cust-201', 'customer-000201@aplibhaji.com', '#262, Block 6, Market Road 5, Central Business Hub', 'CUSTOMER-000201',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '902f7c9f-1b2b-5745-8202-1ba42d2b5e4b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '31e153c3-a38b-5311-b455-055052b60570'::uuid, 'authenticated', 'authenticated',
  'customer-000202@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Patel", "phone": "9891592078", "address": "#393, Block 1, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "b2dae5f5-aab9-507a-ad05-bc3c2ff24b34"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '31e153c3-a38b-5311-b455-055052b60570'::uuid, 'Rohan Patel', 'cust-202', 'customer-000202@aplibhaji.com', '#393, Block 1, Market Road 5, Central Business Hub', 'CUSTOMER-000202',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'b2dae5f5-aab9-507a-ad05-bc3c2ff24b34'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1ae39006-7e00-5ecd-b691-18d1ed8c03d6'::uuid, 'authenticated', 'authenticated',
  'customer-000203@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Joshi", "phone": "9879560325", "address": "#229, Block 6, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "902f7c9f-1b2b-5745-8202-1ba42d2b5e4b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1ae39006-7e00-5ecd-b691-18d1ed8c03d6'::uuid, 'Deepak Joshi', 'cust-203', 'customer-000203@aplibhaji.com', '#229, Block 6, Market Road 5, Central Business Hub', 'CUSTOMER-000203',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '902f7c9f-1b2b-5745-8202-1ba42d2b5e4b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd2fe8744-05b5-519b-91b4-508003caa5aa'::uuid, 'authenticated', 'authenticated',
  'customer-000204@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Jain", "phone": "9848445841", "address": "#193, Block 7, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "7e507346-e2a0-52db-91aa-780b1b799bff"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd2fe8744-05b5-519b-91b4-508003caa5aa'::uuid, 'Vijay Jain', 'cust-204', 'customer-000204@aplibhaji.com', '#193, Block 7, Market Road 5, Central Business Hub', 'CUSTOMER-000204',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '7e507346-e2a0-52db-91aa-780b1b799bff'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9490e63d-63c8-5119-975f-f6ef9b3a90d6'::uuid, 'authenticated', 'authenticated',
  'customer-000205@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Nair", "phone": "9827906601", "address": "#240, Block 2, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "3fad5aa3-3c52-5257-8199-334398712f4f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9490e63d-63c8-5119-975f-f6ef9b3a90d6'::uuid, 'Manish Nair', 'cust-205', 'customer-000205@aplibhaji.com', '#240, Block 2, Market Road 5, Central Business Hub', 'CUSTOMER-000205',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '3fad5aa3-3c52-5257-8199-334398712f4f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b0d3e455-d165-5ffe-8998-db74a11e0c58'::uuid, 'authenticated', 'authenticated',
  'customer-000206@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Chawla", "phone": "9824064152", "address": "#166, Block 5, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "6f039085-20fd-55d6-b8b0-1212695b2eea"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b0d3e455-d165-5ffe-8998-db74a11e0c58'::uuid, 'Amit Chawla', 'cust-206', 'customer-000206@aplibhaji.com', '#166, Block 5, Market Road 5, Central Business Hub', 'CUSTOMER-000206',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '6f039085-20fd-55d6-b8b0-1212695b2eea'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fafe94c7-5057-5a38-9faf-c7a2f9f874fa'::uuid, 'authenticated', 'authenticated',
  'customer-000207@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Deshmukh", "phone": "9831039454", "address": "#299, Block 4, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "a96aaa19-7140-5e78-877e-ea747b12996e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fafe94c7-5057-5a38-9faf-c7a2f9f874fa'::uuid, 'Rahul Deshmukh', 'cust-207', 'customer-000207@aplibhaji.com', '#299, Block 4, Market Road 5, Central Business Hub', 'CUSTOMER-000207',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, 'a96aaa19-7140-5e78-877e-ea747b12996e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7a7f6335-3584-5597-a922-856014159b9c'::uuid, 'authenticated', 'authenticated',
  'customer-000208@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Agarwal", "phone": "9813313388", "address": "#312, Block 5, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "6f039085-20fd-55d6-b8b0-1212695b2eea"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7a7f6335-3584-5597-a922-856014159b9c'::uuid, 'Anita Agarwal', 'cust-208', 'customer-000208@aplibhaji.com', '#312, Block 5, Market Road 5, Central Business Hub', 'CUSTOMER-000208',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '6f039085-20fd-55d6-b8b0-1212695b2eea'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f798d548-ebfb-51f9-a383-61383e1a9a05'::uuid, 'authenticated', 'authenticated',
  'customer-000209@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Joshi", "phone": "9836026296", "address": "#115, Block 5, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "6f039085-20fd-55d6-b8b0-1212695b2eea"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f798d548-ebfb-51f9-a383-61383e1a9a05'::uuid, 'Sunita Joshi', 'cust-209', 'customer-000209@aplibhaji.com', '#115, Block 5, Market Road 5, Central Business Hub', 'CUSTOMER-000209',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '6f039085-20fd-55d6-b8b0-1212695b2eea'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '97d041ca-bacb-5f1f-8c79-94f56a022df6'::uuid, 'authenticated', 'authenticated',
  'customer-000210@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Kulkarni", "phone": "9877134927", "address": "#102, Block 3, Market Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "cc92d7e0-4d41-5ede-903c-b3dccb13b57b", "sub_road_id": "89b50c3e-b470-51b4-baab-28eb8d3d6c35"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '97d041ca-bacb-5f1f-8c79-94f56a022df6'::uuid, 'Sneha Kulkarni', 'cust-210', 'customer-000210@aplibhaji.com', '#102, Block 3, Market Road 5, Central Business Hub', 'CUSTOMER-000210',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, 'cc92d7e0-4d41-5ede-903c-b3dccb13b57b'::uuid, '89b50c3e-b470-51b4-baab-28eb8d3d6c35'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7292a109-2bd7-5b12-8fd7-70658d803b7f'::uuid, 'authenticated', 'authenticated',
  'customer-000211@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Sharma", "phone": "9893538024", "address": "#195, Block 3, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "7c9bfe22-663e-5ad6-994b-9bc2831de66e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7292a109-2bd7-5b12-8fd7-70658d803b7f'::uuid, 'Amit Sharma', 'cust-211', 'customer-000211@aplibhaji.com', '#195, Block 3, MG Road 5, Central Business Hub', 'CUSTOMER-000211',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '7c9bfe22-663e-5ad6-994b-9bc2831de66e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '48e31340-7d11-5299-8317-4d0c4bc03dbf'::uuid, 'authenticated', 'authenticated',
  'customer-000212@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Agarwal", "phone": "9872176768", "address": "#345, Block 2, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "643c1ae6-ee79-586e-ad58-aaf327e678b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '48e31340-7d11-5299-8317-4d0c4bc03dbf'::uuid, 'Sanjay Agarwal', 'cust-212', 'customer-000212@aplibhaji.com', '#345, Block 2, MG Road 5, Central Business Hub', 'CUSTOMER-000212',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '643c1ae6-ee79-586e-ad58-aaf327e678b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a1a8f5cd-959d-5cd1-af3b-6803a6ae6dba'::uuid, 'authenticated', 'authenticated',
  'customer-000213@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Jain", "phone": "9821804658", "address": "#342, Block 1, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "b9df424e-61c6-50c5-8940-0c1a6bc27068"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a1a8f5cd-959d-5cd1-af3b-6803a6ae6dba'::uuid, 'Rahul Jain', 'cust-213', 'customer-000213@aplibhaji.com', '#342, Block 1, MG Road 5, Central Business Hub', 'CUSTOMER-000213',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, 'b9df424e-61c6-50c5-8940-0c1a6bc27068'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f7dfefbe-f462-5a4c-93d3-037f44d39cdd'::uuid, 'authenticated', 'authenticated',
  'customer-000214@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Kumar", "phone": "9899970805", "address": "#316, Block 6, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "5cf1a001-1f17-5af1-9961-3efd7ecfa28d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f7dfefbe-f462-5a4c-93d3-037f44d39cdd'::uuid, 'Arun Kumar', 'cust-214', 'customer-000214@aplibhaji.com', '#316, Block 6, MG Road 5, Central Business Hub', 'CUSTOMER-000214',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '5cf1a001-1f17-5af1-9961-3efd7ecfa28d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a3ab9c6d-6e5e-515f-b2c2-1303dc6fc1db'::uuid, 'authenticated', 'authenticated',
  'customer-000215@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Joshi", "phone": "9873114213", "address": "#132, Block 4, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "56f85075-aeab-5069-afbe-eeb4f9be100d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a3ab9c6d-6e5e-515f-b2c2-1303dc6fc1db'::uuid, 'Amit Joshi', 'cust-215', 'customer-000215@aplibhaji.com', '#132, Block 4, MG Road 5, Central Business Hub', 'CUSTOMER-000215',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '56f85075-aeab-5069-afbe-eeb4f9be100d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ca2bdcc4-1a9e-55f7-8b05-908d0384b6e9'::uuid, 'authenticated', 'authenticated',
  'customer-000216@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Reddy", "phone": "9859036828", "address": "#324, Block 5, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "980be9ec-5854-5053-b768-9ec3c181b376"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ca2bdcc4-1a9e-55f7-8b05-908d0384b6e9'::uuid, 'Neha Reddy', 'cust-216', 'customer-000216@aplibhaji.com', '#324, Block 5, MG Road 5, Central Business Hub', 'CUSTOMER-000216',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '980be9ec-5854-5053-b768-9ec3c181b376'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '084c702c-33ea-5ac7-94e3-27f8ca11686b'::uuid, 'authenticated', 'authenticated',
  'customer-000217@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Agarwal", "phone": "9868630243", "address": "#174, Block 7, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "15201ef2-e936-5925-bb8a-ebbc62a1a398"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '084c702c-33ea-5ac7-94e3-27f8ca11686b'::uuid, 'Ramesh Agarwal', 'cust-217', 'customer-000217@aplibhaji.com', '#174, Block 7, MG Road 5, Central Business Hub', 'CUSTOMER-000217',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '15201ef2-e936-5925-bb8a-ebbc62a1a398'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c3b23ad7-add7-5c9d-83ce-f8098b8f3626'::uuid, 'authenticated', 'authenticated',
  'customer-000218@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Joshi", "phone": "9893371242", "address": "#266, Block 3, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "7c9bfe22-663e-5ad6-994b-9bc2831de66e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c3b23ad7-add7-5c9d-83ce-f8098b8f3626'::uuid, 'Swati Joshi', 'cust-218', 'customer-000218@aplibhaji.com', '#266, Block 3, MG Road 5, Central Business Hub', 'CUSTOMER-000218',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '7c9bfe22-663e-5ad6-994b-9bc2831de66e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c8324edf-651a-5657-9236-6c726211aa41'::uuid, 'authenticated', 'authenticated',
  'customer-000219@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Gupta", "phone": "9855512763", "address": "#174, Block 2, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "643c1ae6-ee79-586e-ad58-aaf327e678b5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c8324edf-651a-5657-9236-6c726211aa41'::uuid, 'Ramesh Gupta', 'cust-219', 'customer-000219@aplibhaji.com', '#174, Block 2, MG Road 5, Central Business Hub', 'CUSTOMER-000219',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '643c1ae6-ee79-586e-ad58-aaf327e678b5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '17b86343-c3ef-531b-8024-a62ad86b456b'::uuid, 'authenticated', 'authenticated',
  'customer-000220@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Kumar", "phone": "9838794722", "address": "#353, Block 3, MG Road 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "288b8231-5ccf-558a-b915-6ae02d3b0079", "sub_road_id": "7c9bfe22-663e-5ad6-994b-9bc2831de66e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '17b86343-c3ef-531b-8024-a62ad86b456b'::uuid, 'Deepak Kumar', 'cust-220', 'customer-000220@aplibhaji.com', '#353, Block 3, MG Road 5, Central Business Hub', 'CUSTOMER-000220',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '288b8231-5ccf-558a-b915-6ae02d3b0079'::uuid, '7c9bfe22-663e-5ad6-994b-9bc2831de66e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ab66f939-584f-51fc-80f6-d6be9018c2ed'::uuid, 'authenticated', 'authenticated',
  'customer-000221@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Rao", "phone": "9853020101", "address": "#177, Block 4, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "6ac8c80d-32fc-5696-af81-a556029ce605"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ab66f939-584f-51fc-80f6-d6be9018c2ed'::uuid, 'Pooja Rao', 'cust-221', 'customer-000221@aplibhaji.com', '#177, Block 4, Station Street 5, Central Business Hub', 'CUSTOMER-000221',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, '6ac8c80d-32fc-5696-af81-a556029ce605'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5f72c7f4-5c0e-5c6d-bb3e-1ac474e41873'::uuid, 'authenticated', 'authenticated',
  'customer-000222@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Patel", "phone": "9816089786", "address": "#345, Block 3, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "3ab32271-6fa0-531b-83bf-6f6b829090e7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5f72c7f4-5c0e-5c6d-bb3e-1ac474e41873'::uuid, 'Geeta Patel', 'cust-222', 'customer-000222@aplibhaji.com', '#345, Block 3, Station Street 5, Central Business Hub', 'CUSTOMER-000222',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, '3ab32271-6fa0-531b-83bf-6f6b829090e7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c6916e4f-bb56-5f08-acd3-ba74fbd0e204'::uuid, 'authenticated', 'authenticated',
  'customer-000223@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Verma", "phone": "9824539615", "address": "#109, Block 6, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "b3e34dac-e5fc-50a8-8c47-0cfe0648b408"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c6916e4f-bb56-5f08-acd3-ba74fbd0e204'::uuid, 'Rahul Verma', 'cust-223', 'customer-000223@aplibhaji.com', '#109, Block 6, Station Street 5, Central Business Hub', 'CUSTOMER-000223',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'b3e34dac-e5fc-50a8-8c47-0cfe0648b408'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6678557e-876c-5e2b-a20b-cf1119835d9f'::uuid, 'authenticated', 'authenticated',
  'customer-000224@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Agarwal", "phone": "9851074669", "address": "#367, Block 4, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "6ac8c80d-32fc-5696-af81-a556029ce605"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6678557e-876c-5e2b-a20b-cf1119835d9f'::uuid, 'Ajay Agarwal', 'cust-224', 'customer-000224@aplibhaji.com', '#367, Block 4, Station Street 5, Central Business Hub', 'CUSTOMER-000224',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, '6ac8c80d-32fc-5696-af81-a556029ce605'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '76cc0166-3b3c-555c-9e45-6c5f5acbbfcf'::uuid, 'authenticated', 'authenticated',
  'customer-000225@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Kumar", "phone": "9870577375", "address": "#331, Block 3, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "3ab32271-6fa0-531b-83bf-6f6b829090e7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '76cc0166-3b3c-555c-9e45-6c5f5acbbfcf'::uuid, 'Meena Kumar', 'cust-225', 'customer-000225@aplibhaji.com', '#331, Block 3, Station Street 5, Central Business Hub', 'CUSTOMER-000225',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, '3ab32271-6fa0-531b-83bf-6f6b829090e7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ca926b12-0073-51f8-903f-1c033e890756'::uuid, 'authenticated', 'authenticated',
  'customer-000226@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Rao", "phone": "9849001394", "address": "#389, Block 1, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "84369228-d22d-51a1-8b81-03a23ee28866"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ca926b12-0073-51f8-903f-1c033e890756'::uuid, 'Manish Rao', 'cust-226', 'customer-000226@aplibhaji.com', '#389, Block 1, Station Street 5, Central Business Hub', 'CUSTOMER-000226',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, '84369228-d22d-51a1-8b81-03a23ee28866'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6e65b5c2-d172-569f-8464-c90861f5595d'::uuid, 'authenticated', 'authenticated',
  'customer-000227@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Joshi", "phone": "9822690553", "address": "#292, Block 5, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "f835a007-d34f-586c-ba44-66ab03027863"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6e65b5c2-d172-569f-8464-c90861f5595d'::uuid, 'Vikram Joshi', 'cust-227', 'customer-000227@aplibhaji.com', '#292, Block 5, Station Street 5, Central Business Hub', 'CUSTOMER-000227',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'f835a007-d34f-586c-ba44-66ab03027863'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b0b45adc-590b-5f8c-9b2b-cb366be05e76'::uuid, 'authenticated', 'authenticated',
  'customer-000228@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Kulkarni", "phone": "9871492785", "address": "#304, Block 6, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "b3e34dac-e5fc-50a8-8c47-0cfe0648b408"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b0b45adc-590b-5f8c-9b2b-cb366be05e76'::uuid, 'Vijay Kulkarni', 'cust-228', 'customer-000228@aplibhaji.com', '#304, Block 6, Station Street 5, Central Business Hub', 'CUSTOMER-000228',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'b3e34dac-e5fc-50a8-8c47-0cfe0648b408'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4744376c-de30-5d37-95d1-168282a9414e'::uuid, 'authenticated', 'authenticated',
  'customer-000229@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Patel", "phone": "9881616509", "address": "#200, Block 6, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "b3e34dac-e5fc-50a8-8c47-0cfe0648b408"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4744376c-de30-5d37-95d1-168282a9414e'::uuid, 'Neha Patel', 'cust-229', 'customer-000229@aplibhaji.com', '#200, Block 6, Station Street 5, Central Business Hub', 'CUSTOMER-000229',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'b3e34dac-e5fc-50a8-8c47-0cfe0648b408'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f9aa1f3f-bec3-5869-832b-ac8bbf284bd8'::uuid, 'authenticated', 'authenticated',
  'customer-000230@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Rao", "phone": "9861070659", "address": "#182, Block 8, Station Street 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "2df52c03-5a6c-5312-9685-f1cafb6c6601", "sub_road_id": "de12e01b-5c06-59bf-8665-ec3db544988f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f9aa1f3f-bec3-5869-832b-ac8bbf284bd8'::uuid, 'Ajay Rao', 'cust-230', 'customer-000230@aplibhaji.com', '#182, Block 8, Station Street 5, Central Business Hub', 'CUSTOMER-000230',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '2df52c03-5a6c-5312-9685-f1cafb6c6601'::uuid, 'de12e01b-5c06-59bf-8665-ec3db544988f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '81c434d0-ad39-5d84-a0f1-534ec46df6fe'::uuid, 'authenticated', 'authenticated',
  'customer-000231@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Joshi", "phone": "9867063391", "address": "#300, Block 5, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "4f0063bd-53b4-5ed0-9d62-716410f46947"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '81c434d0-ad39-5d84-a0f1-534ec46df6fe'::uuid, 'Anita Joshi', 'cust-231', 'customer-000231@aplibhaji.com', '#300, Block 5, Park Avenue 5, Central Business Hub', 'CUSTOMER-000231',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '4f0063bd-53b4-5ed0-9d62-716410f46947'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '59550dbf-a411-5ab1-ab25-e44f05f37bad'::uuid, 'authenticated', 'authenticated',
  'customer-000232@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Rao", "phone": "9821053518", "address": "#325, Block 1, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "a84df336-e632-559e-86c6-613fd4fc966a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '59550dbf-a411-5ab1-ab25-e44f05f37bad'::uuid, 'Sunita Rao', 'cust-232', 'customer-000232@aplibhaji.com', '#325, Block 1, Park Avenue 5, Central Business Hub', 'CUSTOMER-000232',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, 'a84df336-e632-559e-86c6-613fd4fc966a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fa31639f-f14a-5bcc-a153-f04aeaa865db'::uuid, 'authenticated', 'authenticated',
  'customer-000233@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Verma", "phone": "9895295601", "address": "#196, Block 7, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "2fb4e837-8761-5903-b6a0-ff1fc6f1effa"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fa31639f-f14a-5bcc-a153-f04aeaa865db'::uuid, 'Swati Verma', 'cust-233', 'customer-000233@aplibhaji.com', '#196, Block 7, Park Avenue 5, Central Business Hub', 'CUSTOMER-000233',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '2fb4e837-8761-5903-b6a0-ff1fc6f1effa'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a5770390-4525-549f-995c-19f5195bb419'::uuid, 'authenticated', 'authenticated',
  'customer-000234@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Deshmukh", "phone": "9832638142", "address": "#304, Block 5, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "4f0063bd-53b4-5ed0-9d62-716410f46947"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a5770390-4525-549f-995c-19f5195bb419'::uuid, 'Vijay Deshmukh', 'cust-234', 'customer-000234@aplibhaji.com', '#304, Block 5, Park Avenue 5, Central Business Hub', 'CUSTOMER-000234',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '4f0063bd-53b4-5ed0-9d62-716410f46947'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1f2d6cdf-70bc-566e-b3de-b0c13f5f8243'::uuid, 'authenticated', 'authenticated',
  'customer-000235@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Patel", "phone": "9888038653", "address": "#266, Block 2, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "3a004e2a-02b3-59f4-bba1-bd5a37762b76"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1f2d6cdf-70bc-566e-b3de-b0c13f5f8243'::uuid, 'Deepak Patel', 'cust-235', 'customer-000235@aplibhaji.com', '#266, Block 2, Park Avenue 5, Central Business Hub', 'CUSTOMER-000235',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '3a004e2a-02b3-59f4-bba1-bd5a37762b76'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '04a8be70-eb4e-54fc-9802-e45bc75862d6'::uuid, 'authenticated', 'authenticated',
  'customer-000236@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Verma", "phone": "9892766564", "address": "#249, Block 5, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "4f0063bd-53b4-5ed0-9d62-716410f46947"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '04a8be70-eb4e-54fc-9802-e45bc75862d6'::uuid, 'Kavita Verma', 'cust-236', 'customer-000236@aplibhaji.com', '#249, Block 5, Park Avenue 5, Central Business Hub', 'CUSTOMER-000236',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '4f0063bd-53b4-5ed0-9d62-716410f46947'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fd5e2b99-cc4a-5137-afa8-55210de390eb'::uuid, 'authenticated', 'authenticated',
  'customer-000237@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Nair", "phone": "9812177301", "address": "#148, Block 8, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "289e83c7-788e-5c67-9042-e251099033aa"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fd5e2b99-cc4a-5137-afa8-55210de390eb'::uuid, 'Pooja Nair', 'cust-237', 'customer-000237@aplibhaji.com', '#148, Block 8, Park Avenue 5, Central Business Hub', 'CUSTOMER-000237',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '289e83c7-788e-5c67-9042-e251099033aa'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '117f7974-38cf-50c7-bcaf-13b1e892db08'::uuid, 'authenticated', 'authenticated',
  'customer-000238@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Nair", "phone": "9848036010", "address": "#171, Block 2, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "3a004e2a-02b3-59f4-bba1-bd5a37762b76"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '117f7974-38cf-50c7-bcaf-13b1e892db08'::uuid, 'Sunita Nair', 'cust-238', 'customer-000238@aplibhaji.com', '#171, Block 2, Park Avenue 5, Central Business Hub', 'CUSTOMER-000238',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '3a004e2a-02b3-59f4-bba1-bd5a37762b76'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c322e9a9-06ed-5def-908e-9a1cdcbe0141'::uuid, 'authenticated', 'authenticated',
  'customer-000239@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Sharma", "phone": "9880055452", "address": "#188, Block 5, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "4f0063bd-53b4-5ed0-9d62-716410f46947"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c322e9a9-06ed-5def-908e-9a1cdcbe0141'::uuid, 'Sneha Sharma', 'cust-239', 'customer-000239@aplibhaji.com', '#188, Block 5, Park Avenue 5, Central Business Hub', 'CUSTOMER-000239',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '4f0063bd-53b4-5ed0-9d62-716410f46947'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7269a4d4-dfc5-5a46-add3-3b7252d1cc80'::uuid, 'authenticated', 'authenticated',
  'customer-000240@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Chawla", "phone": "9825373729", "address": "#396, Block 2, Park Avenue 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "45624b37-7b61-5334-8e42-0e2c1a3a6d0f", "sub_road_id": "3a004e2a-02b3-59f4-bba1-bd5a37762b76"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7269a4d4-dfc5-5a46-add3-3b7252d1cc80'::uuid, 'Rahul Chawla', 'cust-240', 'customer-000240@aplibhaji.com', '#396, Block 2, Park Avenue 5, Central Business Hub', 'CUSTOMER-000240',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '45624b37-7b61-5334-8e42-0e2c1a3a6d0f'::uuid, '3a004e2a-02b3-59f4-bba1-bd5a37762b76'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c598b6e9-1d0d-5367-bf2c-669f7f33aa00'::uuid, 'authenticated', 'authenticated',
  'customer-000241@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Rao", "phone": "9865971189", "address": "#393, Block 7, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "9739083c-9112-5bfb-9481-2b1260ee86dc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c598b6e9-1d0d-5367-bf2c-669f7f33aa00'::uuid, 'Rajesh Rao', 'cust-241', 'customer-000241@aplibhaji.com', '#393, Block 7, Green Lane 5, Central Business Hub', 'CUSTOMER-000241',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, '9739083c-9112-5bfb-9481-2b1260ee86dc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '615f6de6-6582-509a-b8c6-9ced44a9992a'::uuid, 'authenticated', 'authenticated',
  'customer-000242@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Kulkarni", "phone": "9830282903", "address": "#357, Block 1, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "f0b8ae5a-dc42-5668-b275-279391af3fcc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '615f6de6-6582-509a-b8c6-9ced44a9992a'::uuid, 'Suresh Kulkarni', 'cust-242', 'customer-000242@aplibhaji.com', '#357, Block 1, Green Lane 5, Central Business Hub', 'CUSTOMER-000242',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'f0b8ae5a-dc42-5668-b275-279391af3fcc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '469f8e38-451a-5faf-9b86-0de15e28be03'::uuid, 'authenticated', 'authenticated',
  'customer-000243@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Deshmukh", "phone": "9820764632", "address": "#173, Block 3, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "a686f8c6-e2ff-5732-971a-582575fd9414"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '469f8e38-451a-5faf-9b86-0de15e28be03'::uuid, 'Rahul Deshmukh', 'cust-243', 'customer-000243@aplibhaji.com', '#173, Block 3, Green Lane 5, Central Business Hub', 'CUSTOMER-000243',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'a686f8c6-e2ff-5732-971a-582575fd9414'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '88c96432-4bae-5f08-a929-54c04e473cee'::uuid, 'authenticated', 'authenticated',
  'customer-000244@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Agarwal", "phone": "9845056234", "address": "#233, Block 6, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "a0621bda-9c7f-5920-b617-b50274615f0c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '88c96432-4bae-5f08-a929-54c04e473cee'::uuid, 'Amit Agarwal', 'cust-244', 'customer-000244@aplibhaji.com', '#233, Block 6, Green Lane 5, Central Business Hub', 'CUSTOMER-000244',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'a0621bda-9c7f-5920-b617-b50274615f0c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd74eb800-4b30-5d2e-a19d-fc501aa226e2'::uuid, 'authenticated', 'authenticated',
  'customer-000245@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Patel", "phone": "9844195021", "address": "#117, Block 3, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "a686f8c6-e2ff-5732-971a-582575fd9414"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd74eb800-4b30-5d2e-a19d-fc501aa226e2'::uuid, 'Amit Patel', 'cust-245', 'customer-000245@aplibhaji.com', '#117, Block 3, Green Lane 5, Central Business Hub', 'CUSTOMER-000245',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'a686f8c6-e2ff-5732-971a-582575fd9414'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9f24aaf4-d8ca-5e88-8dbb-4657e5ca6c0a'::uuid, 'authenticated', 'authenticated',
  'customer-000246@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Rao", "phone": "9872557311", "address": "#114, Block 4, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "45a5ed93-765d-5cfd-b5a4-7131b4353002"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9f24aaf4-d8ca-5e88-8dbb-4657e5ca6c0a'::uuid, 'Kavita Rao', 'cust-246', 'customer-000246@aplibhaji.com', '#114, Block 4, Green Lane 5, Central Business Hub', 'CUSTOMER-000246',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, '45a5ed93-765d-5cfd-b5a4-7131b4353002'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0bd93ed0-f415-5c02-97b0-6a34f13dd292'::uuid, 'authenticated', 'authenticated',
  'customer-000247@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Reddy", "phone": "9847855288", "address": "#120, Block 2, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "0b0a4ea4-9337-5cc4-9bf0-c44094e99b8e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0bd93ed0-f415-5c02-97b0-6a34f13dd292'::uuid, 'Arun Reddy', 'cust-247', 'customer-000247@aplibhaji.com', '#120, Block 2, Green Lane 5, Central Business Hub', 'CUSTOMER-000247',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, '0b0a4ea4-9337-5cc4-9bf0-c44094e99b8e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e412d677-96c6-5f1e-a429-c1bdc91aeb6a'::uuid, 'authenticated', 'authenticated',
  'customer-000248@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Agarwal", "phone": "9879214036", "address": "#378, Block 2, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "0b0a4ea4-9337-5cc4-9bf0-c44094e99b8e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e412d677-96c6-5f1e-a429-c1bdc91aeb6a'::uuid, 'Suresh Agarwal', 'cust-248', 'customer-000248@aplibhaji.com', '#378, Block 2, Green Lane 5, Central Business Hub', 'CUSTOMER-000248',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, '0b0a4ea4-9337-5cc4-9bf0-c44094e99b8e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8c4b9cb3-b313-51da-bac1-b986d1e13499'::uuid, 'authenticated', 'authenticated',
  'customer-000249@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Joshi", "phone": "9833418334", "address": "#179, Block 8, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "e89e9186-3ff3-5e2d-9ed7-43a8e9d8bb24"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8c4b9cb3-b313-51da-bac1-b986d1e13499'::uuid, 'Suresh Joshi', 'cust-249', 'customer-000249@aplibhaji.com', '#179, Block 8, Green Lane 5, Central Business Hub', 'CUSTOMER-000249',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, 'e89e9186-3ff3-5e2d-9ed7-43a8e9d8bb24'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e9223cba-67d3-509e-ac1b-d63a9e99acdf'::uuid, 'authenticated', 'authenticated',
  'customer-000250@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Chawla", "phone": "9819450579", "address": "#383, Block 7, Green Lane 5, Central Business Hub", "area_id": "d6a1daa2-1db7-5d07-aa14-82c78944dc0c", "road_id": "3ccf13f2-c75b-5a36-afef-51b7959b478b", "sub_road_id": "9739083c-9112-5bfb-9481-2b1260ee86dc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e9223cba-67d3-509e-ac1b-d63a9e99acdf'::uuid, 'Neha Chawla', 'cust-250', 'customer-000250@aplibhaji.com', '#383, Block 7, Green Lane 5, Central Business Hub', 'CUSTOMER-000250',
  'd6a1daa2-1db7-5d07-aa14-82c78944dc0c'::uuid, '3ccf13f2-c75b-5a36-afef-51b7959b478b'::uuid, '9739083c-9112-5bfb-9481-2b1260ee86dc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '91e2940b-6302-5da8-b570-1172dee7b7a2'::uuid, 'authenticated', 'authenticated',
  'customer-000251@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Verma", "phone": "9849427054", "address": "#284, Block 3, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "6af17ffb-a486-5383-8f57-aa32d173ca5e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '91e2940b-6302-5da8-b570-1172dee7b7a2'::uuid, 'Manish Verma', 'cust-251', 'customer-000251@aplibhaji.com', '#284, Block 3, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000251',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '6af17ffb-a486-5383-8f57-aa32d173ca5e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '713df5f1-c2fa-5227-9e77-146c7135e4b1'::uuid, 'authenticated', 'authenticated',
  'customer-000252@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Kumar", "phone": "9816263358", "address": "#303, Block 1, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "3882b257-5e34-5eba-a709-bfefc8bdf96d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '713df5f1-c2fa-5227-9e77-146c7135e4b1'::uuid, 'Arun Kumar', 'cust-252', 'customer-000252@aplibhaji.com', '#303, Block 1, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000252',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '3882b257-5e34-5eba-a709-bfefc8bdf96d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f6bf015d-cf3f-5375-ad6d-457adbb32c03'::uuid, 'authenticated', 'authenticated',
  'customer-000253@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Sharma", "phone": "9866334930", "address": "#221, Block 7, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "d6a9e642-2a96-50ef-ae9f-1b8ecd4eb43e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f6bf015d-cf3f-5375-ad6d-457adbb32c03'::uuid, 'Deepak Sharma', 'cust-253', 'customer-000253@aplibhaji.com', '#221, Block 7, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000253',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'd6a9e642-2a96-50ef-ae9f-1b8ecd4eb43e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f696ddb4-de7f-533d-8e14-890a4621dca4'::uuid, 'authenticated', 'authenticated',
  'customer-000254@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Reddy", "phone": "9832877180", "address": "#190, Block 3, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "6af17ffb-a486-5383-8f57-aa32d173ca5e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f696ddb4-de7f-533d-8e14-890a4621dca4'::uuid, 'Priya Reddy', 'cust-254', 'customer-000254@aplibhaji.com', '#190, Block 3, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000254',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '6af17ffb-a486-5383-8f57-aa32d173ca5e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '47bc0786-24d4-559d-936e-6411834148b3'::uuid, 'authenticated', 'authenticated',
  'customer-000255@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Joshi", "phone": "9811649758", "address": "#247, Block 4, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "eb66495a-ebc2-5167-84be-aa1b24ae5131"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '47bc0786-24d4-559d-936e-6411834148b3'::uuid, 'Meena Joshi', 'cust-255', 'customer-000255@aplibhaji.com', '#247, Block 4, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000255',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'eb66495a-ebc2-5167-84be-aa1b24ae5131'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c4f621eb-a06b-5b8c-8267-b794aa83948a'::uuid, 'authenticated', 'authenticated',
  'customer-000256@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Kumar", "phone": "9870022763", "address": "#120, Block 3, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "6af17ffb-a486-5383-8f57-aa32d173ca5e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c4f621eb-a06b-5b8c-8267-b794aa83948a'::uuid, 'Sanjay Kumar', 'cust-256', 'customer-000256@aplibhaji.com', '#120, Block 3, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000256',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '6af17ffb-a486-5383-8f57-aa32d173ca5e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5bc1a189-e114-5ddf-b654-6a797e41d9eb'::uuid, 'authenticated', 'authenticated',
  'customer-000257@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Mehta", "phone": "9834292516", "address": "#228, Block 2, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "e7606618-c542-510d-b5a3-c2e8a9d71be9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5bc1a189-e114-5ddf-b654-6a797e41d9eb'::uuid, 'Sneha Mehta', 'cust-257', 'customer-000257@aplibhaji.com', '#228, Block 2, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000257',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'e7606618-c542-510d-b5a3-c2e8a9d71be9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b677b5ab-a069-57dc-bd36-e3e475c07990'::uuid, 'authenticated', 'authenticated',
  'customer-000258@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Jain", "phone": "9819457276", "address": "#396, Block 6, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "21c859fd-0e10-55e8-8aae-85d38c977642"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b677b5ab-a069-57dc-bd36-e3e475c07990'::uuid, 'Arun Jain', 'cust-258', 'customer-000258@aplibhaji.com', '#396, Block 6, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000258',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '21c859fd-0e10-55e8-8aae-85d38c977642'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3adeb14d-f63b-5f47-ba58-8368fa670b98'::uuid, 'authenticated', 'authenticated',
  'customer-000259@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Sharma", "phone": "9822705995", "address": "#355, Block 7, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "d6a9e642-2a96-50ef-ae9f-1b8ecd4eb43e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3adeb14d-f63b-5f47-ba58-8368fa670b98'::uuid, 'Rajesh Sharma', 'cust-259', 'customer-000259@aplibhaji.com', '#355, Block 7, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000259',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, 'd6a9e642-2a96-50ef-ae9f-1b8ecd4eb43e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '91eba596-051f-53cf-b2cf-4c1887285aeb'::uuid, 'authenticated', 'authenticated',
  'customer-000260@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Jain", "phone": "9873097710", "address": "#384, Block 5, Market Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "7c13e7b2-01da-5003-bd77-c40c5020b4ad", "sub_road_id": "7ece6e2f-a68d-57e1-9f3c-c6fdd846911b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '91eba596-051f-53cf-b2cf-4c1887285aeb'::uuid, 'Sneha Jain', 'cust-260', 'customer-000260@aplibhaji.com', '#384, Block 5, Market Road 6, Metro Greens Phase 1', 'CUSTOMER-000260',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '7c13e7b2-01da-5003-bd77-c40c5020b4ad'::uuid, '7ece6e2f-a68d-57e1-9f3c-c6fdd846911b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '617f4eff-8e8f-5805-bc4c-28eb0c275fbf'::uuid, 'authenticated', 'authenticated',
  'customer-000261@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Gupta", "phone": "9831180430", "address": "#319, Block 3, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "be8130f3-6e70-5e3b-afa5-ef07287e2547"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '617f4eff-8e8f-5805-bc4c-28eb0c275fbf'::uuid, 'Kavita Gupta', 'cust-261', 'customer-000261@aplibhaji.com', '#319, Block 3, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000261',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'be8130f3-6e70-5e3b-afa5-ef07287e2547'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3cc53522-1c6b-5ddf-a8ea-f632ed081817'::uuid, 'authenticated', 'authenticated',
  'customer-000262@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Kumar", "phone": "9841505651", "address": "#102, Block 3, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "be8130f3-6e70-5e3b-afa5-ef07287e2547"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3cc53522-1c6b-5ddf-a8ea-f632ed081817'::uuid, 'Swati Kumar', 'cust-262', 'customer-000262@aplibhaji.com', '#102, Block 3, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000262',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'be8130f3-6e70-5e3b-afa5-ef07287e2547'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1f30bf73-3827-5f84-a02d-d7c30797bd10'::uuid, 'authenticated', 'authenticated',
  'customer-000263@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Deshmukh", "phone": "9818481742", "address": "#376, Block 1, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "a2a8b568-358d-58f8-aeda-ee5328eab142"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1f30bf73-3827-5f84-a02d-d7c30797bd10'::uuid, 'Rohan Deshmukh', 'cust-263', 'customer-000263@aplibhaji.com', '#376, Block 1, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000263',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'a2a8b568-358d-58f8-aeda-ee5328eab142'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e045d98a-ecec-57f0-a821-38d50bccc266'::uuid, 'authenticated', 'authenticated',
  'customer-000264@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Reddy", "phone": "9836767700", "address": "#264, Block 8, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "c4508b9f-8b87-52f1-97c9-b5b0efc05466"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e045d98a-ecec-57f0-a821-38d50bccc266'::uuid, 'Anita Reddy', 'cust-264', 'customer-000264@aplibhaji.com', '#264, Block 8, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000264',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'c4508b9f-8b87-52f1-97c9-b5b0efc05466'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '28f98a94-8ad9-5654-99d4-128be4950a7c'::uuid, 'authenticated', 'authenticated',
  'customer-000265@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Sharma", "phone": "9887015698", "address": "#129, Block 3, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "be8130f3-6e70-5e3b-afa5-ef07287e2547"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '28f98a94-8ad9-5654-99d4-128be4950a7c'::uuid, 'Vijay Sharma', 'cust-265', 'customer-000265@aplibhaji.com', '#129, Block 3, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000265',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'be8130f3-6e70-5e3b-afa5-ef07287e2547'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '82b846c1-c4fc-5422-98d4-1dfb6601be3a'::uuid, 'authenticated', 'authenticated',
  'customer-000266@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Mehta", "phone": "9866969225", "address": "#303, Block 8, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "c4508b9f-8b87-52f1-97c9-b5b0efc05466"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '82b846c1-c4fc-5422-98d4-1dfb6601be3a'::uuid, 'Meena Mehta', 'cust-266', 'customer-000266@aplibhaji.com', '#303, Block 8, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000266',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'c4508b9f-8b87-52f1-97c9-b5b0efc05466'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f2827a80-fe2a-5a1d-ae83-1606dd383def'::uuid, 'authenticated', 'authenticated',
  'customer-000267@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Rao", "phone": "9824979100", "address": "#290, Block 6, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "0e5eadf0-ced1-52ac-9fc7-677646d9d49e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f2827a80-fe2a-5a1d-ae83-1606dd383def'::uuid, 'Kavita Rao', 'cust-267', 'customer-000267@aplibhaji.com', '#290, Block 6, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000267',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, '0e5eadf0-ced1-52ac-9fc7-677646d9d49e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fe8b735e-ed4d-5e9f-968e-15a6749e494b'::uuid, 'authenticated', 'authenticated',
  'customer-000268@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Kulkarni", "phone": "9839696346", "address": "#344, Block 4, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "db42c96e-1817-54ca-a012-004e49e22585"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fe8b735e-ed4d-5e9f-968e-15a6749e494b'::uuid, 'Kavita Kulkarni', 'cust-268', 'customer-000268@aplibhaji.com', '#344, Block 4, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000268',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'db42c96e-1817-54ca-a012-004e49e22585'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8b869eb3-6bfd-558f-a1d7-75af3748dd43'::uuid, 'authenticated', 'authenticated',
  'customer-000269@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Chawla", "phone": "9882631366", "address": "#357, Block 7, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "e5eacebd-0b18-5084-a45d-8d353b250f1f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8b869eb3-6bfd-558f-a1d7-75af3748dd43'::uuid, 'Suresh Chawla', 'cust-269', 'customer-000269@aplibhaji.com', '#357, Block 7, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000269',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'e5eacebd-0b18-5084-a45d-8d353b250f1f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5d320cc6-e25c-5170-bff9-675e64f9e43f'::uuid, 'authenticated', 'authenticated',
  'customer-000270@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Chawla", "phone": "9829153387", "address": "#265, Block 2, MG Road 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "42ccb9e6-c076-50f7-9b52-4dbf73ad34ab", "sub_road_id": "b5d0b86b-3c95-53a3-a448-5c3847b15d6c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5d320cc6-e25c-5170-bff9-675e64f9e43f'::uuid, 'Rohan Chawla', 'cust-270', 'customer-000270@aplibhaji.com', '#265, Block 2, MG Road 6, Metro Greens Phase 1', 'CUSTOMER-000270',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '42ccb9e6-c076-50f7-9b52-4dbf73ad34ab'::uuid, 'b5d0b86b-3c95-53a3-a448-5c3847b15d6c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6447dd10-a902-5852-812e-f636bcd52678'::uuid, 'authenticated', 'authenticated',
  'customer-000271@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Mehta", "phone": "9869699501", "address": "#308, Block 1, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "af4d9cde-1415-5155-b02c-fbbe869b00f9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6447dd10-a902-5852-812e-f636bcd52678'::uuid, 'Manish Mehta', 'cust-271', 'customer-000271@aplibhaji.com', '#308, Block 1, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000271',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'af4d9cde-1415-5155-b02c-fbbe869b00f9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1eb8a107-b4a5-5586-b87b-8e057ae99f57'::uuid, 'authenticated', 'authenticated',
  'customer-000272@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Sharma", "phone": "9896001453", "address": "#395, Block 6, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "48c471cc-1d7b-541b-8d4f-6f3b5421ef9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1eb8a107-b4a5-5586-b87b-8e057ae99f57'::uuid, 'Swati Sharma', 'cust-272', 'customer-000272@aplibhaji.com', '#395, Block 6, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000272',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '48c471cc-1d7b-541b-8d4f-6f3b5421ef9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0d4c3924-d796-50c3-bb9a-96fad678b09a'::uuid, 'authenticated', 'authenticated',
  'customer-000273@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Chawla", "phone": "9894325523", "address": "#356, Block 2, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "418d8a92-9a98-5079-b89a-58455c6fc57c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0d4c3924-d796-50c3-bb9a-96fad678b09a'::uuid, 'Rajesh Chawla', 'cust-273', 'customer-000273@aplibhaji.com', '#356, Block 2, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000273',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '418d8a92-9a98-5079-b89a-58455c6fc57c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1cc1ec35-4c39-5b06-93ba-80ab768603ed'::uuid, 'authenticated', 'authenticated',
  'customer-000274@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Singh", "phone": "9872594948", "address": "#150, Block 8, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "152cd6f0-af72-59c5-b0d7-b225c30d21a0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1cc1ec35-4c39-5b06-93ba-80ab768603ed'::uuid, 'Ramesh Singh', 'cust-274', 'customer-000274@aplibhaji.com', '#150, Block 8, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000274',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '152cd6f0-af72-59c5-b0d7-b225c30d21a0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '93d4e454-388a-5c10-b48f-04b6bb6a0ab9'::uuid, 'authenticated', 'authenticated',
  'customer-000275@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Reddy", "phone": "9826962052", "address": "#220, Block 1, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "af4d9cde-1415-5155-b02c-fbbe869b00f9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '93d4e454-388a-5c10-b48f-04b6bb6a0ab9'::uuid, 'Vijay Reddy', 'cust-275', 'customer-000275@aplibhaji.com', '#220, Block 1, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000275',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'af4d9cde-1415-5155-b02c-fbbe869b00f9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '50fcaab7-0ef8-503a-8024-aa87c640e9c2'::uuid, 'authenticated', 'authenticated',
  'customer-000276@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Joshi", "phone": "9869441068", "address": "#178, Block 6, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "48c471cc-1d7b-541b-8d4f-6f3b5421ef9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '50fcaab7-0ef8-503a-8024-aa87c640e9c2'::uuid, 'Ramesh Joshi', 'cust-276', 'customer-000276@aplibhaji.com', '#178, Block 6, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000276',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '48c471cc-1d7b-541b-8d4f-6f3b5421ef9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8ac6c5df-edc2-5cd9-8c03-c00244d7e7a3'::uuid, 'authenticated', 'authenticated',
  'customer-000277@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Kulkarni", "phone": "9895757570", "address": "#387, Block 6, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "48c471cc-1d7b-541b-8d4f-6f3b5421ef9f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8ac6c5df-edc2-5cd9-8c03-c00244d7e7a3'::uuid, 'Anita Kulkarni', 'cust-277', 'customer-000277@aplibhaji.com', '#387, Block 6, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000277',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '48c471cc-1d7b-541b-8d4f-6f3b5421ef9f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6667b463-eda9-51f7-a287-cd3c34df50f3'::uuid, 'authenticated', 'authenticated',
  'customer-000278@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Patel", "phone": "9827342489", "address": "#157, Block 1, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "af4d9cde-1415-5155-b02c-fbbe869b00f9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6667b463-eda9-51f7-a287-cd3c34df50f3'::uuid, 'Meena Patel', 'cust-278', 'customer-000278@aplibhaji.com', '#157, Block 1, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000278',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'af4d9cde-1415-5155-b02c-fbbe869b00f9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4eff960d-ece8-5473-be3b-c6f549a7110e'::uuid, 'authenticated', 'authenticated',
  'customer-000279@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Mehta", "phone": "9886228187", "address": "#356, Block 5, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "e0627714-cd73-5317-a629-8ebf2f20eca9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4eff960d-ece8-5473-be3b-c6f549a7110e'::uuid, 'Anita Mehta', 'cust-279', 'customer-000279@aplibhaji.com', '#356, Block 5, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000279',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, 'e0627714-cd73-5317-a629-8ebf2f20eca9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1ae8569e-0793-597e-90d9-e5396b46cc70'::uuid, 'authenticated', 'authenticated',
  'customer-000280@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Joshi", "phone": "9861648734", "address": "#274, Block 3, Station Street 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "49ef7f1f-23cb-595a-ae90-ea928abbd277", "sub_road_id": "6bdd78b5-19a3-5f9e-8f43-92a091f419b7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1ae8569e-0793-597e-90d9-e5396b46cc70'::uuid, 'Ajay Joshi', 'cust-280', 'customer-000280@aplibhaji.com', '#274, Block 3, Station Street 6, Metro Greens Phase 1', 'CUSTOMER-000280',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '49ef7f1f-23cb-595a-ae90-ea928abbd277'::uuid, '6bdd78b5-19a3-5f9e-8f43-92a091f419b7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c2fb899e-073b-54bd-a712-b3441b2b4451'::uuid, 'authenticated', 'authenticated',
  'customer-000281@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Joshi", "phone": "9894703991", "address": "#339, Block 8, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "8b0d4127-f7f1-5657-97ef-1dce0f0007af"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c2fb899e-073b-54bd-a712-b3441b2b4451'::uuid, 'Ananya Joshi', 'cust-281', 'customer-000281@aplibhaji.com', '#339, Block 8, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000281',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '8b0d4127-f7f1-5657-97ef-1dce0f0007af'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1431aa75-5354-50f0-b0ac-076fc40bb07c'::uuid, 'authenticated', 'authenticated',
  'customer-000282@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Sharma", "phone": "9887813435", "address": "#390, Block 1, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "3c7f9bc5-6195-5b91-a0ee-5e692b105d76"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1431aa75-5354-50f0-b0ac-076fc40bb07c'::uuid, 'Sunita Sharma', 'cust-282', 'customer-000282@aplibhaji.com', '#390, Block 1, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000282',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '3c7f9bc5-6195-5b91-a0ee-5e692b105d76'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd07693e1-9d38-5cd6-8c7b-49e41a1afca0'::uuid, 'authenticated', 'authenticated',
  'customer-000283@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Rao", "phone": "9815368140", "address": "#393, Block 4, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "8eb773d8-8ab2-509b-addb-34301e7f328e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd07693e1-9d38-5cd6-8c7b-49e41a1afca0'::uuid, 'Pooja Rao', 'cust-283', 'customer-000283@aplibhaji.com', '#393, Block 4, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000283',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '8eb773d8-8ab2-509b-addb-34301e7f328e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f2f41443-a756-53d9-bac6-f8df1886e5f0'::uuid, 'authenticated', 'authenticated',
  'customer-000284@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Kumar", "phone": "9853614355", "address": "#110, Block 7, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "3bd10c6c-d27b-57d5-a3e1-6775979060d8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f2f41443-a756-53d9-bac6-f8df1886e5f0'::uuid, 'Geeta Kumar', 'cust-284', 'customer-000284@aplibhaji.com', '#110, Block 7, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000284',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '3bd10c6c-d27b-57d5-a3e1-6775979060d8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '135e072d-5ae0-5bbb-bdb7-7884da0fa7c9'::uuid, 'authenticated', 'authenticated',
  'customer-000285@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Joshi", "phone": "9853655884", "address": "#168, Block 2, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "4ebc7efd-ddbe-570b-a38b-e0fa25e3b514"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '135e072d-5ae0-5bbb-bdb7-7884da0fa7c9'::uuid, 'Rohan Joshi', 'cust-285', 'customer-000285@aplibhaji.com', '#168, Block 2, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000285',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '4ebc7efd-ddbe-570b-a38b-e0fa25e3b514'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2c6fbe79-5942-5e15-9b10-495ebd77a137'::uuid, 'authenticated', 'authenticated',
  'customer-000286@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Jain", "phone": "9892478964", "address": "#160, Block 2, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "4ebc7efd-ddbe-570b-a38b-e0fa25e3b514"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2c6fbe79-5942-5e15-9b10-495ebd77a137'::uuid, 'Sanjay Jain', 'cust-286', 'customer-000286@aplibhaji.com', '#160, Block 2, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000286',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '4ebc7efd-ddbe-570b-a38b-e0fa25e3b514'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4aaf71a5-9d32-581f-860f-d2f76a85ad40'::uuid, 'authenticated', 'authenticated',
  'customer-000287@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Nair", "phone": "9831018095", "address": "#200, Block 6, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "b42dbc29-9997-5846-9a20-985f8ef14f9b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4aaf71a5-9d32-581f-860f-d2f76a85ad40'::uuid, 'Sunita Nair', 'cust-287', 'customer-000287@aplibhaji.com', '#200, Block 6, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000287',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, 'b42dbc29-9997-5846-9a20-985f8ef14f9b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c13ed9a6-eda1-5959-ade7-9e254dbd61f4'::uuid, 'authenticated', 'authenticated',
  'customer-000288@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Joshi", "phone": "9843928423", "address": "#250, Block 4, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "8eb773d8-8ab2-509b-addb-34301e7f328e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c13ed9a6-eda1-5959-ade7-9e254dbd61f4'::uuid, 'Rajesh Joshi', 'cust-288', 'customer-000288@aplibhaji.com', '#250, Block 4, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000288',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '8eb773d8-8ab2-509b-addb-34301e7f328e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a2daca5f-7f66-5b45-89ca-eced64a263cd'::uuid, 'authenticated', 'authenticated',
  'customer-000289@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Kulkarni", "phone": "9856172097", "address": "#197, Block 7, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "3bd10c6c-d27b-57d5-a3e1-6775979060d8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a2daca5f-7f66-5b45-89ca-eced64a263cd'::uuid, 'Kavita Kulkarni', 'cust-289', 'customer-000289@aplibhaji.com', '#197, Block 7, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000289',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '3bd10c6c-d27b-57d5-a3e1-6775979060d8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9a5c601e-960d-535f-9cd5-8d80eb35127a'::uuid, 'authenticated', 'authenticated',
  'customer-000290@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Nair", "phone": "9840562375", "address": "#397, Block 4, Park Avenue 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "485fb322-40cb-537b-a0a8-2a6e83c2b7f5", "sub_road_id": "8eb773d8-8ab2-509b-addb-34301e7f328e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9a5c601e-960d-535f-9cd5-8d80eb35127a'::uuid, 'Sunita Nair', 'cust-290', 'customer-000290@aplibhaji.com', '#397, Block 4, Park Avenue 6, Metro Greens Phase 1', 'CUSTOMER-000290',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '485fb322-40cb-537b-a0a8-2a6e83c2b7f5'::uuid, '8eb773d8-8ab2-509b-addb-34301e7f328e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c6831a62-6bf9-53c6-8408-134bf9aa2ceb'::uuid, 'authenticated', 'authenticated',
  'customer-000291@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Agarwal", "phone": "9852403829", "address": "#178, Block 1, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "ba7c5155-f69c-5c81-842c-bea415d6bb00"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c6831a62-6bf9-53c6-8408-134bf9aa2ceb'::uuid, 'Amit Agarwal', 'cust-291', 'customer-000291@aplibhaji.com', '#178, Block 1, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000291',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'ba7c5155-f69c-5c81-842c-bea415d6bb00'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4694e82a-4400-5c5b-8bdb-192dbb099955'::uuid, 'authenticated', 'authenticated',
  'customer-000292@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Reddy", "phone": "9878152236", "address": "#372, Block 7, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "9d04c833-f01f-534f-a7c2-ec3370118a69"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4694e82a-4400-5c5b-8bdb-192dbb099955'::uuid, 'Priya Reddy', 'cust-292', 'customer-000292@aplibhaji.com', '#372, Block 7, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000292',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, '9d04c833-f01f-534f-a7c2-ec3370118a69'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '765564f4-e914-57b2-8e78-ddd1c4cde381'::uuid, 'authenticated', 'authenticated',
  'customer-000293@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Reddy", "phone": "9854388597", "address": "#248, Block 2, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "eb2dee1a-bf63-5fe1-803b-c54eed0bd885"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '765564f4-e914-57b2-8e78-ddd1c4cde381'::uuid, 'Priya Reddy', 'cust-293', 'customer-000293@aplibhaji.com', '#248, Block 2, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000293',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'eb2dee1a-bf63-5fe1-803b-c54eed0bd885'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3b7162f7-f32f-56a1-8147-7d37a27a81e4'::uuid, 'authenticated', 'authenticated',
  'customer-000294@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Jain", "phone": "9854185695", "address": "#252, Block 7, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "9d04c833-f01f-534f-a7c2-ec3370118a69"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3b7162f7-f32f-56a1-8147-7d37a27a81e4'::uuid, 'Vijay Jain', 'cust-294', 'customer-000294@aplibhaji.com', '#252, Block 7, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000294',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, '9d04c833-f01f-534f-a7c2-ec3370118a69'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9514554a-667d-5db5-b8de-db5141e95e9e'::uuid, 'authenticated', 'authenticated',
  'customer-000295@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Reddy", "phone": "9888519599", "address": "#353, Block 4, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "2145e6c2-4cb9-543f-8a27-bd9ac46f0235"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9514554a-667d-5db5-b8de-db5141e95e9e'::uuid, 'Ananya Reddy', 'cust-295', 'customer-000295@aplibhaji.com', '#353, Block 4, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000295',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, '2145e6c2-4cb9-543f-8a27-bd9ac46f0235'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f4d15dda-3bdf-56d8-88cc-24854854882a'::uuid, 'authenticated', 'authenticated',
  'customer-000296@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Verma", "phone": "9899500076", "address": "#218, Block 5, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "c34b975b-567f-593b-a5bc-290f5d92096c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f4d15dda-3bdf-56d8-88cc-24854854882a'::uuid, 'Sneha Verma', 'cust-296', 'customer-000296@aplibhaji.com', '#218, Block 5, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000296',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'c34b975b-567f-593b-a5bc-290f5d92096c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9adb1c7b-87e5-5e53-9a11-6a90479d031f'::uuid, 'authenticated', 'authenticated',
  'customer-000297@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Rao", "phone": "9838354060", "address": "#373, Block 6, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "cd18adf5-f7be-59be-91db-5619ebf3c691"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9adb1c7b-87e5-5e53-9a11-6a90479d031f'::uuid, 'Manish Rao', 'cust-297', 'customer-000297@aplibhaji.com', '#373, Block 6, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000297',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'cd18adf5-f7be-59be-91db-5619ebf3c691'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dc80e6b6-4db5-58a5-8f77-b92c908d0262'::uuid, 'authenticated', 'authenticated',
  'customer-000298@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kumar", "phone": "9875853312", "address": "#163, Block 6, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "cd18adf5-f7be-59be-91db-5619ebf3c691"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dc80e6b6-4db5-58a5-8f77-b92c908d0262'::uuid, 'Rohan Kumar', 'cust-298', 'customer-000298@aplibhaji.com', '#163, Block 6, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000298',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'cd18adf5-f7be-59be-91db-5619ebf3c691'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6d0ca0e6-a9ee-592d-85e5-60c6343287da'::uuid, 'authenticated', 'authenticated',
  'customer-000299@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Sharma", "phone": "9875685501", "address": "#322, Block 2, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "eb2dee1a-bf63-5fe1-803b-c54eed0bd885"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6d0ca0e6-a9ee-592d-85e5-60c6343287da'::uuid, 'Vijay Sharma', 'cust-299', 'customer-000299@aplibhaji.com', '#322, Block 2, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000299',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, 'eb2dee1a-bf63-5fe1-803b-c54eed0bd885'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7e746fa1-90ea-587e-bfe4-af8bad34dd7f'::uuid, 'authenticated', 'authenticated',
  'customer-000300@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Kulkarni", "phone": "9881350604", "address": "#319, Block 7, Green Lane 6, Metro Greens Phase 1", "area_id": "95a1cd2f-3b02-5604-a5dd-25ac242546e3", "road_id": "3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4", "sub_road_id": "9d04c833-f01f-534f-a7c2-ec3370118a69"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7e746fa1-90ea-587e-bfe4-af8bad34dd7f'::uuid, 'Rajesh Kulkarni', 'cust-300', 'customer-000300@aplibhaji.com', '#319, Block 7, Green Lane 6, Metro Greens Phase 1', 'CUSTOMER-000300',
  '95a1cd2f-3b02-5604-a5dd-25ac242546e3'::uuid, '3d9adf00-d4b0-548a-b7ae-5c1d94e9a4e4'::uuid, '9d04c833-f01f-534f-a7c2-ec3370118a69'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '70afcbc0-e9dc-5efd-b0c7-957d6bd8e24f'::uuid, 'authenticated', 'authenticated',
  'customer-000301@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Chawla", "phone": "9884014615", "address": "#122, Block 4, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "c8e94d9e-a42d-5f17-a526-2ad6ae53203a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '70afcbc0-e9dc-5efd-b0c7-957d6bd8e24f'::uuid, 'Priya Chawla', 'cust-301', 'customer-000301@aplibhaji.com', '#122, Block 4, Market Road 7, Riverside Boulevard', 'CUSTOMER-000301',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'c8e94d9e-a42d-5f17-a526-2ad6ae53203a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8ca025ab-4b57-5eb8-95b4-629ad54d956b'::uuid, 'authenticated', 'authenticated',
  'customer-000302@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Singh", "phone": "9863414841", "address": "#397, Block 1, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "2d4d5764-87f4-554e-969a-8e1b3ca11531"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8ca025ab-4b57-5eb8-95b4-629ad54d956b'::uuid, 'Kavita Singh', 'cust-302', 'customer-000302@aplibhaji.com', '#397, Block 1, Market Road 7, Riverside Boulevard', 'CUSTOMER-000302',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '2d4d5764-87f4-554e-969a-8e1b3ca11531'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2a5ee0ed-34bd-5fe6-a339-01f929d2db7d'::uuid, 'authenticated', 'authenticated',
  'customer-000303@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Patel", "phone": "9818997441", "address": "#374, Block 8, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "34099f71-c2ab-5e2d-9742-8d14a4d42b67"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2a5ee0ed-34bd-5fe6-a339-01f929d2db7d'::uuid, 'Arun Patel', 'cust-303', 'customer-000303@aplibhaji.com', '#374, Block 8, Market Road 7, Riverside Boulevard', 'CUSTOMER-000303',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '34099f71-c2ab-5e2d-9742-8d14a4d42b67'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8bf4dd17-d964-5cb1-8174-e0964f32bd33'::uuid, 'authenticated', 'authenticated',
  'customer-000304@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Kumar", "phone": "9890250874", "address": "#103, Block 4, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "c8e94d9e-a42d-5f17-a526-2ad6ae53203a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8bf4dd17-d964-5cb1-8174-e0964f32bd33'::uuid, 'Vijay Kumar', 'cust-304', 'customer-000304@aplibhaji.com', '#103, Block 4, Market Road 7, Riverside Boulevard', 'CUSTOMER-000304',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'c8e94d9e-a42d-5f17-a526-2ad6ae53203a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a760f290-47cf-55b3-85f8-53460ab044fb'::uuid, 'authenticated', 'authenticated',
  'customer-000305@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Gupta", "phone": "9851583744", "address": "#389, Block 4, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "c8e94d9e-a42d-5f17-a526-2ad6ae53203a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a760f290-47cf-55b3-85f8-53460ab044fb'::uuid, 'Sunita Gupta', 'cust-305', 'customer-000305@aplibhaji.com', '#389, Block 4, Market Road 7, Riverside Boulevard', 'CUSTOMER-000305',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'c8e94d9e-a42d-5f17-a526-2ad6ae53203a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'edbe605a-948b-5f9d-982f-a3506b3ba18f'::uuid, 'authenticated', 'authenticated',
  'customer-000306@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Sharma", "phone": "9844053041", "address": "#173, Block 7, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "95c4d76a-b2c2-5dd9-837a-973f92f7fc7e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'edbe605a-948b-5f9d-982f-a3506b3ba18f'::uuid, 'Ajay Sharma', 'cust-306', 'customer-000306@aplibhaji.com', '#173, Block 7, Market Road 7, Riverside Boulevard', 'CUSTOMER-000306',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '95c4d76a-b2c2-5dd9-837a-973f92f7fc7e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '39cdb6d2-06dc-5116-a452-ee7f60c00535'::uuid, 'authenticated', 'authenticated',
  'customer-000307@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Patel", "phone": "9847853289", "address": "#197, Block 4, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "c8e94d9e-a42d-5f17-a526-2ad6ae53203a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '39cdb6d2-06dc-5116-a452-ee7f60c00535'::uuid, 'Meena Patel', 'cust-307', 'customer-000307@aplibhaji.com', '#197, Block 4, Market Road 7, Riverside Boulevard', 'CUSTOMER-000307',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, 'c8e94d9e-a42d-5f17-a526-2ad6ae53203a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b314ab48-f1c0-5e4e-9bf6-93a561cfeb79'::uuid, 'authenticated', 'authenticated',
  'customer-000308@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Rao", "phone": "9846761311", "address": "#232, Block 1, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "2d4d5764-87f4-554e-969a-8e1b3ca11531"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b314ab48-f1c0-5e4e-9bf6-93a561cfeb79'::uuid, 'Ajay Rao', 'cust-308', 'customer-000308@aplibhaji.com', '#232, Block 1, Market Road 7, Riverside Boulevard', 'CUSTOMER-000308',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '2d4d5764-87f4-554e-969a-8e1b3ca11531'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c4e0c7b4-1979-56c3-a407-6fa55380a1f5'::uuid, 'authenticated', 'authenticated',
  'customer-000309@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Joshi", "phone": "9887506340", "address": "#241, Block 1, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "2d4d5764-87f4-554e-969a-8e1b3ca11531"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c4e0c7b4-1979-56c3-a407-6fa55380a1f5'::uuid, 'Manish Joshi', 'cust-309', 'customer-000309@aplibhaji.com', '#241, Block 1, Market Road 7, Riverside Boulevard', 'CUSTOMER-000309',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '2d4d5764-87f4-554e-969a-8e1b3ca11531'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '22563277-7d9b-539c-b16b-a2366aad620a'::uuid, 'authenticated', 'authenticated',
  'customer-000310@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Rao", "phone": "9874121858", "address": "#228, Block 5, Market Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8985e31a-e4c1-5323-87fa-0038c8a5ca5a", "sub_road_id": "274aa88c-8bca-5d9c-b29b-cdf4ce3fe6bb"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '22563277-7d9b-539c-b16b-a2366aad620a'::uuid, 'Sunita Rao', 'cust-310', 'customer-000310@aplibhaji.com', '#228, Block 5, Market Road 7, Riverside Boulevard', 'CUSTOMER-000310',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8985e31a-e4c1-5323-87fa-0038c8a5ca5a'::uuid, '274aa88c-8bca-5d9c-b29b-cdf4ce3fe6bb'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '82d79392-b8be-5981-82b1-663b8fc51f70'::uuid, 'authenticated', 'authenticated',
  'customer-000311@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Joshi", "phone": "9816343555", "address": "#299, Block 3, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "31d1e228-2aec-5912-845a-1062c6060e11"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '82d79392-b8be-5981-82b1-663b8fc51f70'::uuid, 'Deepak Joshi', 'cust-311', 'customer-000311@aplibhaji.com', '#299, Block 3, MG Road 7, Riverside Boulevard', 'CUSTOMER-000311',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '31d1e228-2aec-5912-845a-1062c6060e11'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0ef96faa-87b7-5ed7-b94e-7e5713e7b6c4'::uuid, 'authenticated', 'authenticated',
  'customer-000312@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Deshmukh", "phone": "9814089918", "address": "#306, Block 4, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "4f4544ee-100b-52b2-96a2-5b20cd6761fe"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0ef96faa-87b7-5ed7-b94e-7e5713e7b6c4'::uuid, 'Priya Deshmukh', 'cust-312', 'customer-000312@aplibhaji.com', '#306, Block 4, MG Road 7, Riverside Boulevard', 'CUSTOMER-000312',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '4f4544ee-100b-52b2-96a2-5b20cd6761fe'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cd3575af-0ab0-5ca7-986c-90cc58428526'::uuid, 'authenticated', 'authenticated',
  'customer-000313@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Deshmukh", "phone": "9821546497", "address": "#123, Block 3, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "31d1e228-2aec-5912-845a-1062c6060e11"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cd3575af-0ab0-5ca7-986c-90cc58428526'::uuid, 'Meena Deshmukh', 'cust-313', 'customer-000313@aplibhaji.com', '#123, Block 3, MG Road 7, Riverside Boulevard', 'CUSTOMER-000313',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '31d1e228-2aec-5912-845a-1062c6060e11'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0d64529e-922a-5ee0-ae4e-1d8108a694ec'::uuid, 'authenticated', 'authenticated',
  'customer-000314@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Kulkarni", "phone": "9834662418", "address": "#136, Block 2, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "6200b5ae-e6e8-5a4a-a316-d4a1e220a6e7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0d64529e-922a-5ee0-ae4e-1d8108a694ec'::uuid, 'Amit Kulkarni', 'cust-314', 'customer-000314@aplibhaji.com', '#136, Block 2, MG Road 7, Riverside Boulevard', 'CUSTOMER-000314',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '6200b5ae-e6e8-5a4a-a316-d4a1e220a6e7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5d09e5da-637c-50d5-9c86-9bb33231b5c4'::uuid, 'authenticated', 'authenticated',
  'customer-000315@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Deshmukh", "phone": "9823080674", "address": "#381, Block 5, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "38cd675a-c9bb-503d-b7d7-dfab64e4a2f1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5d09e5da-637c-50d5-9c86-9bb33231b5c4'::uuid, 'Kavita Deshmukh', 'cust-315', 'customer-000315@aplibhaji.com', '#381, Block 5, MG Road 7, Riverside Boulevard', 'CUSTOMER-000315',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '38cd675a-c9bb-503d-b7d7-dfab64e4a2f1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2b22ebe9-c2cf-5ca8-8f20-aff23457ae0a'::uuid, 'authenticated', 'authenticated',
  'customer-000316@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Kumar", "phone": "9812691584", "address": "#239, Block 1, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "b94e52d1-e671-55c7-8c76-4f20d1dbced0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2b22ebe9-c2cf-5ca8-8f20-aff23457ae0a'::uuid, 'Meena Kumar', 'cust-316', 'customer-000316@aplibhaji.com', '#239, Block 1, MG Road 7, Riverside Boulevard', 'CUSTOMER-000316',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'b94e52d1-e671-55c7-8c76-4f20d1dbced0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1c1e15bb-039a-5975-a783-49a1da7f2e0e'::uuid, 'authenticated', 'authenticated',
  'customer-000317@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Singh", "phone": "9868773969", "address": "#373, Block 4, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "4f4544ee-100b-52b2-96a2-5b20cd6761fe"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1c1e15bb-039a-5975-a783-49a1da7f2e0e'::uuid, 'Suresh Singh', 'cust-317', 'customer-000317@aplibhaji.com', '#373, Block 4, MG Road 7, Riverside Boulevard', 'CUSTOMER-000317',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '4f4544ee-100b-52b2-96a2-5b20cd6761fe'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9e1604f1-af96-5465-97a2-7bbe3b991fdf'::uuid, 'authenticated', 'authenticated',
  'customer-000318@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Kumar", "phone": "9879914657", "address": "#146, Block 4, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "4f4544ee-100b-52b2-96a2-5b20cd6761fe"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9e1604f1-af96-5465-97a2-7bbe3b991fdf'::uuid, 'Swati Kumar', 'cust-318', 'customer-000318@aplibhaji.com', '#146, Block 4, MG Road 7, Riverside Boulevard', 'CUSTOMER-000318',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '4f4544ee-100b-52b2-96a2-5b20cd6761fe'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '92901758-7059-541f-b789-8a7e4e8faeb5'::uuid, 'authenticated', 'authenticated',
  'customer-000319@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Patel", "phone": "9838529814", "address": "#172, Block 6, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "03512892-9b6f-59df-9da0-d5a39628cd3d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '92901758-7059-541f-b789-8a7e4e8faeb5'::uuid, 'Amit Patel', 'cust-319', 'customer-000319@aplibhaji.com', '#172, Block 6, MG Road 7, Riverside Boulevard', 'CUSTOMER-000319',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, '03512892-9b6f-59df-9da0-d5a39628cd3d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4b722c38-6b70-5b57-a76e-09de8ef9b8fc'::uuid, 'authenticated', 'authenticated',
  'customer-000320@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Patel", "phone": "9895337455", "address": "#131, Block 1, MG Road 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "e025493f-a8a5-5acc-8b73-bc9b10056e5c", "sub_road_id": "b94e52d1-e671-55c7-8c76-4f20d1dbced0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4b722c38-6b70-5b57-a76e-09de8ef9b8fc'::uuid, 'Amit Patel', 'cust-320', 'customer-000320@aplibhaji.com', '#131, Block 1, MG Road 7, Riverside Boulevard', 'CUSTOMER-000320',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'e025493f-a8a5-5acc-8b73-bc9b10056e5c'::uuid, 'b94e52d1-e671-55c7-8c76-4f20d1dbced0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9f5af6d7-6a57-565c-9e39-24a1da9477c4'::uuid, 'authenticated', 'authenticated',
  'customer-000321@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Rao", "phone": "9833370985", "address": "#343, Block 8, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "a8b0348b-df13-5f1c-93b1-6e589449f99f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9f5af6d7-6a57-565c-9e39-24a1da9477c4'::uuid, 'Arun Rao', 'cust-321', 'customer-000321@aplibhaji.com', '#343, Block 8, Station Street 7, Riverside Boulevard', 'CUSTOMER-000321',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'a8b0348b-df13-5f1c-93b1-6e589449f99f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '986b3e2d-8077-5497-b3ba-57a1d65d2cf1'::uuid, 'authenticated', 'authenticated',
  'customer-000322@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Mehta", "phone": "9818917149", "address": "#146, Block 1, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "1fa44a68-cdd4-5658-aa21-fdef4e2838f4"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '986b3e2d-8077-5497-b3ba-57a1d65d2cf1'::uuid, 'Meena Mehta', 'cust-322', 'customer-000322@aplibhaji.com', '#146, Block 1, Station Street 7, Riverside Boulevard', 'CUSTOMER-000322',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, '1fa44a68-cdd4-5658-aa21-fdef4e2838f4'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3b7ed86a-6457-50dd-82d9-9f81d7c62ae6'::uuid, 'authenticated', 'authenticated',
  'customer-000323@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Jain", "phone": "9812908565", "address": "#165, Block 6, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "60aaf9e0-9f9a-50ec-a9aa-828726651a24"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3b7ed86a-6457-50dd-82d9-9f81d7c62ae6'::uuid, 'Ananya Jain', 'cust-323', 'customer-000323@aplibhaji.com', '#165, Block 6, Station Street 7, Riverside Boulevard', 'CUSTOMER-000323',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, '60aaf9e0-9f9a-50ec-a9aa-828726651a24'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a93e63c1-5f99-56d1-848b-f405060b19a9'::uuid, 'authenticated', 'authenticated',
  'customer-000324@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Kulkarni", "phone": "9864855368", "address": "#330, Block 8, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "a8b0348b-df13-5f1c-93b1-6e589449f99f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a93e63c1-5f99-56d1-848b-f405060b19a9'::uuid, 'Rahul Kulkarni', 'cust-324', 'customer-000324@aplibhaji.com', '#330, Block 8, Station Street 7, Riverside Boulevard', 'CUSTOMER-000324',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'a8b0348b-df13-5f1c-93b1-6e589449f99f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7a4b72b0-4698-5252-985f-4ecd7abaad55'::uuid, 'authenticated', 'authenticated',
  'customer-000325@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Deshmukh", "phone": "9828656203", "address": "#312, Block 6, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "60aaf9e0-9f9a-50ec-a9aa-828726651a24"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7a4b72b0-4698-5252-985f-4ecd7abaad55'::uuid, 'Rohan Deshmukh', 'cust-325', 'customer-000325@aplibhaji.com', '#312, Block 6, Station Street 7, Riverside Boulevard', 'CUSTOMER-000325',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, '60aaf9e0-9f9a-50ec-a9aa-828726651a24'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8c17df34-90ea-5381-a72e-45b80ebbb472'::uuid, 'authenticated', 'authenticated',
  'customer-000326@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Sharma", "phone": "9886371664", "address": "#216, Block 5, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "e6c9a1e6-6490-5e18-8bd1-b43e64bf9e98"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8c17df34-90ea-5381-a72e-45b80ebbb472'::uuid, 'Ananya Sharma', 'cust-326', 'customer-000326@aplibhaji.com', '#216, Block 5, Station Street 7, Riverside Boulevard', 'CUSTOMER-000326',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'e6c9a1e6-6490-5e18-8bd1-b43e64bf9e98'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8154aedf-2c6a-52fa-b0c6-bf5120eb4923'::uuid, 'authenticated', 'authenticated',
  'customer-000327@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Reddy", "phone": "9849529916", "address": "#161, Block 3, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "e6ec2ee9-b487-5e2d-a1d9-9bf2535ba0c9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8154aedf-2c6a-52fa-b0c6-bf5120eb4923'::uuid, 'Vijay Reddy', 'cust-327', 'customer-000327@aplibhaji.com', '#161, Block 3, Station Street 7, Riverside Boulevard', 'CUSTOMER-000327',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'e6ec2ee9-b487-5e2d-a1d9-9bf2535ba0c9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '365b47cc-aee2-5ef1-8aba-89077bab2450'::uuid, 'authenticated', 'authenticated',
  'customer-000328@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Kulkarni", "phone": "9864887264", "address": "#297, Block 6, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "60aaf9e0-9f9a-50ec-a9aa-828726651a24"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '365b47cc-aee2-5ef1-8aba-89077bab2450'::uuid, 'Vijay Kulkarni', 'cust-328', 'customer-000328@aplibhaji.com', '#297, Block 6, Station Street 7, Riverside Boulevard', 'CUSTOMER-000328',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, '60aaf9e0-9f9a-50ec-a9aa-828726651a24'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '54b59dfe-6839-57bb-ba1f-a43b2e7068ba'::uuid, 'authenticated', 'authenticated',
  'customer-000329@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Kulkarni", "phone": "9851538109", "address": "#360, Block 3, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "e6ec2ee9-b487-5e2d-a1d9-9bf2535ba0c9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '54b59dfe-6839-57bb-ba1f-a43b2e7068ba'::uuid, 'Manish Kulkarni', 'cust-329', 'customer-000329@aplibhaji.com', '#360, Block 3, Station Street 7, Riverside Boulevard', 'CUSTOMER-000329',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'e6ec2ee9-b487-5e2d-a1d9-9bf2535ba0c9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '451f9b3d-025b-5c68-8d9f-3ad309560c18'::uuid, 'authenticated', 'authenticated',
  'customer-000330@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Nair", "phone": "9899189644", "address": "#385, Block 8, Station Street 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "8cae66a0-f3d4-531d-9c37-eb24991297eb", "sub_road_id": "a8b0348b-df13-5f1c-93b1-6e589449f99f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '451f9b3d-025b-5c68-8d9f-3ad309560c18'::uuid, 'Swati Nair', 'cust-330', 'customer-000330@aplibhaji.com', '#385, Block 8, Station Street 7, Riverside Boulevard', 'CUSTOMER-000330',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '8cae66a0-f3d4-531d-9c37-eb24991297eb'::uuid, 'a8b0348b-df13-5f1c-93b1-6e589449f99f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4891e26f-3336-5a60-b204-92cefb8e7e9c'::uuid, 'authenticated', 'authenticated',
  'customer-000331@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Mehta", "phone": "9842235794", "address": "#219, Block 4, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "6b782fb6-23ff-5edb-818b-de105d090acf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4891e26f-3336-5a60-b204-92cefb8e7e9c'::uuid, 'Kavita Mehta', 'cust-331', 'customer-000331@aplibhaji.com', '#219, Block 4, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000331',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '6b782fb6-23ff-5edb-818b-de105d090acf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ca874ffd-ea1d-5570-a566-3c59ba8a6f47'::uuid, 'authenticated', 'authenticated',
  'customer-000332@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Agarwal", "phone": "9888915996", "address": "#115, Block 4, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "6b782fb6-23ff-5edb-818b-de105d090acf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ca874ffd-ea1d-5570-a566-3c59ba8a6f47'::uuid, 'Arun Agarwal', 'cust-332', 'customer-000332@aplibhaji.com', '#115, Block 4, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000332',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '6b782fb6-23ff-5edb-818b-de105d090acf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6c56874c-c9e5-5d13-bf70-c57b37075633'::uuid, 'authenticated', 'authenticated',
  'customer-000333@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Sharma", "phone": "9819915131", "address": "#189, Block 8, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "3e046e0d-4eb2-5c30-9a63-7f042484b32c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6c56874c-c9e5-5d13-bf70-c57b37075633'::uuid, 'Vikram Sharma', 'cust-333', 'customer-000333@aplibhaji.com', '#189, Block 8, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000333',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '3e046e0d-4eb2-5c30-9a63-7f042484b32c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '723e4536-2f7a-5357-b93e-c14fca1ac094'::uuid, 'authenticated', 'authenticated',
  'customer-000334@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Reddy", "phone": "9831581223", "address": "#392, Block 1, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "baf26981-9006-5be9-9ce9-0d1dac042d53"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '723e4536-2f7a-5357-b93e-c14fca1ac094'::uuid, 'Pooja Reddy', 'cust-334', 'customer-000334@aplibhaji.com', '#392, Block 1, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000334',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'baf26981-9006-5be9-9ce9-0d1dac042d53'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7927d8e7-aa4d-5305-9a95-46eaf6ea7499'::uuid, 'authenticated', 'authenticated',
  'customer-000335@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Sharma", "phone": "9875420885", "address": "#162, Block 7, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "4253205f-83bf-5f55-9642-79ff32804cfb"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7927d8e7-aa4d-5305-9a95-46eaf6ea7499'::uuid, 'Neha Sharma', 'cust-335', 'customer-000335@aplibhaji.com', '#162, Block 7, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000335',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '4253205f-83bf-5f55-9642-79ff32804cfb'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '49ba89d1-87cd-5b9c-b6f3-aebe2c9b1481'::uuid, 'authenticated', 'authenticated',
  'customer-000336@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Mehta", "phone": "9889652071", "address": "#168, Block 6, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "0ed8f6ff-f706-5a73-ad13-d146a60b6ff9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '49ba89d1-87cd-5b9c-b6f3-aebe2c9b1481'::uuid, 'Arun Mehta', 'cust-336', 'customer-000336@aplibhaji.com', '#168, Block 6, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000336',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '0ed8f6ff-f706-5a73-ad13-d146a60b6ff9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'de0712d9-0f88-5d5b-8342-13f3354695d3'::uuid, 'authenticated', 'authenticated',
  'customer-000337@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Singh", "phone": "9873218492", "address": "#396, Block 7, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "4253205f-83bf-5f55-9642-79ff32804cfb"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'de0712d9-0f88-5d5b-8342-13f3354695d3'::uuid, 'Kavita Singh', 'cust-337', 'customer-000337@aplibhaji.com', '#396, Block 7, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000337',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '4253205f-83bf-5f55-9642-79ff32804cfb'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b3306989-813b-5043-aa23-ab5942e6016c'::uuid, 'authenticated', 'authenticated',
  'customer-000338@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Nair", "phone": "9840889710", "address": "#230, Block 6, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "0ed8f6ff-f706-5a73-ad13-d146a60b6ff9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b3306989-813b-5043-aa23-ab5942e6016c'::uuid, 'Neha Nair', 'cust-338', 'customer-000338@aplibhaji.com', '#230, Block 6, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000338',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '0ed8f6ff-f706-5a73-ad13-d146a60b6ff9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8b65a433-1096-59eb-a4b8-aa72c764cec4'::uuid, 'authenticated', 'authenticated',
  'customer-000339@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Kulkarni", "phone": "9825394815", "address": "#249, Block 1, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "baf26981-9006-5be9-9ce9-0d1dac042d53"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8b65a433-1096-59eb-a4b8-aa72c764cec4'::uuid, 'Amit Kulkarni', 'cust-339', 'customer-000339@aplibhaji.com', '#249, Block 1, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000339',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, 'baf26981-9006-5be9-9ce9-0d1dac042d53'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '617233de-028c-5a37-9f40-b317e6599e98'::uuid, 'authenticated', 'authenticated',
  'customer-000340@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Singh", "phone": "9843692531", "address": "#127, Block 4, Park Avenue 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "3d3f4ff3-e7df-590d-a011-7df976005c7e", "sub_road_id": "6b782fb6-23ff-5edb-818b-de105d090acf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '617233de-028c-5a37-9f40-b317e6599e98'::uuid, 'Priya Singh', 'cust-340', 'customer-000340@aplibhaji.com', '#127, Block 4, Park Avenue 7, Riverside Boulevard', 'CUSTOMER-000340',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, '3d3f4ff3-e7df-590d-a011-7df976005c7e'::uuid, '6b782fb6-23ff-5edb-818b-de105d090acf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '20c30a55-2b47-5914-af8a-27bbe98d1a4c'::uuid, 'authenticated', 'authenticated',
  'customer-000341@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Mehta", "phone": "9853746430", "address": "#190, Block 7, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "3eb39a5b-5135-515a-b6fe-6d5612978e79"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '20c30a55-2b47-5914-af8a-27bbe98d1a4c'::uuid, 'Arun Mehta', 'cust-341', 'customer-000341@aplibhaji.com', '#190, Block 7, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000341',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '3eb39a5b-5135-515a-b6fe-6d5612978e79'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c0205c12-770b-569a-8f1e-fc435c192e73'::uuid, 'authenticated', 'authenticated',
  'customer-000342@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Agarwal", "phone": "9857847582", "address": "#394, Block 4, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "fb8f4d14-6148-5f02-8e42-e655f1878a82"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c0205c12-770b-569a-8f1e-fc435c192e73'::uuid, 'Rohan Agarwal', 'cust-342', 'customer-000342@aplibhaji.com', '#394, Block 4, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000342',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'fb8f4d14-6148-5f02-8e42-e655f1878a82'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6ed16101-a068-5685-8f62-8fe801fa6170'::uuid, 'authenticated', 'authenticated',
  'customer-000343@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Singh", "phone": "9855613440", "address": "#358, Block 1, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "87ad9267-8d06-5dd4-b2aa-62d5b94ecde9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6ed16101-a068-5685-8f62-8fe801fa6170'::uuid, 'Ananya Singh', 'cust-343', 'customer-000343@aplibhaji.com', '#358, Block 1, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000343',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '87ad9267-8d06-5dd4-b2aa-62d5b94ecde9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '838d33d6-26cb-569a-bcb4-4e9a2a2a900b'::uuid, 'authenticated', 'authenticated',
  'customer-000344@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Rao", "phone": "9821771797", "address": "#208, Block 3, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "de0edabf-ed43-5106-bb31-1ca055938213"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '838d33d6-26cb-569a-bcb4-4e9a2a2a900b'::uuid, 'Swati Rao', 'cust-344', 'customer-000344@aplibhaji.com', '#208, Block 3, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000344',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'de0edabf-ed43-5106-bb31-1ca055938213'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5d26c210-013a-5168-b601-2c67b25f2dd5'::uuid, 'authenticated', 'authenticated',
  'customer-000345@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Jain", "phone": "9875981664", "address": "#331, Block 6, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "073e5bf4-ebbb-5fd5-a090-646987c6aa36"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5d26c210-013a-5168-b601-2c67b25f2dd5'::uuid, 'Ananya Jain', 'cust-345', 'customer-000345@aplibhaji.com', '#331, Block 6, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000345',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '073e5bf4-ebbb-5fd5-a090-646987c6aa36'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '32910ce5-5f76-5fdc-8879-7d4a1a358434'::uuid, 'authenticated', 'authenticated',
  'customer-000346@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Joshi", "phone": "9871160258", "address": "#137, Block 6, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "073e5bf4-ebbb-5fd5-a090-646987c6aa36"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '32910ce5-5f76-5fdc-8879-7d4a1a358434'::uuid, 'Sanjay Joshi', 'cust-346', 'customer-000346@aplibhaji.com', '#137, Block 6, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000346',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '073e5bf4-ebbb-5fd5-a090-646987c6aa36'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7e02a584-903c-5f64-9e93-c39f5eb9a56d'::uuid, 'authenticated', 'authenticated',
  'customer-000347@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Verma", "phone": "9853271159", "address": "#352, Block 2, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "36adc9d8-1e67-5f8a-8882-dc0a1c0b70d6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7e02a584-903c-5f64-9e93-c39f5eb9a56d'::uuid, 'Ramesh Verma', 'cust-347', 'customer-000347@aplibhaji.com', '#352, Block 2, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000347',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '36adc9d8-1e67-5f8a-8882-dc0a1c0b70d6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4fcfcd98-8bb7-5acb-913a-58ee9a2fd0ff'::uuid, 'authenticated', 'authenticated',
  'customer-000348@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Joshi", "phone": "9855639208", "address": "#208, Block 3, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "de0edabf-ed43-5106-bb31-1ca055938213"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4fcfcd98-8bb7-5acb-913a-58ee9a2fd0ff'::uuid, 'Rahul Joshi', 'cust-348', 'customer-000348@aplibhaji.com', '#208, Block 3, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000348',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, 'de0edabf-ed43-5106-bb31-1ca055938213'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f2ec6c01-1018-5d92-bbc3-063a73dc07aa'::uuid, 'authenticated', 'authenticated',
  'customer-000349@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Patel", "phone": "9845055488", "address": "#385, Block 2, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "36adc9d8-1e67-5f8a-8882-dc0a1c0b70d6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f2ec6c01-1018-5d92-bbc3-063a73dc07aa'::uuid, 'Pooja Patel', 'cust-349', 'customer-000349@aplibhaji.com', '#385, Block 2, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000349',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '36adc9d8-1e67-5f8a-8882-dc0a1c0b70d6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e4837e93-efe7-51a0-93af-40a0fcac6dcd'::uuid, 'authenticated', 'authenticated',
  'customer-000350@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Chawla", "phone": "9827986769", "address": "#125, Block 7, Green Lane 7, Riverside Boulevard", "area_id": "d2c69fdd-a093-5243-802d-37aeaff9815a", "road_id": "d2c17a34-62d3-5941-8d68-d168e3a4fbdc", "sub_road_id": "3eb39a5b-5135-515a-b6fe-6d5612978e79"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e4837e93-efe7-51a0-93af-40a0fcac6dcd'::uuid, 'Ananya Chawla', 'cust-350', 'customer-000350@aplibhaji.com', '#125, Block 7, Green Lane 7, Riverside Boulevard', 'CUSTOMER-000350',
  'd2c69fdd-a093-5243-802d-37aeaff9815a'::uuid, 'd2c17a34-62d3-5941-8d68-d168e3a4fbdc'::uuid, '3eb39a5b-5135-515a-b6fe-6d5612978e79'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '10e3a411-045e-5c41-8fa6-be5e06f67249'::uuid, 'authenticated', 'authenticated',
  'customer-000351@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Agarwal", "phone": "9846280902", "address": "#395, Block 1, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "29534439-db5f-55cc-a6ab-2a7c355efb5f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '10e3a411-045e-5c41-8fa6-be5e06f67249'::uuid, 'Sunita Agarwal', 'cust-351', 'customer-000351@aplibhaji.com', '#395, Block 1, Market Road 8, Sunrise Gardens', 'CUSTOMER-000351',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '29534439-db5f-55cc-a6ab-2a7c355efb5f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fc3fc6fb-c7c8-5073-9d92-774b5fa43c3a'::uuid, 'authenticated', 'authenticated',
  'customer-000352@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Singh", "phone": "9885063672", "address": "#210, Block 4, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "74c5954b-1de0-5dda-a891-1710e377da5c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fc3fc6fb-c7c8-5073-9d92-774b5fa43c3a'::uuid, 'Rahul Singh', 'cust-352', 'customer-000352@aplibhaji.com', '#210, Block 4, Market Road 8, Sunrise Gardens', 'CUSTOMER-000352',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '74c5954b-1de0-5dda-a891-1710e377da5c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '370ba333-27cb-5b27-9363-d7b020b79ff6'::uuid, 'authenticated', 'authenticated',
  'customer-000353@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Reddy", "phone": "9820314468", "address": "#360, Block 3, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "cf64d3f2-e857-5ac5-a22a-8c3cd5613f95"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '370ba333-27cb-5b27-9363-d7b020b79ff6'::uuid, 'Arun Reddy', 'cust-353', 'customer-000353@aplibhaji.com', '#360, Block 3, Market Road 8, Sunrise Gardens', 'CUSTOMER-000353',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'cf64d3f2-e857-5ac5-a22a-8c3cd5613f95'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '559c4dab-c8a3-5241-ab2e-4e83c7e1c0e0'::uuid, 'authenticated', 'authenticated',
  'customer-000354@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Chawla", "phone": "9827070357", "address": "#172, Block 2, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "bf1480b8-6b17-5a96-9ab5-0eddf4b4704b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '559c4dab-c8a3-5241-ab2e-4e83c7e1c0e0'::uuid, 'Geeta Chawla', 'cust-354', 'customer-000354@aplibhaji.com', '#172, Block 2, Market Road 8, Sunrise Gardens', 'CUSTOMER-000354',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'bf1480b8-6b17-5a96-9ab5-0eddf4b4704b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a073689d-95a8-554c-9688-944a3f836966'::uuid, 'authenticated', 'authenticated',
  'customer-000355@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Patel", "phone": "9827414046", "address": "#140, Block 7, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "618b85a8-38e5-5188-aeed-5a7e44db5f15"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a073689d-95a8-554c-9688-944a3f836966'::uuid, 'Rohan Patel', 'cust-355', 'customer-000355@aplibhaji.com', '#140, Block 7, Market Road 8, Sunrise Gardens', 'CUSTOMER-000355',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '618b85a8-38e5-5188-aeed-5a7e44db5f15'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6718b591-7935-568c-80a7-03b7774861a7'::uuid, 'authenticated', 'authenticated',
  'customer-000356@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Agarwal", "phone": "9819044869", "address": "#139, Block 1, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "29534439-db5f-55cc-a6ab-2a7c355efb5f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6718b591-7935-568c-80a7-03b7774861a7'::uuid, 'Pooja Agarwal', 'cust-356', 'customer-000356@aplibhaji.com', '#139, Block 1, Market Road 8, Sunrise Gardens', 'CUSTOMER-000356',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '29534439-db5f-55cc-a6ab-2a7c355efb5f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a0b61400-bd69-5b25-a867-259772a871de'::uuid, 'authenticated', 'authenticated',
  'customer-000357@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Agarwal", "phone": "9841262584", "address": "#218, Block 5, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "5046aad7-bbdd-576d-9c34-dd69b7257adf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a0b61400-bd69-5b25-a867-259772a871de'::uuid, 'Geeta Agarwal', 'cust-357', 'customer-000357@aplibhaji.com', '#218, Block 5, Market Road 8, Sunrise Gardens', 'CUSTOMER-000357',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '5046aad7-bbdd-576d-9c34-dd69b7257adf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5f63ab38-bbf3-516d-a58c-e8398692a694'::uuid, 'authenticated', 'authenticated',
  'customer-000358@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Nair", "phone": "9854168137", "address": "#377, Block 2, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "bf1480b8-6b17-5a96-9ab5-0eddf4b4704b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5f63ab38-bbf3-516d-a58c-e8398692a694'::uuid, 'Rajesh Nair', 'cust-358', 'customer-000358@aplibhaji.com', '#377, Block 2, Market Road 8, Sunrise Gardens', 'CUSTOMER-000358',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, 'bf1480b8-6b17-5a96-9ab5-0eddf4b4704b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4cace97e-566f-57f2-a306-624839541a0b'::uuid, 'authenticated', 'authenticated',
  'customer-000359@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Sharma", "phone": "9884158474", "address": "#124, Block 5, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "5046aad7-bbdd-576d-9c34-dd69b7257adf"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4cace97e-566f-57f2-a306-624839541a0b'::uuid, 'Meena Sharma', 'cust-359', 'customer-000359@aplibhaji.com', '#124, Block 5, Market Road 8, Sunrise Gardens', 'CUSTOMER-000359',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '5046aad7-bbdd-576d-9c34-dd69b7257adf'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '84eaf828-bc13-590a-ae50-ff976283415d'::uuid, 'authenticated', 'authenticated',
  'customer-000360@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Patel", "phone": "9824372253", "address": "#380, Block 1, Market Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2bd5fec8-31bc-5cc0-be07-5dc98aedf655", "sub_road_id": "29534439-db5f-55cc-a6ab-2a7c355efb5f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '84eaf828-bc13-590a-ae50-ff976283415d'::uuid, 'Ajay Patel', 'cust-360', 'customer-000360@aplibhaji.com', '#380, Block 1, Market Road 8, Sunrise Gardens', 'CUSTOMER-000360',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2bd5fec8-31bc-5cc0-be07-5dc98aedf655'::uuid, '29534439-db5f-55cc-a6ab-2a7c355efb5f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9723ec51-2577-5355-807c-7d369dcb5dae'::uuid, 'authenticated', 'authenticated',
  'customer-000361@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Kumar", "phone": "9864894421", "address": "#165, Block 3, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "96288f00-00e2-5377-90cc-b55c3e980a3d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9723ec51-2577-5355-807c-7d369dcb5dae'::uuid, 'Vikram Kumar', 'cust-361', 'customer-000361@aplibhaji.com', '#165, Block 3, MG Road 8, Sunrise Gardens', 'CUSTOMER-000361',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '96288f00-00e2-5377-90cc-b55c3e980a3d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a9be3eaf-fcba-570e-aeae-3e87e84bdd55'::uuid, 'authenticated', 'authenticated',
  'customer-000362@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Joshi", "phone": "9818720967", "address": "#329, Block 5, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "5eaea5ca-310f-5ddd-9d20-c38d65fdd818"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a9be3eaf-fcba-570e-aeae-3e87e84bdd55'::uuid, 'Rajesh Joshi', 'cust-362', 'customer-000362@aplibhaji.com', '#329, Block 5, MG Road 8, Sunrise Gardens', 'CUSTOMER-000362',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '5eaea5ca-310f-5ddd-9d20-c38d65fdd818'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '30318ff5-6993-511b-8f8b-17764b7a1262'::uuid, 'authenticated', 'authenticated',
  'customer-000363@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Singh", "phone": "9868624266", "address": "#150, Block 3, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "96288f00-00e2-5377-90cc-b55c3e980a3d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '30318ff5-6993-511b-8f8b-17764b7a1262'::uuid, 'Meena Singh', 'cust-363', 'customer-000363@aplibhaji.com', '#150, Block 3, MG Road 8, Sunrise Gardens', 'CUSTOMER-000363',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '96288f00-00e2-5377-90cc-b55c3e980a3d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1ca4aa97-601a-556b-9a73-a81f7508843a'::uuid, 'authenticated', 'authenticated',
  'customer-000364@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Verma", "phone": "9836067441", "address": "#216, Block 6, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "59660098-8ee7-526c-8954-f452b1151e3a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1ca4aa97-601a-556b-9a73-a81f7508843a'::uuid, 'Vijay Verma', 'cust-364', 'customer-000364@aplibhaji.com', '#216, Block 6, MG Road 8, Sunrise Gardens', 'CUSTOMER-000364',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '59660098-8ee7-526c-8954-f452b1151e3a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6d3d8008-e75c-5587-a521-a3c128dd0b67'::uuid, 'authenticated', 'authenticated',
  'customer-000365@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Rao", "phone": "9878742865", "address": "#381, Block 1, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "fb3b28bb-ffd2-5af6-b4b4-0ddebce432f8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6d3d8008-e75c-5587-a521-a3c128dd0b67'::uuid, 'Geeta Rao', 'cust-365', 'customer-000365@aplibhaji.com', '#381, Block 1, MG Road 8, Sunrise Gardens', 'CUSTOMER-000365',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, 'fb3b28bb-ffd2-5af6-b4b4-0ddebce432f8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c0f4b3f9-0a6f-59a8-8d3e-b63765f8ffa7'::uuid, 'authenticated', 'authenticated',
  'customer-000366@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Sharma", "phone": "9840460040", "address": "#322, Block 4, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "74ba855b-bccf-53f8-ba87-72425480d292"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c0f4b3f9-0a6f-59a8-8d3e-b63765f8ffa7'::uuid, 'Sneha Sharma', 'cust-366', 'customer-000366@aplibhaji.com', '#322, Block 4, MG Road 8, Sunrise Gardens', 'CUSTOMER-000366',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '74ba855b-bccf-53f8-ba87-72425480d292'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a0499f43-7a1d-5837-a4cd-231ab3bbe080'::uuid, 'authenticated', 'authenticated',
  'customer-000367@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Singh", "phone": "9839656630", "address": "#326, Block 4, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "74ba855b-bccf-53f8-ba87-72425480d292"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a0499f43-7a1d-5837-a4cd-231ab3bbe080'::uuid, 'Rajesh Singh', 'cust-367', 'customer-000367@aplibhaji.com', '#326, Block 4, MG Road 8, Sunrise Gardens', 'CUSTOMER-000367',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '74ba855b-bccf-53f8-ba87-72425480d292'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e42520a8-75f0-55d7-b82b-2e05020f2c4b'::uuid, 'authenticated', 'authenticated',
  'customer-000368@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Kulkarni", "phone": "9813428593", "address": "#266, Block 7, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "38deba4a-5240-56c3-9653-a77cd9e4c66c"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e42520a8-75f0-55d7-b82b-2e05020f2c4b'::uuid, 'Rahul Kulkarni', 'cust-368', 'customer-000368@aplibhaji.com', '#266, Block 7, MG Road 8, Sunrise Gardens', 'CUSTOMER-000368',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '38deba4a-5240-56c3-9653-a77cd9e4c66c'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4d7f2634-2ce4-52ae-95ef-2bc28e7ff892'::uuid, 'authenticated', 'authenticated',
  'customer-000369@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Patel", "phone": "9816459063", "address": "#268, Block 5, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "5eaea5ca-310f-5ddd-9d20-c38d65fdd818"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4d7f2634-2ce4-52ae-95ef-2bc28e7ff892'::uuid, 'Pooja Patel', 'cust-369', 'customer-000369@aplibhaji.com', '#268, Block 5, MG Road 8, Sunrise Gardens', 'CUSTOMER-000369',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '5eaea5ca-310f-5ddd-9d20-c38d65fdd818'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '92f3deed-b0f0-5268-82e6-307bf17d7d1a'::uuid, 'authenticated', 'authenticated',
  'customer-000370@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Nair", "phone": "9897561669", "address": "#389, Block 4, MG Road 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "9f989377-b9f8-5b66-b643-59e3b1dd3c72", "sub_road_id": "74ba855b-bccf-53f8-ba87-72425480d292"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '92f3deed-b0f0-5268-82e6-307bf17d7d1a'::uuid, 'Vijay Nair', 'cust-370', 'customer-000370@aplibhaji.com', '#389, Block 4, MG Road 8, Sunrise Gardens', 'CUSTOMER-000370',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '9f989377-b9f8-5b66-b643-59e3b1dd3c72'::uuid, '74ba855b-bccf-53f8-ba87-72425480d292'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '01471bbd-65dc-5475-94ff-acfeef47a03c'::uuid, 'authenticated', 'authenticated',
  'customer-000371@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Joshi", "phone": "9817725551", "address": "#219, Block 5, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "ed8cec98-fb3d-5b80-a2dc-f8f6ca2c9791"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '01471bbd-65dc-5475-94ff-acfeef47a03c'::uuid, 'Rahul Joshi', 'cust-371', 'customer-000371@aplibhaji.com', '#219, Block 5, Station Street 8, Sunrise Gardens', 'CUSTOMER-000371',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'ed8cec98-fb3d-5b80-a2dc-f8f6ca2c9791'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5b60b6e9-24ba-50ce-b908-f8f3cefc1be6'::uuid, 'authenticated', 'authenticated',
  'customer-000372@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Kulkarni", "phone": "9893420976", "address": "#202, Block 4, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "09956a33-e1c6-5d96-b6b4-7247453355f2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5b60b6e9-24ba-50ce-b908-f8f3cefc1be6'::uuid, 'Swati Kulkarni', 'cust-372', 'customer-000372@aplibhaji.com', '#202, Block 4, Station Street 8, Sunrise Gardens', 'CUSTOMER-000372',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '09956a33-e1c6-5d96-b6b4-7247453355f2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f79504b3-fb37-5316-81ce-e215c035916b'::uuid, 'authenticated', 'authenticated',
  'customer-000373@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Reddy", "phone": "9853586440", "address": "#160, Block 1, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "d2575613-8628-5e12-a432-fb925b23daba"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f79504b3-fb37-5316-81ce-e215c035916b'::uuid, 'Anita Reddy', 'cust-373', 'customer-000373@aplibhaji.com', '#160, Block 1, Station Street 8, Sunrise Gardens', 'CUSTOMER-000373',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'd2575613-8628-5e12-a432-fb925b23daba'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0981cb46-159d-5d80-ab8a-fa2bd801dcef'::uuid, 'authenticated', 'authenticated',
  'customer-000374@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Patel", "phone": "9869768134", "address": "#321, Block 4, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "09956a33-e1c6-5d96-b6b4-7247453355f2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0981cb46-159d-5d80-ab8a-fa2bd801dcef'::uuid, 'Suresh Patel', 'cust-374', 'customer-000374@aplibhaji.com', '#321, Block 4, Station Street 8, Sunrise Gardens', 'CUSTOMER-000374',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '09956a33-e1c6-5d96-b6b4-7247453355f2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8db630c2-663a-53da-b6d1-c0c9c1701e0a'::uuid, 'authenticated', 'authenticated',
  'customer-000375@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Patel", "phone": "9870502791", "address": "#291, Block 7, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "94b91c5c-f498-526f-b9f5-293d87d9f4d0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8db630c2-663a-53da-b6d1-c0c9c1701e0a'::uuid, 'Vikram Patel', 'cust-375', 'customer-000375@aplibhaji.com', '#291, Block 7, Station Street 8, Sunrise Gardens', 'CUSTOMER-000375',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '94b91c5c-f498-526f-b9f5-293d87d9f4d0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '05a64ae9-5b9f-5dbc-875d-6d0ea864b701'::uuid, 'authenticated', 'authenticated',
  'customer-000376@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Patel", "phone": "9889319641", "address": "#287, Block 8, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "11ff76c6-351d-5105-a26f-a0090c823235"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '05a64ae9-5b9f-5dbc-875d-6d0ea864b701'::uuid, 'Rahul Patel', 'cust-376', 'customer-000376@aplibhaji.com', '#287, Block 8, Station Street 8, Sunrise Gardens', 'CUSTOMER-000376',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '11ff76c6-351d-5105-a26f-a0090c823235'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6801e352-ad11-555b-b726-044b8da2b865'::uuid, 'authenticated', 'authenticated',
  'customer-000377@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Kumar", "phone": "9866151761", "address": "#214, Block 6, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "41852b80-0e5f-551f-9d7d-29742d1aab6d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6801e352-ad11-555b-b726-044b8da2b865'::uuid, 'Pooja Kumar', 'cust-377', 'customer-000377@aplibhaji.com', '#214, Block 6, Station Street 8, Sunrise Gardens', 'CUSTOMER-000377',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '41852b80-0e5f-551f-9d7d-29742d1aab6d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ee2f593a-3437-5d70-972d-601bc07b4e47'::uuid, 'authenticated', 'authenticated',
  'customer-000378@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Chawla", "phone": "9854294106", "address": "#235, Block 8, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "11ff76c6-351d-5105-a26f-a0090c823235"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ee2f593a-3437-5d70-972d-601bc07b4e47'::uuid, 'Suresh Chawla', 'cust-378', 'customer-000378@aplibhaji.com', '#235, Block 8, Station Street 8, Sunrise Gardens', 'CUSTOMER-000378',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, '11ff76c6-351d-5105-a26f-a0090c823235'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2d93e397-a2bd-53cb-9405-16bd95189a20'::uuid, 'authenticated', 'authenticated',
  'customer-000379@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Mehta", "phone": "9826411717", "address": "#342, Block 1, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "d2575613-8628-5e12-a432-fb925b23daba"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2d93e397-a2bd-53cb-9405-16bd95189a20'::uuid, 'Rajesh Mehta', 'cust-379', 'customer-000379@aplibhaji.com', '#342, Block 1, Station Street 8, Sunrise Gardens', 'CUSTOMER-000379',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'd2575613-8628-5e12-a432-fb925b23daba'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1229d20c-8b21-535c-83e2-c65a4c53cdd3'::uuid, 'authenticated', 'authenticated',
  'customer-000380@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Agarwal", "phone": "9820303509", "address": "#103, Block 5, Station Street 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2ce61724-9b17-5265-9df8-3079dfcd0d84", "sub_road_id": "ed8cec98-fb3d-5b80-a2dc-f8f6ca2c9791"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1229d20c-8b21-535c-83e2-c65a4c53cdd3'::uuid, 'Amit Agarwal', 'cust-380', 'customer-000380@aplibhaji.com', '#103, Block 5, Station Street 8, Sunrise Gardens', 'CUSTOMER-000380',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2ce61724-9b17-5265-9df8-3079dfcd0d84'::uuid, 'ed8cec98-fb3d-5b80-a2dc-f8f6ca2c9791'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '65b9a48c-f589-5a3e-8966-12b7efd6f217'::uuid, 'authenticated', 'authenticated',
  'customer-000381@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Singh", "phone": "9848731494", "address": "#309, Block 8, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "a0a1c6f3-c1c1-56ca-b087-eea0669cdbab"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '65b9a48c-f589-5a3e-8966-12b7efd6f217'::uuid, 'Manish Singh', 'cust-381', 'customer-000381@aplibhaji.com', '#309, Block 8, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000381',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'a0a1c6f3-c1c1-56ca-b087-eea0669cdbab'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '528505c7-c917-54ce-a8f0-86632c455d3e'::uuid, 'authenticated', 'authenticated',
  'customer-000382@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Jain", "phone": "9846965565", "address": "#298, Block 7, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '528505c7-c917-54ce-a8f0-86632c455d3e'::uuid, 'Sneha Jain', 'cust-382', 'customer-000382@aplibhaji.com', '#298, Block 7, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000382',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, '2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c6f8d9a2-23c0-511c-83ba-06bc7217300f'::uuid, 'authenticated', 'authenticated',
  'customer-000383@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kulkarni", "phone": "9860925623", "address": "#156, Block 3, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "c9c767a1-b892-5dc6-a3cd-3ff723433409"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c6f8d9a2-23c0-511c-83ba-06bc7217300f'::uuid, 'Rohan Kulkarni', 'cust-383', 'customer-000383@aplibhaji.com', '#156, Block 3, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000383',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'c9c767a1-b892-5dc6-a3cd-3ff723433409'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f56b0ea2-a238-5df1-8c15-35c3481b5fc6'::uuid, 'authenticated', 'authenticated',
  'customer-000384@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Singh", "phone": "9879271691", "address": "#184, Block 8, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "a0a1c6f3-c1c1-56ca-b087-eea0669cdbab"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f56b0ea2-a238-5df1-8c15-35c3481b5fc6'::uuid, 'Meena Singh', 'cust-384', 'customer-000384@aplibhaji.com', '#184, Block 8, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000384',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'a0a1c6f3-c1c1-56ca-b087-eea0669cdbab'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '299d350a-0256-5c40-9a68-c864758a701d'::uuid, 'authenticated', 'authenticated',
  'customer-000385@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Reddy", "phone": "9862091361", "address": "#130, Block 7, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '299d350a-0256-5c40-9a68-c864758a701d'::uuid, 'Swati Reddy', 'cust-385', 'customer-000385@aplibhaji.com', '#130, Block 7, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000385',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, '2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '801c2a06-a3d9-53c6-8602-0e0bb51c3eda'::uuid, 'authenticated', 'authenticated',
  'customer-000386@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Kulkarni", "phone": "9841768588", "address": "#356, Block 7, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '801c2a06-a3d9-53c6-8602-0e0bb51c3eda'::uuid, 'Deepak Kulkarni', 'cust-386', 'customer-000386@aplibhaji.com', '#356, Block 7, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000386',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, '2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b23bb822-47f8-52b5-aaf1-310ec7ae378f'::uuid, 'authenticated', 'authenticated',
  'customer-000387@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Mehta", "phone": "9848538043", "address": "#172, Block 7, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b23bb822-47f8-52b5-aaf1-310ec7ae378f'::uuid, 'Deepak Mehta', 'cust-387', 'customer-000387@aplibhaji.com', '#172, Block 7, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000387',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, '2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '85bfae9a-af00-5d86-a66b-81b712a14947'::uuid, 'authenticated', 'authenticated',
  'customer-000388@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Jain", "phone": "9812545265", "address": "#128, Block 2, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "c1b9f9e5-0a00-5ac4-a0af-ba6bbf41900d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '85bfae9a-af00-5d86-a66b-81b712a14947'::uuid, 'Suresh Jain', 'cust-388', 'customer-000388@aplibhaji.com', '#128, Block 2, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000388',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'c1b9f9e5-0a00-5ac4-a0af-ba6bbf41900d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2392478f-a7ae-5e8e-bc87-889335879270'::uuid, 'authenticated', 'authenticated',
  'customer-000389@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Rao", "phone": "9869290957", "address": "#399, Block 2, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "c1b9f9e5-0a00-5ac4-a0af-ba6bbf41900d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2392478f-a7ae-5e8e-bc87-889335879270'::uuid, 'Vikram Rao', 'cust-389', 'customer-000389@aplibhaji.com', '#399, Block 2, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000389',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, 'c1b9f9e5-0a00-5ac4-a0af-ba6bbf41900d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2efb8608-bb30-5177-ba5e-39e5b0ca58cb'::uuid, 'authenticated', 'authenticated',
  'customer-000390@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Gupta", "phone": "9833561580", "address": "#163, Block 7, Park Avenue 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "65b17ea4-37d7-5352-986a-de9180010177", "sub_road_id": "2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2efb8608-bb30-5177-ba5e-39e5b0ca58cb'::uuid, 'Sunita Gupta', 'cust-390', 'customer-000390@aplibhaji.com', '#163, Block 7, Park Avenue 8, Sunrise Gardens', 'CUSTOMER-000390',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '65b17ea4-37d7-5352-986a-de9180010177'::uuid, '2581eebc-ad1d-53e2-8bf2-0d90b4bf6c7d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '31f546b7-5c73-5e99-b714-df2071b22b05'::uuid, 'authenticated', 'authenticated',
  'customer-000391@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Deshmukh", "phone": "9876068465", "address": "#274, Block 2, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "c112dc8a-9703-5f0b-b1b6-b3653aeb91af"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '31f546b7-5c73-5e99-b714-df2071b22b05'::uuid, 'Vikram Deshmukh', 'cust-391', 'customer-000391@aplibhaji.com', '#274, Block 2, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000391',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'c112dc8a-9703-5f0b-b1b6-b3653aeb91af'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '13bb1ef2-c980-5310-be4a-acaa4c00419d'::uuid, 'authenticated', 'authenticated',
  'customer-000392@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Mehta", "phone": "9889507845", "address": "#286, Block 8, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "38c5695b-9636-583e-8f36-3387434430c8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '13bb1ef2-c980-5310-be4a-acaa4c00419d'::uuid, 'Ajay Mehta', 'cust-392', 'customer-000392@aplibhaji.com', '#286, Block 8, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000392',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '38c5695b-9636-583e-8f36-3387434430c8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6862f873-f87b-59cc-9809-0ef3bd58005e'::uuid, 'authenticated', 'authenticated',
  'customer-000393@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Jain", "phone": "9834421350", "address": "#246, Block 3, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "56bc8d5c-f97c-5022-8969-fdcdd3f8706a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6862f873-f87b-59cc-9809-0ef3bd58005e'::uuid, 'Vijay Jain', 'cust-393', 'customer-000393@aplibhaji.com', '#246, Block 3, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000393',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '56bc8d5c-f97c-5022-8969-fdcdd3f8706a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '713c1d5a-a5ec-51ec-b895-d2ae7b5c1d3a'::uuid, 'authenticated', 'authenticated',
  'customer-000394@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Agarwal", "phone": "9815014541", "address": "#141, Block 2, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "c112dc8a-9703-5f0b-b1b6-b3653aeb91af"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '713c1d5a-a5ec-51ec-b895-d2ae7b5c1d3a'::uuid, 'Neha Agarwal', 'cust-394', 'customer-000394@aplibhaji.com', '#141, Block 2, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000394',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'c112dc8a-9703-5f0b-b1b6-b3653aeb91af'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5e286d72-7bca-56d6-8867-82d65e11fa64'::uuid, 'authenticated', 'authenticated',
  'customer-000395@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Rao", "phone": "9828799811", "address": "#301, Block 8, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "38c5695b-9636-583e-8f36-3387434430c8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5e286d72-7bca-56d6-8867-82d65e11fa64'::uuid, 'Pooja Rao', 'cust-395', 'customer-000395@aplibhaji.com', '#301, Block 8, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000395',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '38c5695b-9636-583e-8f36-3387434430c8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '634ef721-1803-52d7-a5f3-d0c08d564a99'::uuid, 'authenticated', 'authenticated',
  'customer-000396@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Mehta", "phone": "9827030948", "address": "#200, Block 1, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "f486b2f7-8ba5-5b6f-8730-c0b39999e0c1"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '634ef721-1803-52d7-a5f3-d0c08d564a99'::uuid, 'Manish Mehta', 'cust-396', 'customer-000396@aplibhaji.com', '#200, Block 1, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000396',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'f486b2f7-8ba5-5b6f-8730-c0b39999e0c1'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '13366e0e-0f58-56f4-ae7d-9dd55a7e994e'::uuid, 'authenticated', 'authenticated',
  'customer-000397@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Reddy", "phone": "9882010222", "address": "#342, Block 6, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "4fdc13b1-cf67-5c7e-a73a-2121a1e24d80"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '13366e0e-0f58-56f4-ae7d-9dd55a7e994e'::uuid, 'Vijay Reddy', 'cust-397', 'customer-000397@aplibhaji.com', '#342, Block 6, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000397',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '4fdc13b1-cf67-5c7e-a73a-2121a1e24d80'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e5dee3da-0a48-5565-a3eb-d345ab4ed30c'::uuid, 'authenticated', 'authenticated',
  'customer-000398@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Gupta", "phone": "9824879973", "address": "#114, Block 8, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "38c5695b-9636-583e-8f36-3387434430c8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e5dee3da-0a48-5565-a3eb-d345ab4ed30c'::uuid, 'Rahul Gupta', 'cust-398', 'customer-000398@aplibhaji.com', '#114, Block 8, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000398',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '38c5695b-9636-583e-8f36-3387434430c8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'bdebe86d-50d3-5cf4-88e3-c62a68c568dc'::uuid, 'authenticated', 'authenticated',
  'customer-000399@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Deshmukh", "phone": "9848666936", "address": "#253, Block 4, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "012e8356-2f7f-556d-9efb-0c4abe416d35"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'bdebe86d-50d3-5cf4-88e3-c62a68c568dc'::uuid, 'Neha Deshmukh', 'cust-399', 'customer-000399@aplibhaji.com', '#253, Block 4, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000399',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, '012e8356-2f7f-556d-9efb-0c4abe416d35'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0be8bd63-becd-5711-8c75-fd0e5ba4da23'::uuid, 'authenticated', 'authenticated',
  'customer-000400@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Singh", "phone": "9874431066", "address": "#254, Block 5, Green Lane 8, Sunrise Gardens", "area_id": "675396a6-8cac-5e18-a301-63a79185a559", "road_id": "2b1fa0bd-a353-5359-99e0-56c576b7f9b1", "sub_road_id": "f3dd618f-878d-5449-b0de-7cc96e9d427b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0be8bd63-becd-5711-8c75-fd0e5ba4da23'::uuid, 'Neha Singh', 'cust-400', 'customer-000400@aplibhaji.com', '#254, Block 5, Green Lane 8, Sunrise Gardens', 'CUSTOMER-000400',
  '675396a6-8cac-5e18-a301-63a79185a559'::uuid, '2b1fa0bd-a353-5359-99e0-56c576b7f9b1'::uuid, 'f3dd618f-878d-5449-b0de-7cc96e9d427b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'dcc446e3-f456-5ca3-981c-249244e81ced'::uuid, 'authenticated', 'authenticated',
  'customer-000401@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Singh", "phone": "9874149520", "address": "#305, Block 6, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "a66957b7-5433-57f5-ad15-2838c088315f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'dcc446e3-f456-5ca3-981c-249244e81ced'::uuid, 'Vikram Singh', 'cust-401', 'customer-000401@aplibhaji.com', '#305, Block 6, Market Road 9, Royal Palms Estate', 'CUSTOMER-000401',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'a66957b7-5433-57f5-ad15-2838c088315f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8f3d29e2-cd33-547e-86e1-343de41bf39c'::uuid, 'authenticated', 'authenticated',
  'customer-000402@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Sharma", "phone": "9893231055", "address": "#252, Block 3, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "e181c86f-d8c5-5c49-8627-82fa07c857ec"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8f3d29e2-cd33-547e-86e1-343de41bf39c'::uuid, 'Swati Sharma', 'cust-402', 'customer-000402@aplibhaji.com', '#252, Block 3, Market Road 9, Royal Palms Estate', 'CUSTOMER-000402',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'e181c86f-d8c5-5c49-8627-82fa07c857ec'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '88a7538f-75b8-5241-b435-35ec759c6f11'::uuid, 'authenticated', 'authenticated',
  'customer-000403@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Sharma", "phone": "9822265075", "address": "#370, Block 3, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "e181c86f-d8c5-5c49-8627-82fa07c857ec"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '88a7538f-75b8-5241-b435-35ec759c6f11'::uuid, 'Neha Sharma', 'cust-403', 'customer-000403@aplibhaji.com', '#370, Block 3, Market Road 9, Royal Palms Estate', 'CUSTOMER-000403',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'e181c86f-d8c5-5c49-8627-82fa07c857ec'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '75643b37-337f-505d-96b1-3647c54e3b98'::uuid, 'authenticated', 'authenticated',
  'customer-000404@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Verma", "phone": "9898272283", "address": "#192, Block 7, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "b67d8daa-156b-52ac-a618-2e2451509142"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '75643b37-337f-505d-96b1-3647c54e3b98'::uuid, 'Suresh Verma', 'cust-404', 'customer-000404@aplibhaji.com', '#192, Block 7, Market Road 9, Royal Palms Estate', 'CUSTOMER-000404',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'b67d8daa-156b-52ac-a618-2e2451509142'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2a69bbf6-1501-5540-ab9b-ecf67f9b2091'::uuid, 'authenticated', 'authenticated',
  'customer-000405@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Joshi", "phone": "9858381837", "address": "#197, Block 6, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "a66957b7-5433-57f5-ad15-2838c088315f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2a69bbf6-1501-5540-ab9b-ecf67f9b2091'::uuid, 'Vijay Joshi', 'cust-405', 'customer-000405@aplibhaji.com', '#197, Block 6, Market Road 9, Royal Palms Estate', 'CUSTOMER-000405',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'a66957b7-5433-57f5-ad15-2838c088315f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2845ffce-0f7f-5c92-9811-5f03d1b3aba2'::uuid, 'authenticated', 'authenticated',
  'customer-000406@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Chawla", "phone": "9847926041", "address": "#397, Block 4, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "d48b8e11-c0f2-5404-95f0-d5d7459c4323"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2845ffce-0f7f-5c92-9811-5f03d1b3aba2'::uuid, 'Pooja Chawla', 'cust-406', 'customer-000406@aplibhaji.com', '#397, Block 4, Market Road 9, Royal Palms Estate', 'CUSTOMER-000406',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'd48b8e11-c0f2-5404-95f0-d5d7459c4323'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b19c0e48-0f3c-5aa4-9a27-2044797b8f07'::uuid, 'authenticated', 'authenticated',
  'customer-000407@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Jain", "phone": "9820305798", "address": "#212, Block 5, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "418f3f4d-0d20-50f9-8b53-6a52e8230316"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b19c0e48-0f3c-5aa4-9a27-2044797b8f07'::uuid, 'Neha Jain', 'cust-407', 'customer-000407@aplibhaji.com', '#212, Block 5, Market Road 9, Royal Palms Estate', 'CUSTOMER-000407',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, '418f3f4d-0d20-50f9-8b53-6a52e8230316'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '89b4dd50-e115-59b6-827f-beb0fab660f1'::uuid, 'authenticated', 'authenticated',
  'customer-000408@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Agarwal", "phone": "9888458035", "address": "#255, Block 5, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "418f3f4d-0d20-50f9-8b53-6a52e8230316"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '89b4dd50-e115-59b6-827f-beb0fab660f1'::uuid, 'Suresh Agarwal', 'cust-408', 'customer-000408@aplibhaji.com', '#255, Block 5, Market Road 9, Royal Palms Estate', 'CUSTOMER-000408',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, '418f3f4d-0d20-50f9-8b53-6a52e8230316'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5f5015cc-eb33-5b6d-bdf4-e67b8bfce1d8'::uuid, 'authenticated', 'authenticated',
  'customer-000409@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Jain", "phone": "9886844850", "address": "#183, Block 7, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "b67d8daa-156b-52ac-a618-2e2451509142"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5f5015cc-eb33-5b6d-bdf4-e67b8bfce1d8'::uuid, 'Meena Jain', 'cust-409', 'customer-000409@aplibhaji.com', '#183, Block 7, Market Road 9, Royal Palms Estate', 'CUSTOMER-000409',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'b67d8daa-156b-52ac-a618-2e2451509142'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7803cac3-e4be-5971-b3e6-3b4ae7dfefea'::uuid, 'authenticated', 'authenticated',
  'customer-000410@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Mehta", "phone": "9874249759", "address": "#160, Block 4, Market Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "1f28f0fb-3c94-503a-9fad-3eb4047bd144", "sub_road_id": "d48b8e11-c0f2-5404-95f0-d5d7459c4323"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7803cac3-e4be-5971-b3e6-3b4ae7dfefea'::uuid, 'Ramesh Mehta', 'cust-410', 'customer-000410@aplibhaji.com', '#160, Block 4, Market Road 9, Royal Palms Estate', 'CUSTOMER-000410',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '1f28f0fb-3c94-503a-9fad-3eb4047bd144'::uuid, 'd48b8e11-c0f2-5404-95f0-d5d7459c4323'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7b68c4a7-ee11-517c-866d-d2986c36405e'::uuid, 'authenticated', 'authenticated',
  'customer-000411@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Gupta", "phone": "9829037374", "address": "#399, Block 1, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "8d47e0e9-edec-5748-ab50-7ca414907808"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7b68c4a7-ee11-517c-866d-d2986c36405e'::uuid, 'Sunita Gupta', 'cust-411', 'customer-000411@aplibhaji.com', '#399, Block 1, MG Road 9, Royal Palms Estate', 'CUSTOMER-000411',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '8d47e0e9-edec-5748-ab50-7ca414907808'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6274608a-25cb-587c-8709-31196f440584'::uuid, 'authenticated', 'authenticated',
  'customer-000412@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Mehta", "phone": "9819213202", "address": "#301, Block 4, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "d9cb2203-1ccb-5f56-83d4-1f71db714e90"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6274608a-25cb-587c-8709-31196f440584'::uuid, 'Sneha Mehta', 'cust-412', 'customer-000412@aplibhaji.com', '#301, Block 4, MG Road 9, Royal Palms Estate', 'CUSTOMER-000412',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'd9cb2203-1ccb-5f56-83d4-1f71db714e90'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2afe92d4-6050-53eb-acb3-310fa5f01285'::uuid, 'authenticated', 'authenticated',
  'customer-000413@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Kulkarni", "phone": "9824304092", "address": "#328, Block 1, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "8d47e0e9-edec-5748-ab50-7ca414907808"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2afe92d4-6050-53eb-acb3-310fa5f01285'::uuid, 'Deepak Kulkarni', 'cust-413', 'customer-000413@aplibhaji.com', '#328, Block 1, MG Road 9, Royal Palms Estate', 'CUSTOMER-000413',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '8d47e0e9-edec-5748-ab50-7ca414907808'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '1462b493-1bf8-5b5f-91f6-fdb2284f609e'::uuid, 'authenticated', 'authenticated',
  'customer-000414@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Singh", "phone": "9826476810", "address": "#331, Block 3, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "8e6d9cd1-2434-510f-82f0-6a9fcc3a3519"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '1462b493-1bf8-5b5f-91f6-fdb2284f609e'::uuid, 'Deepak Singh', 'cust-414', 'customer-000414@aplibhaji.com', '#331, Block 3, MG Road 9, Royal Palms Estate', 'CUSTOMER-000414',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '8e6d9cd1-2434-510f-82f0-6a9fcc3a3519'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6c461da5-ccdf-5a06-9b2d-09c803c86832'::uuid, 'authenticated', 'authenticated',
  'customer-000415@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Chawla", "phone": "9818059686", "address": "#190, Block 8, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "9cba1288-0235-54c4-ad60-1ab83e429bab"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6c461da5-ccdf-5a06-9b2d-09c803c86832'::uuid, 'Kavita Chawla', 'cust-415', 'customer-000415@aplibhaji.com', '#190, Block 8, MG Road 9, Royal Palms Estate', 'CUSTOMER-000415',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '9cba1288-0235-54c4-ad60-1ab83e429bab'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '16f438d2-067a-5f9f-8bd1-6b70ac0c3226'::uuid, 'authenticated', 'authenticated',
  'customer-000416@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Kulkarni", "phone": "9871620048", "address": "#288, Block 7, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "7939e55b-be68-5e93-b28d-d83d681ca639"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '16f438d2-067a-5f9f-8bd1-6b70ac0c3226'::uuid, 'Rajesh Kulkarni', 'cust-416', 'customer-000416@aplibhaji.com', '#288, Block 7, MG Road 9, Royal Palms Estate', 'CUSTOMER-000416',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '7939e55b-be68-5e93-b28d-d83d681ca639'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6b6e440f-717b-5bfc-981a-1bc2005c92b1'::uuid, 'authenticated', 'authenticated',
  'customer-000417@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Kulkarni", "phone": "9877664864", "address": "#269, Block 5, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "64d77408-59ad-5484-a6e9-05792232abd6"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6b6e440f-717b-5bfc-981a-1bc2005c92b1'::uuid, 'Priya Kulkarni', 'cust-417', 'customer-000417@aplibhaji.com', '#269, Block 5, MG Road 9, Royal Palms Estate', 'CUSTOMER-000417',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '64d77408-59ad-5484-a6e9-05792232abd6'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0e7b50d1-be95-5de5-aa5c-84535c8dcc5b'::uuid, 'authenticated', 'authenticated',
  'customer-000418@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Gupta", "phone": "9858013072", "address": "#378, Block 8, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "9cba1288-0235-54c4-ad60-1ab83e429bab"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0e7b50d1-be95-5de5-aa5c-84535c8dcc5b'::uuid, 'Ananya Gupta', 'cust-418', 'customer-000418@aplibhaji.com', '#378, Block 8, MG Road 9, Royal Palms Estate', 'CUSTOMER-000418',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, '9cba1288-0235-54c4-ad60-1ab83e429bab'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0c586052-a1fc-5b95-aa6c-7ed6ca05fd12'::uuid, 'authenticated', 'authenticated',
  'customer-000419@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Patel", "phone": "9890195498", "address": "#341, Block 4, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "d9cb2203-1ccb-5f56-83d4-1f71db714e90"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0c586052-a1fc-5b95-aa6c-7ed6ca05fd12'::uuid, 'Ramesh Patel', 'cust-419', 'customer-000419@aplibhaji.com', '#341, Block 4, MG Road 9, Royal Palms Estate', 'CUSTOMER-000419',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'd9cb2203-1ccb-5f56-83d4-1f71db714e90'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a176dbd4-c9d4-57fb-a73a-a6ac239d3ef0'::uuid, 'authenticated', 'authenticated',
  'customer-000420@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Mehta", "phone": "9825297692", "address": "#137, Block 4, MG Road 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "3e6522ca-d878-5d24-8c83-c2c62e90b645", "sub_road_id": "d9cb2203-1ccb-5f56-83d4-1f71db714e90"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a176dbd4-c9d4-57fb-a73a-a6ac239d3ef0'::uuid, 'Vikram Mehta', 'cust-420', 'customer-000420@aplibhaji.com', '#137, Block 4, MG Road 9, Royal Palms Estate', 'CUSTOMER-000420',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, '3e6522ca-d878-5d24-8c83-c2c62e90b645'::uuid, 'd9cb2203-1ccb-5f56-83d4-1f71db714e90'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '85e61bf1-61c3-5d59-9387-fbc560af6611'::uuid, 'authenticated', 'authenticated',
  'customer-000421@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Chawla", "phone": "9827155873", "address": "#197, Block 4, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "f7b7f811-ffde-510a-b2da-150f3f7e64ec"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '85e61bf1-61c3-5d59-9387-fbc560af6611'::uuid, 'Geeta Chawla', 'cust-421', 'customer-000421@aplibhaji.com', '#197, Block 4, Station Street 9, Royal Palms Estate', 'CUSTOMER-000421',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'f7b7f811-ffde-510a-b2da-150f3f7e64ec'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cec48f88-7503-5631-9792-112e4cc7a622'::uuid, 'authenticated', 'authenticated',
  'customer-000422@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Mehta", "phone": "9893497003", "address": "#119, Block 2, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "2b08aa54-9e60-5712-b543-dfcf25004e56"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cec48f88-7503-5631-9792-112e4cc7a622'::uuid, 'Kavita Mehta', 'cust-422', 'customer-000422@aplibhaji.com', '#119, Block 2, Station Street 9, Royal Palms Estate', 'CUSTOMER-000422',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '2b08aa54-9e60-5712-b543-dfcf25004e56'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5138d184-83c3-55a4-b098-57781f14452c'::uuid, 'authenticated', 'authenticated',
  'customer-000423@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Priya Kumar", "phone": "9883297737", "address": "#161, Block 6, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "298d73bb-3adc-53c7-8d4f-7231fb02c803"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5138d184-83c3-55a4-b098-57781f14452c'::uuid, 'Priya Kumar', 'cust-423', 'customer-000423@aplibhaji.com', '#161, Block 6, Station Street 9, Royal Palms Estate', 'CUSTOMER-000423',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '298d73bb-3adc-53c7-8d4f-7231fb02c803'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f88bdb48-27ec-5edd-8b03-a42a7a7f84f4'::uuid, 'authenticated', 'authenticated',
  'customer-000424@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Agarwal", "phone": "9836185527", "address": "#134, Block 8, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "767f3099-d50c-5fa7-b863-c4f780aa6348"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f88bdb48-27ec-5edd-8b03-a42a7a7f84f4'::uuid, 'Suresh Agarwal', 'cust-424', 'customer-000424@aplibhaji.com', '#134, Block 8, Station Street 9, Royal Palms Estate', 'CUSTOMER-000424',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '767f3099-d50c-5fa7-b863-c4f780aa6348'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8cb32f54-9439-5907-a9d5-f7b9d9d13778'::uuid, 'authenticated', 'authenticated',
  'customer-000425@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Kumar", "phone": "9892645156", "address": "#151, Block 2, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "2b08aa54-9e60-5712-b543-dfcf25004e56"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8cb32f54-9439-5907-a9d5-f7b9d9d13778'::uuid, 'Sunita Kumar', 'cust-425', 'customer-000425@aplibhaji.com', '#151, Block 2, Station Street 9, Royal Palms Estate', 'CUSTOMER-000425',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '2b08aa54-9e60-5712-b543-dfcf25004e56'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd0c010f1-726c-5cb3-b186-35d9300fe7e7'::uuid, 'authenticated', 'authenticated',
  'customer-000426@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Kumar", "phone": "9845337030", "address": "#348, Block 5, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "322e0a98-0765-5483-a011-1dde9e7f7ab2"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd0c010f1-726c-5cb3-b186-35d9300fe7e7'::uuid, 'Sunita Kumar', 'cust-426', 'customer-000426@aplibhaji.com', '#348, Block 5, Station Street 9, Royal Palms Estate', 'CUSTOMER-000426',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '322e0a98-0765-5483-a011-1dde9e7f7ab2'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2461fa14-c183-57c7-923c-25ccdbe90394'::uuid, 'authenticated', 'authenticated',
  'customer-000427@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Rao", "phone": "9882009161", "address": "#318, Block 6, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "298d73bb-3adc-53c7-8d4f-7231fb02c803"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2461fa14-c183-57c7-923c-25ccdbe90394'::uuid, 'Deepak Rao', 'cust-427', 'customer-000427@aplibhaji.com', '#318, Block 6, Station Street 9, Royal Palms Estate', 'CUSTOMER-000427',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '298d73bb-3adc-53c7-8d4f-7231fb02c803'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a2e768df-636e-5d8b-aaef-11f12c0eb721'::uuid, 'authenticated', 'authenticated',
  'customer-000428@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Jain", "phone": "9872167794", "address": "#334, Block 3, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "98b3165f-0032-5872-b528-d517c81cc0d7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a2e768df-636e-5d8b-aaef-11f12c0eb721'::uuid, 'Sneha Jain', 'cust-428', 'customer-000428@aplibhaji.com', '#334, Block 3, Station Street 9, Royal Palms Estate', 'CUSTOMER-000428',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '98b3165f-0032-5872-b528-d517c81cc0d7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'b486f423-c242-50db-bdb7-78b180525041'::uuid, 'authenticated', 'authenticated',
  'customer-000429@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Singh", "phone": "9838686834", "address": "#158, Block 3, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "98b3165f-0032-5872-b528-d517c81cc0d7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'b486f423-c242-50db-bdb7-78b180525041'::uuid, 'Ajay Singh', 'cust-429', 'customer-000429@aplibhaji.com', '#158, Block 3, Station Street 9, Royal Palms Estate', 'CUSTOMER-000429',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, '98b3165f-0032-5872-b528-d517c81cc0d7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8ddade2f-6679-57e0-b760-c2bf4f51bf6e'::uuid, 'authenticated', 'authenticated',
  'customer-000430@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sneha Chawla", "phone": "9883182064", "address": "#125, Block 4, Station Street 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "e3623b9c-9e48-523c-bc47-22419827558d", "sub_road_id": "f7b7f811-ffde-510a-b2da-150f3f7e64ec"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8ddade2f-6679-57e0-b760-c2bf4f51bf6e'::uuid, 'Sneha Chawla', 'cust-430', 'customer-000430@aplibhaji.com', '#125, Block 4, Station Street 9, Royal Palms Estate', 'CUSTOMER-000430',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'e3623b9c-9e48-523c-bc47-22419827558d'::uuid, 'f7b7f811-ffde-510a-b2da-150f3f7e64ec'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd99792e7-def0-5b5b-91b5-bc8192e1bb91'::uuid, 'authenticated', 'authenticated',
  'customer-000431@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Gupta", "phone": "9896818235", "address": "#125, Block 8, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "845954dc-4d95-55f9-bed1-3262a6e623ba"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd99792e7-def0-5b5b-91b5-bc8192e1bb91'::uuid, 'Manish Gupta', 'cust-431', 'customer-000431@aplibhaji.com', '#125, Block 8, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000431',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '845954dc-4d95-55f9-bed1-3262a6e623ba'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '51f8c45e-6db9-58be-be1d-1af4b311015a'::uuid, 'authenticated', 'authenticated',
  'customer-000432@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Agarwal", "phone": "9899261327", "address": "#131, Block 4, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "6940fc5d-6582-500c-be09-f624b23f6615"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '51f8c45e-6db9-58be-be1d-1af4b311015a'::uuid, 'Geeta Agarwal', 'cust-432', 'customer-000432@aplibhaji.com', '#131, Block 4, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000432',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '6940fc5d-6582-500c-be09-f624b23f6615'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'be5707e4-2dcd-5e73-bf1f-78f410d37f70'::uuid, 'authenticated', 'authenticated',
  'customer-000433@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Reddy", "phone": "9858931554", "address": "#308, Block 2, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "035734b6-855d-5bba-91d3-06b851c0ae25"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'be5707e4-2dcd-5e73-bf1f-78f410d37f70'::uuid, 'Deepak Reddy', 'cust-433', 'customer-000433@aplibhaji.com', '#308, Block 2, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000433',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '035734b6-855d-5bba-91d3-06b851c0ae25'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '312da01f-f9b9-5ee6-bd13-90fb31c7e774'::uuid, 'authenticated', 'authenticated',
  'customer-000434@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kulkarni", "phone": "9828676099", "address": "#177, Block 2, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "035734b6-855d-5bba-91d3-06b851c0ae25"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '312da01f-f9b9-5ee6-bd13-90fb31c7e774'::uuid, 'Rohan Kulkarni', 'cust-434', 'customer-000434@aplibhaji.com', '#177, Block 2, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000434',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '035734b6-855d-5bba-91d3-06b851c0ae25'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '429bebbd-351c-508e-b0d7-779a506dd9e5'::uuid, 'authenticated', 'authenticated',
  'customer-000435@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Gupta", "phone": "9845356581", "address": "#230, Block 6, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "c520b532-05a5-5a46-81f4-e9f51cb0ff5b"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '429bebbd-351c-508e-b0d7-779a506dd9e5'::uuid, 'Sunita Gupta', 'cust-435', 'customer-000435@aplibhaji.com', '#230, Block 6, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000435',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'c520b532-05a5-5a46-81f4-e9f51cb0ff5b'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '667406ff-04f8-5f54-9703-acecef537967'::uuid, 'authenticated', 'authenticated',
  'customer-000436@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Reddy", "phone": "9862726702", "address": "#162, Block 5, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "4b3817c7-6211-5e6d-9461-9899e293d723"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '667406ff-04f8-5f54-9703-acecef537967'::uuid, 'Vijay Reddy', 'cust-436', 'customer-000436@aplibhaji.com', '#162, Block 5, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000436',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '4b3817c7-6211-5e6d-9461-9899e293d723'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '96011dae-ce4c-556b-8c1e-00a8432149f1'::uuid, 'authenticated', 'authenticated',
  'customer-000437@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Kumar", "phone": "9895163857", "address": "#220, Block 7, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "5f712bbc-b0c8-500b-a2d5-96f319c0f6b9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '96011dae-ce4c-556b-8c1e-00a8432149f1'::uuid, 'Pooja Kumar', 'cust-437', 'customer-000437@aplibhaji.com', '#220, Block 7, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000437',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '5f712bbc-b0c8-500b-a2d5-96f319c0f6b9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cb87a7f7-6dd3-57d0-9f67-21d1bbda5530'::uuid, 'authenticated', 'authenticated',
  'customer-000438@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Sharma", "phone": "9892226596", "address": "#363, Block 7, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "5f712bbc-b0c8-500b-a2d5-96f319c0f6b9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cb87a7f7-6dd3-57d0-9f67-21d1bbda5530'::uuid, 'Vikram Sharma', 'cust-438', 'customer-000438@aplibhaji.com', '#363, Block 7, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000438',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, '5f712bbc-b0c8-500b-a2d5-96f319c0f6b9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9db22b9c-db3c-5d44-bb0e-067f96d23a41'::uuid, 'authenticated', 'authenticated',
  'customer-000439@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Deshmukh", "phone": "9867213912", "address": "#332, Block 3, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "aeadde06-48c4-5cdb-88ba-c843f5722320"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9db22b9c-db3c-5d44-bb0e-067f96d23a41'::uuid, 'Amit Deshmukh', 'cust-439', 'customer-000439@aplibhaji.com', '#332, Block 3, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000439',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'aeadde06-48c4-5cdb-88ba-c843f5722320'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6183dff9-efb2-5e9b-9bd5-24b8f46d375e'::uuid, 'authenticated', 'authenticated',
  'customer-000440@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Rao", "phone": "9854212908", "address": "#284, Block 1, Park Avenue 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "bbb30289-0367-5f9b-a429-2e032a1bd150", "sub_road_id": "d3743f56-9259-5524-b8a2-8531af509ab8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6183dff9-efb2-5e9b-9bd5-24b8f46d375e'::uuid, 'Ananya Rao', 'cust-440', 'customer-000440@aplibhaji.com', '#284, Block 1, Park Avenue 9, Royal Palms Estate', 'CUSTOMER-000440',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'bbb30289-0367-5f9b-a429-2e032a1bd150'::uuid, 'd3743f56-9259-5524-b8a2-8531af509ab8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4d8990e7-f6b0-5389-9862-56e81854f400'::uuid, 'authenticated', 'authenticated',
  'customer-000441@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Joshi", "phone": "9827728918", "address": "#147, Block 1, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "5a8e923f-eb15-513b-b28e-e87b55ad4a78"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4d8990e7-f6b0-5389-9862-56e81854f400'::uuid, 'Deepak Joshi', 'cust-441', 'customer-000441@aplibhaji.com', '#147, Block 1, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000441',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, '5a8e923f-eb15-513b-b28e-e87b55ad4a78'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4d594f39-058c-5171-9476-275d83c88316'::uuid, 'authenticated', 'authenticated',
  'customer-000442@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Rao", "phone": "9819165681", "address": "#152, Block 5, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "f43f4b50-2237-528b-81a2-6d34c671ebd5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4d594f39-058c-5171-9476-275d83c88316'::uuid, 'Anita Rao', 'cust-442', 'customer-000442@aplibhaji.com', '#152, Block 5, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000442',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'f43f4b50-2237-528b-81a2-6d34c671ebd5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a91f34b6-e67c-558d-a143-8f2ccd913acc'::uuid, 'authenticated', 'authenticated',
  'customer-000443@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Deshmukh", "phone": "9854447113", "address": "#170, Block 8, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "83d465fd-b961-5e9c-be5a-6cc8bd2dfe96"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a91f34b6-e67c-558d-a143-8f2ccd913acc'::uuid, 'Ajay Deshmukh', 'cust-443', 'customer-000443@aplibhaji.com', '#170, Block 8, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000443',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, '83d465fd-b961-5e9c-be5a-6cc8bd2dfe96'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '3eafa7c5-4795-57fb-a952-caa3cdca8539'::uuid, 'authenticated', 'authenticated',
  'customer-000444@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Kulkarni", "phone": "9838502004", "address": "#237, Block 6, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "4eef933a-088f-57fe-952a-3c86864b3301"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '3eafa7c5-4795-57fb-a952-caa3cdca8539'::uuid, 'Amit Kulkarni', 'cust-444', 'customer-000444@aplibhaji.com', '#237, Block 6, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000444',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, '4eef933a-088f-57fe-952a-3c86864b3301'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '75a875ae-ecd2-5869-8352-fc81327d9341'::uuid, 'authenticated', 'authenticated',
  'customer-000445@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Deshmukh", "phone": "9897320955", "address": "#161, Block 5, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "f43f4b50-2237-528b-81a2-6d34c671ebd5"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '75a875ae-ecd2-5869-8352-fc81327d9341'::uuid, 'Neha Deshmukh', 'cust-445', 'customer-000445@aplibhaji.com', '#161, Block 5, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000445',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'f43f4b50-2237-528b-81a2-6d34c671ebd5'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'aa66c120-6292-56b0-98ad-def7a36de931'::uuid, 'authenticated', 'authenticated',
  'customer-000446@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Patel", "phone": "9863149740", "address": "#349, Block 7, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "be7f15e9-5e1d-5d85-a10e-d7e52ab430c0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'aa66c120-6292-56b0-98ad-def7a36de931'::uuid, 'Ananya Patel', 'cust-446', 'customer-000446@aplibhaji.com', '#349, Block 7, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000446',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'be7f15e9-5e1d-5d85-a10e-d7e52ab430c0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '395a5e20-cedd-507f-84bb-c4b025432238'::uuid, 'authenticated', 'authenticated',
  'customer-000447@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Jain", "phone": "9881902064", "address": "#228, Block 7, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "be7f15e9-5e1d-5d85-a10e-d7e52ab430c0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '395a5e20-cedd-507f-84bb-c4b025432238'::uuid, 'Vikram Jain', 'cust-447', 'customer-000447@aplibhaji.com', '#228, Block 7, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000447',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'be7f15e9-5e1d-5d85-a10e-d7e52ab430c0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '303d16e2-fa2e-58fc-b4dc-400b0859dd27'::uuid, 'authenticated', 'authenticated',
  'customer-000448@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Nair", "phone": "9897502219", "address": "#151, Block 7, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "be7f15e9-5e1d-5d85-a10e-d7e52ab430c0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '303d16e2-fa2e-58fc-b4dc-400b0859dd27'::uuid, 'Geeta Nair', 'cust-448', 'customer-000448@aplibhaji.com', '#151, Block 7, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000448',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'be7f15e9-5e1d-5d85-a10e-d7e52ab430c0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5d3fdba6-90a8-5ab3-b6bb-8fea788cbb9d'::uuid, 'authenticated', 'authenticated',
  'customer-000449@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Kulkarni", "phone": "9838361613", "address": "#253, Block 8, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "83d465fd-b961-5e9c-be5a-6cc8bd2dfe96"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5d3fdba6-90a8-5ab3-b6bb-8fea788cbb9d'::uuid, 'Vikram Kulkarni', 'cust-449', 'customer-000449@aplibhaji.com', '#253, Block 8, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000449',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, '83d465fd-b961-5e9c-be5a-6cc8bd2dfe96'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9788000b-0e3a-5893-8c21-cba7ebbf4abf'::uuid, 'authenticated', 'authenticated',
  'customer-000450@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Rao", "phone": "9834739420", "address": "#140, Block 7, Green Lane 9, Royal Palms Estate", "area_id": "11d2b992-62b2-55c8-b3ca-8b4a0efd31de", "road_id": "a4eacdae-6e84-543f-98e4-e2d7c0d446ad", "sub_road_id": "be7f15e9-5e1d-5d85-a10e-d7e52ab430c0"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9788000b-0e3a-5893-8c21-cba7ebbf4abf'::uuid, 'Rohan Rao', 'cust-450', 'customer-000450@aplibhaji.com', '#140, Block 7, Green Lane 9, Royal Palms Estate', 'CUSTOMER-000450',
  '11d2b992-62b2-55c8-b3ca-8b4a0efd31de'::uuid, 'a4eacdae-6e84-543f-98e4-e2d7c0d446ad'::uuid, 'be7f15e9-5e1d-5d85-a10e-d7e52ab430c0'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c3bf1e01-1dfe-56c6-b421-5aa3a5a8ebd5'::uuid, 'authenticated', 'authenticated',
  'customer-000451@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Suresh Mehta", "phone": "9893527857", "address": "#214, Block 7, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "9e61ed5a-b893-5bfe-b6c8-aebb11e0ea5e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c3bf1e01-1dfe-56c6-b421-5aa3a5a8ebd5'::uuid, 'Suresh Mehta', 'cust-451', 'customer-000451@aplibhaji.com', '#214, Block 7, Market Road 10, Valley View Towers', 'CUSTOMER-000451',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '9e61ed5a-b893-5bfe-b6c8-aebb11e0ea5e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'da746792-6735-5b64-bfac-f64c2f00af97'::uuid, 'authenticated', 'authenticated',
  'customer-000452@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Rao", "phone": "9835736355", "address": "#295, Block 4, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "0b10bf49-6867-5ab8-8124-8a8706e31f37"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'da746792-6735-5b64-bfac-f64c2f00af97'::uuid, 'Deepak Rao', 'cust-452', 'customer-000452@aplibhaji.com', '#295, Block 4, Market Road 10, Valley View Towers', 'CUSTOMER-000452',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '0b10bf49-6867-5ab8-8124-8a8706e31f37'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '98a505f0-a451-5c69-8fb6-bfe8d0abcb4b'::uuid, 'authenticated', 'authenticated',
  'customer-000453@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Nair", "phone": "9874977865", "address": "#104, Block 4, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "0b10bf49-6867-5ab8-8124-8a8706e31f37"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '98a505f0-a451-5c69-8fb6-bfe8d0abcb4b'::uuid, 'Rohan Nair', 'cust-453', 'customer-000453@aplibhaji.com', '#104, Block 4, Market Road 10, Valley View Towers', 'CUSTOMER-000453',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '0b10bf49-6867-5ab8-8124-8a8706e31f37'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '10f9e20d-4b98-5a98-b0ab-67848a2f1345'::uuid, 'authenticated', 'authenticated',
  'customer-000454@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Gupta", "phone": "9856241661", "address": "#229, Block 1, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "03750ca1-20ac-5e9c-bb36-974ddab1f608"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '10f9e20d-4b98-5a98-b0ab-67848a2f1345'::uuid, 'Swati Gupta', 'cust-454', 'customer-000454@aplibhaji.com', '#229, Block 1, Market Road 10, Valley View Towers', 'CUSTOMER-000454',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '03750ca1-20ac-5e9c-bb36-974ddab1f608'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4cb1f8ee-aac4-56ee-a2a3-a44902fff16b'::uuid, 'authenticated', 'authenticated',
  'customer-000455@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Kumar", "phone": "9890829554", "address": "#149, Block 3, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "3171804c-9c66-5583-8fed-fe5af9592c18"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4cb1f8ee-aac4-56ee-a2a3-a44902fff16b'::uuid, 'Sunita Kumar', 'cust-455', 'customer-000455@aplibhaji.com', '#149, Block 3, Market Road 10, Valley View Towers', 'CUSTOMER-000455',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '3171804c-9c66-5583-8fed-fe5af9592c18'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5e78af59-328d-55c6-9eec-aad6dc5c9b19'::uuid, 'authenticated', 'authenticated',
  'customer-000456@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Nair", "phone": "9871405945", "address": "#388, Block 1, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "03750ca1-20ac-5e9c-bb36-974ddab1f608"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5e78af59-328d-55c6-9eec-aad6dc5c9b19'::uuid, 'Sanjay Nair', 'cust-456', 'customer-000456@aplibhaji.com', '#388, Block 1, Market Road 10, Valley View Towers', 'CUSTOMER-000456',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '03750ca1-20ac-5e9c-bb36-974ddab1f608'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd10bef94-9eac-5adb-ae59-5faf79c49e15'::uuid, 'authenticated', 'authenticated',
  'customer-000457@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Reddy", "phone": "9819481948", "address": "#227, Block 1, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "03750ca1-20ac-5e9c-bb36-974ddab1f608"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd10bef94-9eac-5adb-ae59-5faf79c49e15'::uuid, 'Ajay Reddy', 'cust-457', 'customer-000457@aplibhaji.com', '#227, Block 1, Market Road 10, Valley View Towers', 'CUSTOMER-000457',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '03750ca1-20ac-5e9c-bb36-974ddab1f608'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ec2436b6-b3a8-587d-bc25-4aa052516dc9'::uuid, 'authenticated', 'authenticated',
  'customer-000458@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Pooja Kulkarni", "phone": "9852556647", "address": "#244, Block 4, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "0b10bf49-6867-5ab8-8124-8a8706e31f37"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ec2436b6-b3a8-587d-bc25-4aa052516dc9'::uuid, 'Pooja Kulkarni', 'cust-458', 'customer-000458@aplibhaji.com', '#244, Block 4, Market Road 10, Valley View Towers', 'CUSTOMER-000458',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '0b10bf49-6867-5ab8-8124-8a8706e31f37'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'bd4ee175-41f3-5fc9-be00-f0c7f41c9fa1'::uuid, 'authenticated', 'authenticated',
  'customer-000459@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rajesh Gupta", "phone": "9828993033", "address": "#215, Block 3, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "3171804c-9c66-5583-8fed-fe5af9592c18"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'bd4ee175-41f3-5fc9-be00-f0c7f41c9fa1'::uuid, 'Rajesh Gupta', 'cust-459', 'customer-000459@aplibhaji.com', '#215, Block 3, Market Road 10, Valley View Towers', 'CUSTOMER-000459',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, '3171804c-9c66-5583-8fed-fe5af9592c18'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '80c3596e-ebdc-555d-931c-65a9cb49a5c6'::uuid, 'authenticated', 'authenticated',
  'customer-000460@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Amit Agarwal", "phone": "9836550542", "address": "#154, Block 8, Market Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "eb4047d1-138e-5841-b19c-00a670e1935e", "sub_road_id": "fc60eb08-c2c5-54a7-9778-9cb811a91b6f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '80c3596e-ebdc-555d-931c-65a9cb49a5c6'::uuid, 'Amit Agarwal', 'cust-460', 'customer-000460@aplibhaji.com', '#154, Block 8, Market Road 10, Valley View Towers', 'CUSTOMER-000460',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'eb4047d1-138e-5841-b19c-00a670e1935e'::uuid, 'fc60eb08-c2c5-54a7-9778-9cb811a91b6f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a763d7e6-7fdf-510f-b013-c30b98c9d702'::uuid, 'authenticated', 'authenticated',
  'customer-000461@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Kavita Kulkarni", "phone": "9882760231", "address": "#232, Block 5, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "e1f6720c-7abc-54b2-9d3c-242154ba1f70"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a763d7e6-7fdf-510f-b013-c30b98c9d702'::uuid, 'Kavita Kulkarni', 'cust-461', 'customer-000461@aplibhaji.com', '#232, Block 5, MG Road 10, Valley View Towers', 'CUSTOMER-000461',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'e1f6720c-7abc-54b2-9d3c-242154ba1f70'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9370da4a-93f8-525b-a299-9914229f0596'::uuid, 'authenticated', 'authenticated',
  'customer-000462@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Nair", "phone": "9878115461", "address": "#387, Block 7, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "40285b98-b4d3-5c32-b26c-1ba3e2ef55f7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9370da4a-93f8-525b-a299-9914229f0596'::uuid, 'Rohan Nair', 'cust-462', 'customer-000462@aplibhaji.com', '#387, Block 7, MG Road 10, Valley View Towers', 'CUSTOMER-000462',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '40285b98-b4d3-5c32-b26c-1ba3e2ef55f7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '873d766e-db36-55db-bbe1-ab7cc4fcbb40'::uuid, 'authenticated', 'authenticated',
  'customer-000463@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kumar", "phone": "9863797783", "address": "#185, Block 4, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "b87171f4-eef5-58c7-8a15-0ff770444d85"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '873d766e-db36-55db-bbe1-ab7cc4fcbb40'::uuid, 'Rohan Kumar', 'cust-463', 'customer-000463@aplibhaji.com', '#185, Block 4, MG Road 10, Valley View Towers', 'CUSTOMER-000463',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'b87171f4-eef5-58c7-8a15-0ff770444d85'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8e9a4b01-9257-599f-bcc7-92dbde75dfa9'::uuid, 'authenticated', 'authenticated',
  'customer-000464@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Verma", "phone": "9839904956", "address": "#103, Block 6, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "6d6396cb-a8a3-5f4c-950a-28bcae06710a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8e9a4b01-9257-599f-bcc7-92dbde75dfa9'::uuid, 'Manish Verma', 'cust-464', 'customer-000464@aplibhaji.com', '#103, Block 6, MG Road 10, Valley View Towers', 'CUSTOMER-000464',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '6d6396cb-a8a3-5f4c-950a-28bcae06710a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a6548165-ec6f-5abe-8d6e-05a8d22ca6bd'::uuid, 'authenticated', 'authenticated',
  'customer-000465@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Singh", "phone": "9817547080", "address": "#283, Block 7, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "40285b98-b4d3-5c32-b26c-1ba3e2ef55f7"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a6548165-ec6f-5abe-8d6e-05a8d22ca6bd'::uuid, 'Neha Singh', 'cust-465', 'customer-000465@aplibhaji.com', '#283, Block 7, MG Road 10, Valley View Towers', 'CUSTOMER-000465',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '40285b98-b4d3-5c32-b26c-1ba3e2ef55f7'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '7c13608f-d140-56b6-9717-c05a370dcdff'::uuid, 'authenticated', 'authenticated',
  'customer-000466@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Sharma", "phone": "9826631311", "address": "#357, Block 2, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "81701a3f-836e-5a07-a8ff-3dd33bafb195"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '7c13608f-d140-56b6-9717-c05a370dcdff'::uuid, 'Rahul Sharma', 'cust-466', 'customer-000466@aplibhaji.com', '#357, Block 2, MG Road 10, Valley View Towers', 'CUSTOMER-000466',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '81701a3f-836e-5a07-a8ff-3dd33bafb195'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '97a77b53-6079-52e7-9665-fedebcc57e8c'::uuid, 'authenticated', 'authenticated',
  'customer-000467@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Singh", "phone": "9891085297", "address": "#142, Block 2, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "81701a3f-836e-5a07-a8ff-3dd33bafb195"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '97a77b53-6079-52e7-9665-fedebcc57e8c'::uuid, 'Geeta Singh', 'cust-467', 'customer-000467@aplibhaji.com', '#142, Block 2, MG Road 10, Valley View Towers', 'CUSTOMER-000467',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '81701a3f-836e-5a07-a8ff-3dd33bafb195'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5d3f5c5c-34ee-5cae-bae1-faf5c1ab693e'::uuid, 'authenticated', 'authenticated',
  'customer-000468@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Kulkarni", "phone": "9822788413", "address": "#149, Block 8, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "7e20fdae-c4ff-5355-b4a5-1aedbcd1a99f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5d3f5c5c-34ee-5cae-bae1-faf5c1ab693e'::uuid, 'Ananya Kulkarni', 'cust-468', 'customer-000468@aplibhaji.com', '#149, Block 8, MG Road 10, Valley View Towers', 'CUSTOMER-000468',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '7e20fdae-c4ff-5355-b4a5-1aedbcd1a99f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a693e42d-abec-5ff6-9cec-6ee4af30b66d'::uuid, 'authenticated', 'authenticated',
  'customer-000469@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Nair", "phone": "9846445949", "address": "#153, Block 6, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "6d6396cb-a8a3-5f4c-950a-28bcae06710a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a693e42d-abec-5ff6-9cec-6ee4af30b66d'::uuid, 'Geeta Nair', 'cust-469', 'customer-000469@aplibhaji.com', '#153, Block 6, MG Road 10, Valley View Towers', 'CUSTOMER-000469',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, '6d6396cb-a8a3-5f4c-950a-28bcae06710a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '5a2e4016-826c-58e5-917b-535a0b8b1eb2'::uuid, 'authenticated', 'authenticated',
  'customer-000470@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Rao", "phone": "9858650013", "address": "#386, Block 3, MG Road 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "4c626994-badf-596a-aeea-0023bca423d9", "sub_road_id": "f330fc21-298e-575d-a073-a1747175eaca"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '5a2e4016-826c-58e5-917b-535a0b8b1eb2'::uuid, 'Deepak Rao', 'cust-470', 'customer-000470@aplibhaji.com', '#386, Block 3, MG Road 10, Valley View Towers', 'CUSTOMER-000470',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, '4c626994-badf-596a-aeea-0023bca423d9'::uuid, 'f330fc21-298e-575d-a073-a1747175eaca'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cef21d3c-8382-5501-affc-0e82843e93f8'::uuid, 'authenticated', 'authenticated',
  'customer-000471@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Kumar", "phone": "9857193335", "address": "#362, Block 1, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "e7a47294-607a-5bae-820c-163c79d52831"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cef21d3c-8382-5501-affc-0e82843e93f8'::uuid, 'Rohan Kumar', 'cust-471', 'customer-000471@aplibhaji.com', '#362, Block 1, Station Street 10, Valley View Towers', 'CUSTOMER-000471',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'e7a47294-607a-5bae-820c-163c79d52831'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6cb4674a-7dfa-5f72-bd60-13641e6fa592'::uuid, 'authenticated', 'authenticated',
  'customer-000472@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ananya Deshmukh", "phone": "9811146394", "address": "#227, Block 7, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "9cb96b62-f2fa-52fd-b9ec-fa580300075e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6cb4674a-7dfa-5f72-bd60-13641e6fa592'::uuid, 'Ananya Deshmukh', 'cust-472', 'customer-000472@aplibhaji.com', '#227, Block 7, Station Street 10, Valley View Towers', 'CUSTOMER-000472',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, '9cb96b62-f2fa-52fd-b9ec-fa580300075e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '177ec94c-5bfe-5ac5-abf7-d12f18f407c4'::uuid, 'authenticated', 'authenticated',
  'customer-000473@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vikram Kumar", "phone": "9811192572", "address": "#155, Block 5, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "dda835d0-097b-575f-9d12-bf4aeeac5795"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '177ec94c-5bfe-5ac5-abf7-d12f18f407c4'::uuid, 'Vikram Kumar', 'cust-473', 'customer-000473@aplibhaji.com', '#155, Block 5, Station Street 10, Valley View Towers', 'CUSTOMER-000473',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'dda835d0-097b-575f-9d12-bf4aeeac5795'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '23aa5da4-d509-5be9-b4a3-74c10f384f01'::uuid, 'authenticated', 'authenticated',
  'customer-000474@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Gupta", "phone": "9822287201", "address": "#238, Block 1, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "e7a47294-607a-5bae-820c-163c79d52831"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '23aa5da4-d509-5be9-b4a3-74c10f384f01'::uuid, 'Ajay Gupta', 'cust-474', 'customer-000474@aplibhaji.com', '#238, Block 1, Station Street 10, Valley View Towers', 'CUSTOMER-000474',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'e7a47294-607a-5bae-820c-163c79d52831'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4e9c60ee-8de6-51fa-b66f-7db0fb42adac'::uuid, 'authenticated', 'authenticated',
  'customer-000475@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Joshi", "phone": "9898420820", "address": "#338, Block 1, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "e7a47294-607a-5bae-820c-163c79d52831"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4e9c60ee-8de6-51fa-b66f-7db0fb42adac'::uuid, 'Arun Joshi', 'cust-475', 'customer-000475@aplibhaji.com', '#338, Block 1, Station Street 10, Valley View Towers', 'CUSTOMER-000475',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'e7a47294-607a-5bae-820c-163c79d52831'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '4fc52831-bf7c-50e9-83a2-02aa7d6a1512'::uuid, 'authenticated', 'authenticated',
  'customer-000476@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Gupta", "phone": "9856673433", "address": "#148, Block 5, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "dda835d0-097b-575f-9d12-bf4aeeac5795"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '4fc52831-bf7c-50e9-83a2-02aa7d6a1512'::uuid, 'Rahul Gupta', 'cust-476', 'customer-000476@aplibhaji.com', '#148, Block 5, Station Street 10, Valley View Towers', 'CUSTOMER-000476',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'dda835d0-097b-575f-9d12-bf4aeeac5795'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0d3e0292-0adc-50d5-8ec3-5b104c6a4c9c'::uuid, 'authenticated', 'authenticated',
  'customer-000477@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Meena Reddy", "phone": "9838402206", "address": "#134, Block 3, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "23cffbca-c5d1-5748-a30c-aa4bc1349af8"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0d3e0292-0adc-50d5-8ec3-5b104c6a4c9c'::uuid, 'Meena Reddy', 'cust-477', 'customer-000477@aplibhaji.com', '#134, Block 3, Station Street 10, Valley View Towers', 'CUSTOMER-000477',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, '23cffbca-c5d1-5748-a30c-aa4bc1349af8'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e2e92117-f8c5-5969-a248-9617e32711cd'::uuid, 'authenticated', 'authenticated',
  'customer-000478@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Verma", "phone": "9870344767", "address": "#349, Block 1, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "e7a47294-607a-5bae-820c-163c79d52831"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e2e92117-f8c5-5969-a248-9617e32711cd'::uuid, 'Rahul Verma', 'cust-478', 'customer-000478@aplibhaji.com', '#349, Block 1, Station Street 10, Valley View Towers', 'CUSTOMER-000478',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'e7a47294-607a-5bae-820c-163c79d52831'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f6f21e12-f65d-545c-b267-6d38552b7d30'::uuid, 'authenticated', 'authenticated',
  'customer-000479@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Mehta", "phone": "9829909049", "address": "#377, Block 4, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "ca1253cc-f4f2-5272-a093-c050ca3b663f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f6f21e12-f65d-545c-b267-6d38552b7d30'::uuid, 'Sanjay Mehta', 'cust-479', 'customer-000479@aplibhaji.com', '#377, Block 4, Station Street 10, Valley View Towers', 'CUSTOMER-000479',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, 'ca1253cc-f4f2-5272-a093-c050ca3b663f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '2d21f274-64fe-5e5e-97bd-d760431da4de'::uuid, 'authenticated', 'authenticated',
  'customer-000480@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Kulkarni", "phone": "9817148634", "address": "#209, Block 7, Station Street 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "bec70ee5-2882-5cd5-bdf1-5ccb887dee89", "sub_road_id": "9cb96b62-f2fa-52fd-b9ec-fa580300075e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '2d21f274-64fe-5e5e-97bd-d760431da4de'::uuid, 'Sanjay Kulkarni', 'cust-480', 'customer-000480@aplibhaji.com', '#209, Block 7, Station Street 10, Valley View Towers', 'CUSTOMER-000480',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'bec70ee5-2882-5cd5-bdf1-5ccb887dee89'::uuid, '9cb96b62-f2fa-52fd-b9ec-fa580300075e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'a4400f02-69ad-5df4-abae-b94ca714a585'::uuid, 'authenticated', 'authenticated',
  'customer-000481@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sunita Deshmukh", "phone": "9810324428", "address": "#220, Block 4, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "e2c50f2d-4fb8-5d46-9641-c1a0c1b57700"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'a4400f02-69ad-5df4-abae-b94ca714a585'::uuid, 'Sunita Deshmukh', 'cust-481', 'customer-000481@aplibhaji.com', '#220, Block 4, Park Avenue 10, Valley View Towers', 'CUSTOMER-000481',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'e2c50f2d-4fb8-5d46-9641-c1a0c1b57700'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'f3f4b034-f969-5cb4-ab9c-295d6b240c10'::uuid, 'authenticated', 'authenticated',
  'customer-000482@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ramesh Chawla", "phone": "9834951931", "address": "#229, Block 3, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "5502a197-691b-56f7-8d69-804f9a6a30e9"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'f3f4b034-f969-5cb4-ab9c-295d6b240c10'::uuid, 'Ramesh Chawla', 'cust-482', 'customer-000482@aplibhaji.com', '#229, Block 3, Park Avenue 10, Valley View Towers', 'CUSTOMER-000482',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '5502a197-691b-56f7-8d69-804f9a6a30e9'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '0eea8c8b-aa43-555b-982f-ec85f6e3835b'::uuid, 'authenticated', 'authenticated',
  'customer-000483@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Deepak Kulkarni", "phone": "9897033965", "address": "#231, Block 2, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "6eb78452-ce88-57a6-a0c3-d3f32923a817"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '0eea8c8b-aa43-555b-982f-ec85f6e3835b'::uuid, 'Deepak Kulkarni', 'cust-483', 'customer-000483@aplibhaji.com', '#231, Block 2, Park Avenue 10, Valley View Towers', 'CUSTOMER-000483',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '6eb78452-ce88-57a6-a0c3-d3f32923a817'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '80e11ba5-d428-56ae-86e7-90d0fa9b3a67'::uuid, 'authenticated', 'authenticated',
  'customer-000484@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Vijay Patel", "phone": "9888229522", "address": "#377, Block 4, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "e2c50f2d-4fb8-5d46-9641-c1a0c1b57700"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '80e11ba5-d428-56ae-86e7-90d0fa9b3a67'::uuid, 'Vijay Patel', 'cust-484', 'customer-000484@aplibhaji.com', '#377, Block 4, Park Avenue 10, Valley View Towers', 'CUSTOMER-000484',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'e2c50f2d-4fb8-5d46-9641-c1a0c1b57700'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '78bf9100-fdb6-5094-9ef2-81eb2b3bd3e3'::uuid, 'authenticated', 'authenticated',
  'customer-000485@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Swati Reddy", "phone": "9846288104", "address": "#395, Block 1, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "cc0350d0-191a-57d5-88e7-4985eadd2acc"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '78bf9100-fdb6-5094-9ef2-81eb2b3bd3e3'::uuid, 'Swati Reddy', 'cust-485', 'customer-000485@aplibhaji.com', '#395, Block 1, Park Avenue 10, Valley View Towers', 'CUSTOMER-000485',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, 'cc0350d0-191a-57d5-88e7-4985eadd2acc'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'ae3c50c5-e890-5bf7-a709-3233f006c191'::uuid, 'authenticated', 'authenticated',
  'customer-000486@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Rao", "phone": "9869051165", "address": "#179, Block 8, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "15c7e698-86d7-5670-9399-000432987b4d"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'ae3c50c5-e890-5bf7-a709-3233f006c191'::uuid, 'Arun Rao', 'cust-486', 'customer-000486@aplibhaji.com', '#179, Block 8, Park Avenue 10, Valley View Towers', 'CUSTOMER-000486',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '15c7e698-86d7-5670-9399-000432987b4d'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '9fdc63ec-1b19-51f0-92f4-28d333ba0ce6'::uuid, 'authenticated', 'authenticated',
  'customer-000487@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Jain", "phone": "9831406407", "address": "#369, Block 7, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "04322682-343c-57ef-b738-6a434245b392"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '9fdc63ec-1b19-51f0-92f4-28d333ba0ce6'::uuid, 'Manish Jain', 'cust-487', 'customer-000487@aplibhaji.com', '#369, Block 7, Park Avenue 10, Valley View Towers', 'CUSTOMER-000487',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '04322682-343c-57ef-b738-6a434245b392'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cb8cdc7b-557c-5083-8d1e-0faa79d00fbb'::uuid, 'authenticated', 'authenticated',
  'customer-000488@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Sharma", "phone": "9861742999", "address": "#331, Block 5, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "1069b58f-6e4d-5b81-ad0d-9c0ae5b92e5a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cb8cdc7b-557c-5083-8d1e-0faa79d00fbb'::uuid, 'Sanjay Sharma', 'cust-488', 'customer-000488@aplibhaji.com', '#331, Block 5, Park Avenue 10, Valley View Towers', 'CUSTOMER-000488',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '1069b58f-6e4d-5b81-ad0d-9c0ae5b92e5a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '611e8434-ee41-5558-ab4b-2e901b0f7079'::uuid, 'authenticated', 'authenticated',
  'customer-000489@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Manish Jain", "phone": "9817060387", "address": "#133, Block 6, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "741cd65e-3309-58e2-86fe-c0a2b16ab43e"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '611e8434-ee41-5558-ab4b-2e901b0f7079'::uuid, 'Manish Jain', 'cust-489', 'customer-000489@aplibhaji.com', '#133, Block 6, Park Avenue 10, Valley View Towers', 'CUSTOMER-000489',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '741cd65e-3309-58e2-86fe-c0a2b16ab43e'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'e8ef981d-da72-5441-ac0c-20b6ad416085'::uuid, 'authenticated', 'authenticated',
  'customer-000490@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rahul Nair", "phone": "9825505370", "address": "#348, Block 5, Park Avenue 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "db5a20d7-4752-592d-ae6c-7b93aaaba07c", "sub_road_id": "1069b58f-6e4d-5b81-ad0d-9c0ae5b92e5a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'e8ef981d-da72-5441-ac0c-20b6ad416085'::uuid, 'Rahul Nair', 'cust-490', 'customer-000490@aplibhaji.com', '#348, Block 5, Park Avenue 10, Valley View Towers', 'CUSTOMER-000490',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'db5a20d7-4752-592d-ae6c-7b93aaaba07c'::uuid, '1069b58f-6e4d-5b81-ad0d-9c0ae5b92e5a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '74cb0018-901a-5b98-959d-4e6917f09aaf'::uuid, 'authenticated', 'authenticated',
  'customer-000491@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Verma", "phone": "9836867922", "address": "#252, Block 4, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "911546fc-0ee4-583d-9bc6-79b74384be7f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '74cb0018-901a-5b98-959d-4e6917f09aaf'::uuid, 'Arun Verma', 'cust-491', 'customer-000491@aplibhaji.com', '#252, Block 4, Green Lane 10, Valley View Towers', 'CUSTOMER-000491',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '911546fc-0ee4-583d-9bc6-79b74384be7f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'cd86955b-4fb7-5aac-b2d0-fd3abf0f0501'::uuid, 'authenticated', 'authenticated',
  'customer-000492@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Kumar", "phone": "9868688502", "address": "#347, Block 4, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "911546fc-0ee4-583d-9bc6-79b74384be7f"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'cd86955b-4fb7-5aac-b2d0-fd3abf0f0501'::uuid, 'Ajay Kumar', 'cust-492', 'customer-000492@aplibhaji.com', '#347, Block 4, Green Lane 10, Valley View Towers', 'CUSTOMER-000492',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '911546fc-0ee4-583d-9bc6-79b74384be7f'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '6ae81d8d-ddcc-58fc-954d-78ea555bcc72'::uuid, 'authenticated', 'authenticated',
  'customer-000493@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Reddy", "phone": "9879321099", "address": "#384, Block 1, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "50c35e47-9045-5701-acbc-28f6e2099e75"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '6ae81d8d-ddcc-58fc-954d-78ea555bcc72'::uuid, 'Ajay Reddy', 'cust-493', 'customer-000493@aplibhaji.com', '#384, Block 1, Green Lane 10, Valley View Towers', 'CUSTOMER-000493',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '50c35e47-9045-5701-acbc-28f6e2099e75'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'c7b74358-f964-5718-ba09-3886f3989bc8'::uuid, 'authenticated', 'authenticated',
  'customer-000494@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Geeta Kumar", "phone": "9881119455", "address": "#189, Block 2, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "6d26ba4c-096d-5b2b-b54d-0dc5776be700"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'c7b74358-f964-5718-ba09-3886f3989bc8'::uuid, 'Geeta Kumar', 'cust-494', 'customer-000494@aplibhaji.com', '#189, Block 2, Green Lane 10, Valley View Towers', 'CUSTOMER-000494',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '6d26ba4c-096d-5b2b-b54d-0dc5776be700'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '22c7e2de-8239-5a72-92d1-d7abce0f35ab'::uuid, 'authenticated', 'authenticated',
  'customer-000495@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Rohan Joshi", "phone": "9848194334", "address": "#355, Block 1, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "50c35e47-9045-5701-acbc-28f6e2099e75"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '22c7e2de-8239-5a72-92d1-d7abce0f35ab'::uuid, 'Rohan Joshi', 'cust-495', 'customer-000495@aplibhaji.com', '#355, Block 1, Green Lane 10, Valley View Towers', 'CUSTOMER-000495',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '50c35e47-9045-5701-acbc-28f6e2099e75'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'fc347591-adc8-5b2e-8aa5-443d7043802b'::uuid, 'authenticated', 'authenticated',
  'customer-000496@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Neha Joshi", "phone": "9811396947", "address": "#386, Block 3, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "f7c04f62-1e4e-5655-9823-466ce9c99136"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'fc347591-adc8-5b2e-8aa5-443d7043802b'::uuid, 'Neha Joshi', 'cust-496', 'customer-000496@aplibhaji.com', '#386, Block 3, Green Lane 10, Valley View Towers', 'CUSTOMER-000496',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'f7c04f62-1e4e-5655-9823-466ce9c99136'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', 'd41d317c-83ef-5ce8-b4f7-7b37647bf806'::uuid, 'authenticated', 'authenticated',
  'customer-000497@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Sanjay Sharma", "phone": "9889783922", "address": "#382, Block 3, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "f7c04f62-1e4e-5655-9823-466ce9c99136"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  'd41d317c-83ef-5ce8-b4f7-7b37647bf806'::uuid, 'Sanjay Sharma', 'cust-497', 'customer-000497@aplibhaji.com', '#382, Block 3, Green Lane 10, Valley View Towers', 'CUSTOMER-000497',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, 'f7c04f62-1e4e-5655-9823-466ce9c99136'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '58a3e8bf-eb38-5dbd-94f6-50010732a31b'::uuid, 'authenticated', 'authenticated',
  'customer-000498@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Anita Chawla", "phone": "9840143785", "address": "#133, Block 1, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "50c35e47-9045-5701-acbc-28f6e2099e75"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '58a3e8bf-eb38-5dbd-94f6-50010732a31b'::uuid, 'Anita Chawla', 'cust-498', 'customer-000498@aplibhaji.com', '#133, Block 1, Green Lane 10, Valley View Towers', 'CUSTOMER-000498',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '50c35e47-9045-5701-acbc-28f6e2099e75'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '8f25c288-281c-50f5-aac8-e8743a240692'::uuid, 'authenticated', 'authenticated',
  'customer-000499@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Arun Agarwal", "phone": "9881281297", "address": "#150, Block 7, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "62ab0aa8-28cd-5410-88d2-db78ae975c19"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '8f25c288-281c-50f5-aac8-e8743a240692'::uuid, 'Arun Agarwal', 'cust-499', 'customer-000499@aplibhaji.com', '#150, Block 7, Green Lane 10, Valley View Towers', 'CUSTOMER-000499',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '62ab0aa8-28cd-5410-88d2-db78ae975c19'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;
INSERT INTO auth.users (
  instance_id, id, aud, role, email, encrypted_password,
  email_confirmed_at, raw_app_meta_data, raw_user_meta_data,
  created_at, updated_at, confirmation_token, recovery_token,
  email_change_token_new, email_change
) VALUES (
  '00000000-0000-0000-0000-000000000000', '12f91c3a-45e4-5c1e-bd0a-f9dc35a5180f'::uuid, 'authenticated', 'authenticated',
  'customer-000500@aplibhaji.com', extensions.crypt('aplibhaji123', extensions.gen_salt('bf')),
  now(), '{"provider": "email", "providers": ["email"]}'::jsonb,
  '{"name": "Ajay Reddy", "phone": "9877608398", "address": "#357, Block 6, Green Lane 10, Valley View Towers", "area_id": "f52e2369-5c87-515d-a95c-3999b53cb2cb", "road_id": "c3b6c980-7670-5bfb-866a-aa3aaf831a9a", "sub_road_id": "2031493b-05fb-51fc-9e7f-5cd4e8f02e3a"}'::jsonb,
  now(), now(), '', '', '', ''
) ON CONFLICT (id) DO NOTHING;
INSERT INTO public.customers (
  id, name, phone, email, address, customer_code, area_id, road_id, sub_road_id
) VALUES (
  '12f91c3a-45e4-5c1e-bd0a-f9dc35a5180f'::uuid, 'Ajay Reddy', 'cust-500', 'customer-000500@aplibhaji.com', '#357, Block 6, Green Lane 10, Valley View Towers', 'CUSTOMER-000500',
  'f52e2369-5c87-515d-a95c-3999b53cb2cb'::uuid, 'c3b6c980-7670-5bfb-866a-aa3aaf831a9a'::uuid, '2031493b-05fb-51fc-9e7f-5cd4e8f02e3a'::uuid
) ON CONFLICT (id) DO UPDATE SET
  area_id = excluded.area_id, road_id = excluded.road_id, sub_road_id = excluded.sub_road_id;

-- 8. Create schedule calculation helper functions
CREATE OR REPLACE FUNCTION public.get_effective_schedule(
  p_area_id uuid,
  p_road_id uuid,
  p_sub_road_id uuid
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_schedule jsonb;
BEGIN
  -- 1. Check Sub-Road override
  IF p_sub_road_id IS NOT NULL THEN
    SELECT delivery_schedule INTO v_schedule FROM public.sub_roads WHERE id = p_sub_road_id;
    IF v_schedule IS NOT NULL THEN
      RETURN v_schedule;
    END IF;
  END IF;

  -- 2. Check Road override
  IF p_road_id IS NOT NULL THEN
    SELECT delivery_schedule INTO v_schedule FROM public.roads WHERE id = p_road_id;
    IF v_schedule IS NOT NULL THEN
      RETURN v_schedule;
    END IF;
  END IF;

  -- 3. Get Area schedule
  IF p_area_id IS NOT NULL THEN
    SELECT delivery_schedule INTO v_schedule FROM public.areas WHERE id = p_area_id;
    IF v_schedule IS NOT NULL THEN
      RETURN v_schedule;
    END IF;
  END IF;

  RETURN '[]'::jsonb;
END;
$$;

-- 9. Create delivery info lookup function
CREATE OR REPLACE FUNCTION public.get_delivery_info(
  p_customer_id uuid,
  p_requested_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
AS $$
DECLARE
  v_area_id uuid;
  v_road_id uuid;
  v_sub_road_id uuid;
  v_schedule jsonb;
  v_schedule_arr text[];
  v_today date;
  v_current_day_name text;
  v_check_date date;
  v_check_day_name text;
  v_next_date date := NULL;
  v_is_today_allowed boolean := false;
  v_is_requested_valid boolean := false;
  v_assigned_date date;
  v_is_pre_order boolean := false;
  i int;
BEGIN
  -- Get customer route
  SELECT area_id, road_id, sub_road_id 
  INTO v_area_id, v_road_id, v_sub_road_id 
  FROM public.customers 
  WHERE id = p_customer_id;

  -- Get effective schedule
  v_schedule := public.get_effective_schedule(v_area_id, v_road_id, v_sub_road_id);
  
  -- Convert jsonb array to text array
  SELECT array_agg(val)::text[] INTO v_schedule_arr
  FROM jsonb_array_elements_text(v_schedule) AS val;

  -- Get local today date in India (IST)
  v_today := (now() AT TIME ZONE 'Asia/Kolkata')::date;
  v_current_day_name := trim(to_char(v_today, 'Day'));

  -- Check if today is allowed
  IF v_schedule_arr IS NOT NULL AND v_current_day_name = ANY(v_schedule_arr) THEN
    v_is_today_allowed := true;
  END IF;

  -- Find next delivery date starting from today
  FOR i IN 0..7 LOOP
    v_check_date := v_today + i;
    v_check_day_name := trim(to_char(v_check_date, 'Day'));
    IF v_schedule_arr IS NOT NULL AND v_check_day_name = ANY(v_schedule_arr) THEN
      v_next_date := v_check_date;
      EXIT;
    END IF;
  END LOOP;

  -- If schedule is empty, default next_date to tomorrow
  IF v_next_date IS NULL THEN
    v_next_date := v_today + 1;
  END IF;

  -- Validate requested date if provided
  IF p_requested_date IS NOT NULL THEN
    v_check_day_name := trim(to_char(p_requested_date, 'Day'));
    IF v_schedule_arr IS NOT NULL AND v_check_day_name = ANY(v_schedule_arr) AND p_requested_date >= v_today THEN
      v_is_requested_valid := true;
    END IF;
  ELSE
    v_is_requested_valid := true;
  END IF;

  -- Assigned delivery date logic:
  IF v_is_today_allowed THEN
    v_assigned_date := v_today;
    v_is_pre_order := false;
  ELSE
    v_assigned_date := v_next_date;
    v_is_pre_order := true;
  END IF;

  -- If a valid requested date was passed, we can assign it
  IF p_requested_date IS NOT NULL AND v_is_requested_valid THEN
    v_assigned_date := p_requested_date;
    IF v_assigned_date > v_today THEN
      v_is_pre_order := true;
    ELSE
      v_is_pre_order := false;
    END IF;
  END IF;

  RETURN jsonb_build_object(
    'is_today_allowed', v_is_today_allowed,
    'next_delivery_date', to_char(v_next_date, 'YYYY-MM-DD'),
    'assigned_delivery_date', to_char(v_assigned_date, 'YYYY-MM-DD'),
    'is_pre_order', v_is_pre_order,
    'is_requested_date_valid', v_is_requested_valid,
    'schedule', v_schedule
  );
END;
$$;

-- 10. Update handle_new_user trigger function to include routes
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
  ON CONFLICT (id) DO NOTHING;
  RETURN new;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER
SET search_path = public, pg_temp;

-- 11. Update sync_customer_with_code to include routes
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

  v_random_password := encode(gen_random_bytes(32), 'hex');

  select id into v_user_id from auth.users where id = p_id;

  if v_user_id is null then
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
      encrypted_password = extensions.crypt(v_random_password, extensions.gen_salt('bf')),
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

-- 12. Update update_customer_profile to include routes
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
  v_user_id uuid;
  v_current_email text;
  v_current_code text;
  v_new_email text;
BEGIN
  v_user_id := auth.uid();
  IF v_user_id IS NULL THEN
    RAISE EXCEPTION 'Unauthorized: User must be logged in.';
  END IF;

  IF p_name IS NULL OR trim(p_name) = '' THEN
    RAISE EXCEPTION 'Name is required.';
  END IF;
  IF p_phone IS NULL OR trim(p_phone) = '' THEN
    RAISE EXCEPTION 'Phone number is required.';
  END IF;

  IF EXISTS (SELECT 1 FROM public.customers WHERE phone = p_phone AND id != v_user_id) THEN
    RAISE EXCEPTION 'This phone number is already registered to another customer.';
  END IF;

  SELECT email INTO v_current_email FROM auth.users WHERE id = v_user_id;
  SELECT customer_code INTO v_current_code FROM public.customers WHERE id = v_user_id;

  IF v_current_code IS NOT NULL AND v_current_email = lower(v_current_code) || '@aplibhaji.com' THEN
    v_new_email := v_current_email;
  ELSE
    v_new_email := p_phone || '@aplibhaji.com';
  END IF;

  UPDATE auth.users SET
    email = v_new_email,
    raw_user_meta_data = jsonb_build_object(
      'name', p_name, 
      'phone', p_phone, 
      'address', p_address,
      'area_id', p_area_id,
      'road_id', p_road_id,
      'sub_road_id', p_sub_road_id
    ),
    updated_at = now()
  WHERE id = v_user_id;

  UPDATE public.customers SET
    name = p_name, phone = p_phone, address = p_address, email = v_new_email,
    area_id = p_area_id, road_id = p_road_id, sub_road_id = p_sub_road_id
  WHERE id = v_user_id;
END;
$$;

-- 13. Re-write place_order_secure with routing snapshot, next delivery date validation, and OK- canonical order numbering
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
  v_customer_name text;
  v_area_id uuid;
  v_road_id uuid;
  v_sub_road_id uuid;
  v_area_name text;
  v_road_name text;
  v_sub_road_name text;
  v_delivery_info jsonb;
  v_delivery_date date;
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
BEGIN
  -- 1. Authentication Check
  v_customer_id := auth.uid();
  if v_customer_id is null then
    raise exception 'Unauthorized: User must be logged in to place an order.';
  end if;

  -- 2. Verify that the customer profile exists and fetch route mapping
  SELECT name, area_id, road_id, sub_road_id
  INTO v_customer_name, v_area_id, v_road_id, v_sub_road_id
  FROM public.customers
  WHERE id = v_customer_id;

  if v_customer_name is null then
    raise exception 'Customer profile not found.';
  end if;

  if v_area_id is null then
    raise exception 'Delivery Area is not set. Please update your profile with a valid delivery area.';
  end if;

  -- Fetch route names for historical snapshot
  SELECT name INTO v_area_name FROM public.areas WHERE id = v_area_id;
  SELECT name INTO v_road_name FROM public.roads WHERE id = v_road_id;
  SELECT name INTO v_sub_road_name FROM public.sub_roads WHERE id = v_sub_road_id;

  -- 3. Calculate and Validate Delivery Date
  v_delivery_info := public.get_delivery_info(v_customer_id, p_delivery_date);
  
  if p_delivery_date is not null and not (v_delivery_info->>'is_requested_date_valid')::boolean then
    raise exception 'Invalid delivery date according to the route schedule.';
  end if;

  v_delivery_date := (v_delivery_info->>'assigned_delivery_date')::date;

  -- Idempotency Check: Return existing order if key matches
  if p_idempotency_key is not null then
    select id, order_number, customer_id, customer_phone, delivery_address, order_date, status, total_amount, delivery_date
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
        'total_amount', v_order_row.total_amount,
        'delivery_date', to_char(v_order_row.delivery_date, 'YYYY-MM-DD')
      );
    end if;
  end if;

  -- 4. Input Validation
  if p_delivery_address is null or trim(p_delivery_address) = '' then
    raise exception 'Delivery address is required.';
  end if;

  if jsonb_array_length(p_items) = 0 then
    raise exception 'Order must contain at least one item.';
  end if;

  -- 5. Generate Order ID and canonical Order Number
  v_order_id := gen_random_uuid();
  v_order_no := 'OK-' || to_char(now() AT TIME ZONE 'Asia/Kolkata', 'YYYYMMDD') || '-' || lpad(nextval('public.order_number_seq')::text, 4, '0');

  -- 6. Create Order with snapshot route info and delivery date
  insert into public.orders (
    id, order_number, customer_id, customer_phone, delivery_address, total_amount, idempotency_key,
    delivery_date, area_id, area_name, road_id, road_name, sub_road_id, sub_road_name, customer_name, offline_order_no
  ) values (
    v_order_id, v_order_no, v_customer_id, p_customer_phone, p_delivery_address, 0.00, p_idempotency_key,
    v_delivery_date, v_area_id, v_area_name, v_road_id, v_road_name, v_sub_road_id, v_sub_road_name, v_customer_name, p_offline_order_no
  );

  -- 7. Process Items
  for v_item in select * from jsonb_array_elements(p_items) loop
    v_product_id := (v_item->>'product_id')::uuid;
    v_quantity := (v_item->>'quantity')::numeric;

    if v_quantity <= 0 then
      raise exception 'Quantity must be positive.';
    end if;

    -- Fetch product details
    select name, price, unit, is_available, is_enabled, description
    into v_product_name, v_price, v_unit, v_is_available, v_is_enabled, v_description
    from public.products
    where id = v_product_id
    for update;

    if not found or not v_is_enabled or not v_is_available then
      raise exception 'Product is unavailable.';
    end if;

    -- Parse stock safely
    v_stock := null;
    if v_description is not null and v_description ~ '^\s*\{.*\}\s*$' then
      begin
        v_stock := (v_description::jsonb->>'stock')::numeric;
      exception when others then
        v_stock := null;
      end;
    end if;

    -- Enforce stock constraints
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
    'total_amount', v_order_row.total_amount,
    'delivery_date', to_char(v_order_row.delivery_date, 'YYYY-MM-DD')
  );
END;
$$;
