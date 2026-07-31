// notify-new-post/index.ts
// Called after a new post is created — notifies all other family members.

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const APNS_HOST   = Deno.env.get("APNS_SANDBOX") !== "false"
  ? "https://api.sandbox.push.apple.com"
  : "https://api.push.apple.com";
const BUNDLE_ID   = Deno.env.get("APNS_BUNDLE_ID")!;
const TEAM_ID     = Deno.env.get("APNS_TEAM_ID")!;
const KEY_ID      = Deno.env.get("APNS_KEY_ID")!;
const PRIVATE_KEY = Deno.env.get("APNS_PRIVATE_KEY")!;

// ── JWT helpers ────────────────────────────────────────────────

let cachedJwt: { token: string; issuedAt: number } | null = null;

function base64url(input: string | ArrayBuffer): string {
  const bytes = typeof input === "string"
    ? new TextEncoder().encode(input)
    : new Uint8Array(input);
  return btoa(String.fromCharCode(...bytes))
    .replace(/\+/g, "-").replace(/\//g, "_").replace(/=/g, "");
}

async function getApnsJwt(): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cachedJwt && (now - cachedJwt.issuedAt) < 2400) return cachedJwt.token;

  const header  = base64url(JSON.stringify({ alg: "ES256", kid: KEY_ID }));
  const payload = base64url(JSON.stringify({ iss: TEAM_ID, iat: now }));

  const keyPem   = PRIVATE_KEY
    .replace("-----BEGIN PRIVATE KEY-----", "")
    .replace("-----END PRIVATE KEY-----", "")
    .replace(/\s+/g, "");
  const keyBytes = Uint8Array.from(atob(keyPem), c => c.charCodeAt(0));
  const cryptoKey = await crypto.subtle.importKey(
    "pkcs8", keyBytes,
    { name: "ECDSA", namedCurve: "P-256" },
    false, ["sign"]
  );

  const data = new TextEncoder().encode(`${header}.${payload}`);
  const sig  = await crypto.subtle.sign({ name: "ECDSA", hash: "SHA-256" }, cryptoKey, data);
  const token = `${header}.${payload}.${base64url(sig)}`;

  cachedJwt = { token, issuedAt: now };
  return token;
}

// ── APNs send ─────────────────────────────────────────────────

async function sendApns(
  deviceToken: string,
  title: string,
  body: string,
  jwt: string,
  postId?: string
): Promise<{ ok: boolean; status: number; reason: string }> {
  const payload: Record<string, unknown> = {
    aps: { alert: { title, body }, sound: "default", badge: 1 },
  };
  if (postId) payload.postId = postId;
  const res = await fetch(`${APNS_HOST}/3/device/${deviceToken}`, {
    method: "POST",
    headers: {
      "content-type":   "application/json",
      "apns-push-type": "alert",
      "apns-topic":     BUNDLE_ID,
      "apns-priority":  "10",
      "authorization":  `bearer ${jwt}`,
    },
    body: JSON.stringify(payload),
  });
  const reason = res.status === 200 ? "ok" : (await res.json().catch(() => ({}))).reason ?? "unknown";
  if (res.status !== 200) {
    console.error(`APNs error for token ${deviceToken.slice(0, 8)}…: ${res.status} ${reason}`);
  }
  return { ok: res.status === 200, status: res.status, reason };
}

// ── Handler ───────────────────────────────────────────────────

serve(async (req) => {
  const { postId, authorName, excludeUserId } = await req.json();

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  const { data: rows } = await supabase
    .from("device_tokens")
    .select("token")
    .neq("user_id", excludeUserId);

  const tokens = rows ?? [];
  if (tokens.length === 0) {
    return new Response(JSON.stringify({ sent: 0 }), { status: 200 });
  }

  const jwt     = await getApnsJwt();
  const results = await Promise.all(
    tokens.map(({ token }) =>
      sendApns(token, "FamJam \uD83C\uDFE1", `${authorName} shared something new!`, jwt, postId)
    )
  );

  const succeeded = results.filter(r => r.ok).length;
  const failed    = results.filter(r => !r.ok).map(r => `${r.status} ${r.reason}`);
  console.log(`notify-new-post: sent=${succeeded} failed=${failed.length}`, failed);

  return new Response(JSON.stringify({ sent: succeeded, failed }), {
    headers: { "content-type": "application/json" },
  });
});
