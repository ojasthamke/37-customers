import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface PushPayload {
  token?: string;
  tokens?: string[];
  userId?: string;
  targetRole?: "customer" | "admin";
  topic?: string;
  title: string;
  body: string;
  payload?: string;
  channelId?: string;
}

interface TokenResponse {
  access_token: string;
  expires_in: number;
}

function b64UrlEncode(str: string): string {
  const bytes = new TextEncoder().encode(str);
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

function uint8ArrayToB64Url(bytes: Uint8Array): string {
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i++) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

async function signRS256(input: string, privateKeyPem: string): Promise<string> {
  const rawKeyB64 = privateKeyPem
    .replace(/-----BEGIN PRIVATE KEY-----/, "")
    .replace(/-----END PRIVATE KEY-----/, "")
    .replace(/\s+/g, "");

  const binaryKey = atob(rawKeyB64);
  const keyBuffer = new Uint8Array(binaryKey.length);
  for (let i = 0; i < binaryKey.length; i++) {
    keyBuffer[i] = binaryKey.charCodeAt(i);
  }

  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8",
    keyBuffer.buffer,
    {
      name: "RSASSA-PKCS1-v1_5",
      hash: "SHA-256",
    },
    false,
    ["sign"]
  );

  const signature = await crypto.subtle.sign(
    "RSASSA-PKCS1-v1_5",
    cryptoKey,
    new TextEncoder().encode(input)
  );

  return uint8ArrayToB64Url(new Uint8Array(signature));
}

