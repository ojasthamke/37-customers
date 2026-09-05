import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2.39.3";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
    const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

    if (!supabaseUrl || !serviceRoleKey) {
      throw new Error("Server configuration error: missing service credentials.");
    }

    const supabaseAdmin = createClient(supabaseUrl, serviceRoleKey);

    // 1. TRUSTED IP DETECTION
    const clientIp =
      req.headers.get("cf-connecting-ip") ||
      req.headers.get("x-real-ip") ||
      "127.0.0.1";

    // IP Security Check
    const { data: ipStatus, error: ipErr } = await supabaseAdmin.rpc("check_ip_security_status", {
      p_ip: clientIp,
    });

    if (ipErr || !ipStatus || !ipStatus.allowed) {
      return new Response(
        JSON.stringify({ error: "Access blocked due to security policy. Please contact support." }),
        { status: 403, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // Parse payload
    const { customer_code, name, pin, password } = await req.json();

    if (!customer_code || typeof customer_code !== "string" || !customer_code.trim()) {
      await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
      return new Response(
        JSON.stringify({ error: "Customer Code is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (!password || typeof password !== "string" || password.trim().length === 0) {
      await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
      return new Response(
        JSON.stringify({ error: "Password is required." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    const rawPassword = password.trim();
    // Map short passwords (< 6 chars, e.g. 4-digit PINs) to meet Supabase Auth min length requirement
    const authPassword = rawPassword.length < 6 ? `OK_${rawPassword}_2026` : rawPassword;
    const normalizedCode = customer_code.trim().toUpperCase();

    // 2. Customer Code Lock Check
    const { data: lockCheck, error: lockErr } = await supabaseAdmin.rpc("check_rate_limit_lock", {
      p_identifier: normalizedCode,
    });

    if (lockErr || (lockCheck && !lockCheck.allowed)) {
      await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
      return new Response(
        JSON.stringify({ error: lockCheck?.message || "Too many failed attempts. Account temporarily locked." }),
        { status: 429, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 3. Query public.customers for eligibility (CASE-INSENSITIVE MATCH)
    const { data: customer, error: custErr } = await supabaseAdmin
      .from("customers")
      .select("id, auth_user_id, phone, account_status, initial_login_completed, temp_setup_pin_hash")
      .ilike("customer_code", normalizedCode)
      .maybeSingle();

    if (custErr || !customer || (customer.account_status && customer.account_status !== "active")) {
      await supabaseAdmin.rpc("record_failed_attempt", { p_identifier: normalizedCode });
      await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
      return new Response(
        JSON.stringify({ error: "Invalid Customer Code or account is inactive." }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    if (customer.initial_login_completed === true) {
      await supabaseAdmin.rpc("record_failed_attempt", { p_identifier: normalizedCode });
      await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
      return new Response(
        JSON.stringify({ error: "Already have a password" }),
        { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
      );
    }

    // 4. STRICT MANDATORY 4-DIGIT PIN VERIFICATION (IF PIN HASH EXISTS)
    if (customer.temp_setup_pin_hash) {
      const pinStr = pin ? pin.toString().trim() : "";
      if (!pinStr || pinStr.length !== 4 || !/^\d{4}$/.test(pinStr)) {
        await supabaseAdmin.rpc("record_failed_attempt", { p_identifier: normalizedCode });
        await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
        return new Response(
          JSON.stringify({ error: "A valid 4-digit onboarding PIN is required." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }

      const { data: pinValid } = await supabaseAdmin.rpc("verify_pin_hash", {
        p_pin: pinStr,
        p_hash: customer.temp_setup_pin_hash,
      });

      if (!pinValid) {
        await supabaseAdmin.rpc("record_failed_attempt", { p_identifier: normalizedCode });
        await supabaseAdmin.rpc("record_ip_failed_attempt", { p_ip: clientIp });
        await supabaseAdmin.from("security_audit_logs").insert({
          customer_id: customer.id,
          event_type: "PIN_VERIFICATION_FAILED",
          details: { code: normalizedCode, ip: clientIp },
        });

        return new Response(
          JSON.stringify({ error: "Invalid onboarding PIN. Please verify details or contact store." }),
          { status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" } }
        );
      }
    }

    // 5. SECURE PASSWORD SETTING (CREATE OR UPDATE AUTH USER)
    const synthEmail = `${normalizedCode.toLowerCase()}@aplibhaji.com`;
    let targetAuthUserId: string | null = customer.auth_user_id || null;

    if (!targetAuthUserId) {
      // Lookup existing Auth user by email if auth_user_id not linked yet
      const { data: userList } = await supabaseAdmin.auth.admin.listUsers();
      const existingUser = userList?.users?.find(
        (u: any) => u.email?.toLowerCase() === synthEmail.toLowerCase()
      );
      if (existingUser) {
        targetAuthUserId = existingUser.id;
      }
    }

    if (targetAuthUserId) {
      // Update existing Auth user password securely with Bcrypt hashing in Supabase Auth
      const { error: updateErr } = await supabaseAdmin.auth.admin.updateUserById(targetAuthUserId, {
        password: authPassword,
        email_confirm: true,
        user_metadata: { name: name || normalizedCode, phone: customer.phone },
      });

      if (updateErr) {
        throw new Error(`Failed to update password: ${updateErr.message}`);
      }
    } else {
      // Create new Auth user in Supabase Auth
      const { data: newAuthUser, error: createErr } = await supabaseAdmin.auth.admin.createUser({
        email: synthEmail,
        password: authPassword,
        email_confirm: true,
        user_metadata: { name: name || normalizedCode, phone: customer.phone },
      });

      if (createErr || !newAuthUser.user) {
        throw new Error(`Failed to create auth user: ${createErr?.message}`);
      }

      targetAuthUserId = newAuthUser.user.id;
    }

    // 6. Link Customer record & mark initial_login_completed = TRUE
    const { error: linkErr } = await supabaseAdmin
      .from("customers")
      .update({
        auth_user_id: targetAuthUserId,
        initial_login_completed: true,
        temp_setup_pin_hash: null,
        is_guest: false,
      })
      .eq("id", customer.id);

    if (linkErr) {
      throw new Error(`Failed to link customer profile: ${linkErr.message}`);
    }

    // 7. Reset rate limit counters & record IP success
    await supabaseAdmin.rpc("reset_rate_limit", { p_identifier: normalizedCode });
    await supabaseAdmin.rpc("record_ip_success", { p_ip: clientIp });

    // 8. Audit log entry
    await supabaseAdmin.from("security_audit_logs").insert({
      customer_id: customer.id,
      auth_user_id: targetAuthUserId,
      event_type: "PASSWORD_SET_SUCCESS",
      details: { code: normalizedCode, ip: clientIp },
    });

    return new Response(
      JSON.stringify({ success: true, email: synthEmail }),
      { status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  } catch (err: any) {
    return new Response(
      JSON.stringify({ error: err.message || "An unexpected error occurred during password setup." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }
});
