-- ==============================================================================
-- FCM Push Notification Automation Migration for Supabase
-- Target: aplibhaji_customer, aplibhaji_admin, orderkart
-- ==============================================================================

-- 1. Ensure fcm_token column exists in customers table with an index
DO $$ 
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_schema = 'public' AND table_name = 'customers' AND column_name = 'fcm_token'
  ) THEN
    ALTER TABLE public.customers ADD COLUMN fcm_token TEXT;
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_customers_fcm_token ON public.customers(fcm_token) WHERE fcm_token IS NOT NULL;

-- 2. Ensure fcm_token column exists in admin_users/workers if applicable
DO $$ 
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'workers') THEN
    IF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_schema = 'public' AND table_name = 'workers' AND column_name = 'fcm_token') THEN
      ALTER TABLE public.workers ADD COLUMN fcm_token TEXT;
    END IF;
  END IF;
END $$;

-- 3. Trigger Function: Send Push on Notification Insert
-- 2.1 Secure Secret Retrieval Function
CREATE SCHEMA IF NOT EXISTS private;
CREATE TABLE IF NOT EXISTS private.app_config (
  key TEXT PRIMARY KEY,
  value TEXT NOT NULL,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

-- Revoke all public access to private.app_config
REVOKE ALL ON SCHEMA private FROM anon, authenticated, public;
REVOKE ALL ON TABLE private.app_config FROM anon, authenticated, public;

CREATE OR REPLACE FUNCTION public.get_push_webhook_secret()
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_secret text;
BEGIN
  -- 1. Try Supabase Vault if installed
  BEGIN
    SELECT decrypted_secret INTO v_secret
    FROM vault.decrypted_secrets
    WHERE name = 'push_webhook_secret'
    LIMIT 1;
  EXCEPTION WHEN OTHERS THEN
    v_secret := NULL;
  END;

  -- 2. Fallback to GUC parameter if configured in postgresql.conf / session
  IF v_secret IS NULL OR length(trim(v_secret)) = 0 THEN
    v_secret := current_setting('app.settings.push_webhook_secret', true);
  END IF;

  -- 3. Fallback to private.app_config
  IF v_secret IS NULL OR length(trim(v_secret)) = 0 THEN
    BEGIN
      SELECT value INTO v_secret
      FROM private.app_config
      WHERE key = 'push_webhook_secret'
      LIMIT 1;
    EXCEPTION WHEN OTHERS THEN
      v_secret := NULL;
    END;
  END IF;

  RETURN v_secret;
END;
$$;

-- 3. Trigger Function: Send Push on Notification Insert
CREATE OR REPLACE FUNCTION public.handle_push_notification_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fcm_token TEXT;
  v_project_url TEXT := 'https://xsqaxvbrjvhgemlfgoxn.supabase.co';
  v_payload JSONB;
  v_webhook_secret TEXT;
BEGIN
  v_webhook_secret := public.get_push_webhook_secret();
  IF v_webhook_secret IS NULL OR length(trim(v_webhook_secret)) = 0 THEN
    -- If no webhook secret configured, exit gracefully without erroring client write
    RETURN NEW;
  END IF;

  -- If targeted to a specific customer, fetch their FCM token
  IF NEW.customer_id IS NOT NULL THEN
    SELECT fcm_token INTO v_fcm_token
    FROM public.customers
    WHERE id = NEW.customer_id;

    -- If no token found, check by auth_user_id
    IF v_fcm_token IS NULL THEN
      SELECT fcm_token INTO v_fcm_token
      FROM public.customers
      WHERE auth_user_id = NEW.customer_id;
    END IF;

    IF v_fcm_token IS NOT NULL AND length(trim(v_fcm_token)) > 0 THEN
      v_payload := jsonb_build_object(
        'token', v_fcm_token,
        'title', NEW.title,
        'body', NEW.body,
        'payload', COALESCE(NEW.id::text, ''),
        'channelId', 'aplibhaji_customer_channel'
      );
    ELSE
      -- Fallback to topic broadcast if no direct device token is found
      v_payload := jsonb_build_object(
        'topic', 'all_customers',
        'title', NEW.title,
        'body', NEW.body,
        'payload', COALESCE(NEW.id::text, ''),
        'channelId', 'aplibhaji_customer_channel'
      );
    END IF;
  ELSE
    -- Broadcast to all customers topic
    v_payload := jsonb_build_object(
      'topic', 'all_customers',
      'title', NEW.title,
      'body', NEW.body,
      'payload', COALESCE(NEW.id::text, ''),
      'channelId', 'aplibhaji_customer_channel'
    );
  END IF;

  -- Dispatch HTTP POST to Supabase send-push Edge Function using pg_net (if available)
  BEGIN
    PERFORM net.http_post(
      url := v_project_url || '/functions/v1/send-push',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'apikey', 'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
        'x-webhook-secret', v_webhook_secret,
        'Authorization', 'Bearer ' || v_webhook_secret
      ),
      body := v_payload
    );
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'pg_net push dispatch notice: %', SQLERRM;
  END;

  RETURN NEW;
