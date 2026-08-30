// Deno Edge Function: send-push
// Place in supabase/functions/send-push/index.ts and deploy using: supabase functions deploy send-push

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

interface PushPayload {
  token: string;
  title: string;
  body: string;
  payload?: string;
}

// Google OAuth2 Token Response Interface
interface TokenResponse {
  access_token: string;
  expires_in: number;
}

// Helper to get Google OAuth2 access token using Firebase Service Account
async function getAccessToken(serviceAccount: any): Promise<string> {
  const jwtHeader = b64Encode(JSON.stringify({ alg: "RS256", typ: "JWT" }));
  
  const now = Math.floor(Date.now() / 1000);
  const jwtClaim = b64Encode(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: "https://www.googleapis.com/auth/firebase.messaging",
    aud: "https://oauth2.googleapis.com/token",
    exp: now + 3600,
    iat: now
  }));

  const signInput = `${jwtHeader}.${jwtClaim}`;
  const signedJwt = await signRS256(signInput, serviceAccount.private_key);

  const response = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: {
      "Content-Type": "application/x-www-form-urlencoded"
    },
    body: `grant_type=urn:ietf:params:oauth:grant-type:jwt-bearer&assertion=${signedJwt}`
  });

  if (!response.ok) {
    throw new Error(`Failed to fetch access token: ${await response.text()}`);
  }

  const data: TokenResponse = await response.json();
  return data.access_token;
}

// Base64 encoding helper
function b64Encode(str: string): string {
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

// RS256 signing using Deno WebCrypto API
async function signRS256(input: string, privateKeyPem: string): Promise<string> {
  // Extract key base64 from PEM
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

  const sigBytes = new Uint8Array(signature);
  let binarySig = "";
  for (let i = 0; i < sigBytes.byteLength; i++) {
    binarySig += String.fromCharCode(sigBytes[i]);
  }
  
  return btoa(binarySig)
    .replace(/=/g, "")
    .replace(/\+/g, "-")
    .replace(/\//g, "_");
}

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST",
        "Access-Control-Allow-Headers": "Content-Type, Authorization",
      }
    });
  }

  try {
    // 1. Verify authorization webhook token
    const authHeader = req.headers.get("Authorization");
    if (!authHeader || authHeader !== "Bearer my_secure_webhook_secret_token_12345") {
      return new Response(JSON.stringify({ error: "Unauthorized" }), {
        status: 401,
        headers: { "Content-Type": "application/json" }
      });
    }

    const payload: PushPayload = await req.json();
    
    // Retrieve Firebase Service Account JSON from secret environment variables
    const serviceAccountJson = Deno.env.get("FIREBASE_SERVICE_ACCOUNT");
    if (!serviceAccountJson) {
      throw new Error("Missing FIREBASE_SERVICE_ACCOUNT environment variable.");
    }
    const serviceAccount = JSON.parse(serviceAccountJson);

    // Fetch OAuth2 access token
    const accessToken = await getAccessToken(serviceAccount);

    // Call Firebase Cloud Messaging v1 Send API
    const projectId = serviceAccount.project_id;
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`;

    const fcmMessage = {
      message: {
        token: payload.token,
        notification: {
          title: payload.title,
          body: payload.body
        },
        data: {
          click_action: "FLUTTER_NOTIFICATION_CLICK",
          payload: payload.payload ?? ""
        },
        android: {
          priority: "high",
          notification: {
            sound: "default",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          }
        }
      }
    };

    const response = await fetch(fcmUrl, {
      method: "POST",
      headers: {
        "Content-Type": "application/json",
        "Authorization": `Bearer ${accessToken}`
      },
      body: JSON.stringify(fcmMessage)
    });

    if (!response.ok) {
      throw new Error(`FCM API returned error status: ${response.status} - ${await response.text()}`);
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { "Content-Type": "application/json" }
    });

  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      status: 400,
      headers: { "Content-Type": "application/json" }
    });
  }
});