async function getAccessToken(serviceAccount: any): Promise<string> {
  const jwtHeader = b64UrlEncode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  const now = Math.floor(Date.now() / 1000);
  const jwtClaim = b64UrlEncode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }));

  const signInput = `${jwtHeader}.${jwtClaim}`;
  const signature = await signRS256(signInput, serviceAccount.private_key);
  const jwtAssertion = `${signInput}.${signature}`;

  const bodyParams = new URLSearchParams({
    grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
    assertion: jwtAssertion
  });

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: bodyParams.toString()
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch access token: ${await response.text()}`);
  }

  const data: TokenResponse = await response.json();
  return data.access_token;
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, Authorization, x-webhook-secret, apikey",
      }
    });
  }

  try {
    const expectedSecret = Deno.env.get("PUSH_WEBHOOK_SECRET");
    const customHeader = req.headers.get("x-webhook-secret");
    const authHeader = req.headers.get("Authorization");
    const apikeyHeader = req.headers.get("apikey");

    const isAuthorized = 
      (customHeader && expectedSecret && customHeader === expectedSecret) ||
      (authHeader && expectedSecret && (authHeader === `Bearer ${expectedSecret}` || authHeader === expectedSecret)) ||
      (apikeyHeader && apikeyHeader.length > 10) ||
      (authHeader && (authHeader.startsWith("Bearer eyJ") || authHeader.startsWith("Bearer sb_")));

    if (!isAuthorized) {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" }
      });
    }

    const payload: PushPayload = await req.json();

    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT environment variable.");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);

    const accessToken = await getAccessToken(serviceAccount);
    const projectId = serviceAccount.project_id;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const channelId = payload.channelId ?? 
      (payload.targetRole === "admin" ? "orderkart_channel" : "aplibhaji_customer_channel");

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "https://xsqaxvbrjvhgemlfgoxn.supabase.co";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

    async function sendToFcmTarget(targetObj: { token?: string; topic?: string }) {
      const targetKey = targetObj.token ? "token" : "topic";
      const targetValue = targetObj.token ?? targetObj.topic ?? "all_customers";

      const fcmMessage = {
        message: {
          [targetKey]: targetValue,
          notification: {
            title: payload.title,
            body: payload.body
          },
          data: {
            title: payload.title,
            body: payload.body,
            click_action: "FLUTTER_NOTIFICATION_CLICK",
            payload: payload.payload ?? "",
            timestamp: Date.now().toString()
          },
          android: {
            priority: "high",
            ttl: "86400s",
            notification: {
              channel_id: channelId,
              sound: "default",
              default_sound: true,
              default_vibrate_timings: true,
              notification_priority: "PRIORITY_MAX",
              visibility: "PUBLIC",
              click_action: "FLUTTER_NOTIFICATION_CLICK"
            }
          },
          apns: {
            headers: {
              "apns-priority": "10"
            },
            payload: {
              aps: {
                alert: {
                  title: payload.title,
                  body: payload.body
                },
                sound: "default",
                badge: 1,
                "content-available": 1
              }
            }
          }
        }
      };

      const res = await fetch(fcmUrl, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${accessToken}`
        },
        body: JSON.stringify(fcmMessage)
      });

      if (!res.ok) {
        const errText = await res.text();
        console.warn(`FCM send notice for ${targetValue}:`, res.status, errText);

        if (targetObj.token && serviceKey && (errText.includes("UNREGISTERED") || errText.includes("INVALID_ARGUMENT"))) {
          try {
            await fetch(`${supabaseUrl}/rest/v1/device_tokens?token=eq.${encodeURIComponent(targetObj.token)}`, {
              method: "DELETE",
              headers: {
                "apikey": serviceKey,
                "Authorization": `Bearer ${serviceKey}`
              }
            });
          } catch (_) {}
        }
      }

      return res;
    }

    const tokensToSend: Set<string> = new Set();

    if (payload.token && payload.token.trim().length > 0) {
      tokensToSend.add(payload.token.trim());
    }
    if (payload.tokens && Array.isArray(payload.tokens)) {
      payload.tokens.forEach(t => { if (t && t.trim().length > 0) tokensToSend.add(t.trim()); });
    }

    if (payload.targetRole && serviceKey) {
      try {
        const dtRes = await fetch(`${supabaseUrl}/rest/v1/device_tokens?select=token,user_id,updated_at&role=eq.${payload.targetRole}&order=updated_at.desc`, {
          headers: {
            "apikey": serviceKey,
            "Authorization": `Bearer ${serviceKey}`
          }
        });
        if (dtRes.ok) {
          const list: Array<{ token: string; user_id: string; updated_at?: string }> = await dtRes.json();
          const seenAdminUsers = new Set<string>();
          for (const r of list) {
            if (r.token && r.user_id && !seenAdminUsers.has(r.user_id)) {
              seenAdminUsers.add(r.user_id);
              tokensToSend.add(r.token.trim());
            } else if (r.token && !r.user_id) {
              tokensToSend.add(r.token.trim());
            }
          }
        }
      } catch (err) {
        console.warn("Error fetching role device tokens:", err);
      }
    }

    // Only resolve userId if no direct token was supplied
    if (tokensToSend.size === 0 && payload.userId && serviceKey) {
      try {
        // 1. Check device_tokens table for the latest registered token
        const dtRes = await fetch(`${supabaseUrl}/rest/v1/device_tokens?select=token,updated_at&user_id=eq.${payload.userId}&order=updated_at.desc&limit=1`, {
          headers: {
            "apikey": serviceKey,
            "Authorization": `Bearer ${serviceKey}`
          }
        });
        let foundToken = false;
        if (dtRes.ok) {
          const list: Array<{ token: string }> = await dtRes.json();
          if (list.length > 0 && list[0].token) {
            tokensToSend.add(list[0].token.trim());
            foundToken = true;
          }
        }

        // 2. Fallback to customers table if no device_tokens row exists
        if (!foundToken) {
          const custRes = await fetch(`${supabaseUrl}/rest/v1/customers?select=fcm_token&or=(id.eq.${payload.userId},auth_user_id.eq.${payload.userId})&fcm_token=not.is.null&limit=1`, {
            headers: {
              "apikey": serviceKey,
              "Authorization": `Bearer ${serviceKey}`
            }
          });
          if (custRes.ok) {
            const custs: Array<{ fcm_token: string }> = await custRes.json();
            if (custs.length > 0 && custs[0].fcm_token) {
              tokensToSend.add(custs[0].fcm_token.trim());
            }
          }
        }
      } catch (err) {
        console.warn("Error fetching user device tokens:", err);
      }
    }

    if (tokensToSend.size > 0) {
      await Promise.allSettled(Array.from(tokensToSend).map(tok => sendToFcmTarget({ token: tok })));
    } else if (payload.topic) {
      await sendToFcmTarget({ topic: payload.topic });
    }

    return new Response(JSON.stringify({ success: true, count: tokensToSend.size }), {
      headers: { "Content-Type": "application/json" }
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }
});