END;
$$;

-- 4. Attach Trigger to public.notifications
DROP TRIGGER IF EXISTS trg_dispatch_push_notification ON public.notifications;
CREATE TRIGGER trg_dispatch_push_notification
  AFTER INSERT ON public.notifications
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_push_notification_dispatch();

-- 5. Trigger Function: Send Push on Order Status Updates
CREATE OR REPLACE FUNCTION public.handle_order_status_push_dispatch()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_fcm_token TEXT;
  v_customer_name TEXT;
  v_title TEXT;
  v_body TEXT;
  v_project_url TEXT := 'https://xsqaxvbrjvhgemlfgoxn.supabase.co';
  v_payload JSONB;
  v_webhook_secret TEXT;
BEGIN
  -- Only trigger when delivery status changes
  IF OLD.status IS DISTINCT FROM NEW.status THEN
    v_webhook_secret := public.get_push_webhook_secret();
    IF v_webhook_secret IS NULL OR length(trim(v_webhook_secret)) = 0 THEN
      RETURN NEW;
    END IF;

    SELECT fcm_token, name INTO v_fcm_token, v_customer_name
    FROM public.customers
    WHERE id = NEW.customer_id OR auth_user_id = NEW.customer_id;

    IF NEW.status = 'Confirmed' THEN
      v_title := 'Order Confirmed! 🛍️';
      v_body := 'Your order #' || COALESCE(NEW.order_number, SUBSTRING(NEW.id::text, 1, 8)) || ' has been confirmed and is being prepared.';
    ELSIF NEW.status = 'Out for Delivery' THEN
      v_title := 'Order Out for Delivery! 🚚';
      v_body := 'Your fresh farm delivery #' || COALESCE(NEW.order_number, SUBSTRING(NEW.id::text, 1, 8)) || ' is on its way to your address!';
    ELSIF NEW.status = 'Delivered' THEN
      v_title := 'Order Delivered! 🎉';
      v_body := 'Your order #' || COALESCE(NEW.order_number, SUBSTRING(NEW.id::text, 1, 8)) || ' has been delivered. Enjoy your fresh harvest!';
    ELSIF NEW.status = 'Cancelled' THEN
      v_title := 'Order Cancelled';
      v_body := 'Your order #' || COALESCE(NEW.order_number, SUBSTRING(NEW.id::text, 1, 8)) || ' was cancelled.';
    ELSE
      v_title := 'Order Update #' || COALESCE(NEW.order_number, SUBSTRING(NEW.id::text, 1, 8));
      v_body := 'Your order status is now: ' || NEW.status;
    END IF;

    IF v_fcm_token IS NOT NULL AND length(trim(v_fcm_token)) > 0 THEN
      v_payload := jsonb_build_object(
        'token', v_fcm_token,
        'title', v_title,
        'body', v_body,
        'payload', 'order_' || COALESCE(NEW.order_number, NEW.id::text),
        'channelId', 'aplibhaji_customer_channel'
      );

      BEGIN
        PERFORM net.http_post(
          url := v_project_url || '/functions/v1/send-push',
          headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'apikey', 'sb_publishable_7w2JdGBs0yI-P1pKfz7eOg_p2yV1qd_',
            'x-webhook-secret', v_webhook_secret,
            'Authorization', 'Bearer ' || v_webhook_secret
          ),
          body := v_payload
        );
      EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE 'pg_net order status push dispatch notice: %', SQLERRM;
      END;
    END IF;
  END IF;

  RETURN NEW;
END;
$$;

-- 6. Attach Trigger to public.orders
DROP TRIGGER IF EXISTS trg_dispatch_order_status_push ON public.orders;
CREATE TRIGGER trg_dispatch_order_status_push
  AFTER UPDATE OF status ON public.orders
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_order_status_push_dispatch();
