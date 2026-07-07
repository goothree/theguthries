// notify-web/index.ts
// Sends Web Push notifications (browser / installed PWA) to subscriptions in
// public.push_subscriptions. Mirrors the APNs functions' rules:
//   type "new_post"   -> everyone except excludeUserId
//   type "engagement" -> only postAuthorId
import webpush from "npm:web-push@3.6.7";
import { createClient } from "jsr:@supabase/supabase-js@2";

webpush.setVapidDetails(
  Deno.env.get("VAPID_SUBJECT")!,
  Deno.env.get("VAPID_PUBLIC_KEY")!,
  Deno.env.get("VAPID_PRIVATE_KEY")!,
);

Deno.serve(async (req) => {
  try {
    const {
      type,
      postId,
      authorName,
      excludeUserId,
      postAuthorId,
      engagementType,
      actorName,
    } = await req.json();

    const supabase = createClient(
      Deno.env.get("SUPABASE_URL")!,
      Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    );

    let query = supabase.from("push_subscriptions").select("endpoint,p256dh,auth");
    let body: string;
    if (type === "new_post") {
      query = query.neq("user_id", excludeUserId);
      body = `${authorName ?? "Someone"} shared something new!`;
    } else {
      query = query.eq("user_id", postAuthorId);
      body = engagementType === "comment"
        ? `${actorName ?? "Someone"} commented on your post`
        : `${actorName ?? "Someone"} reacted to your post`;
    }

    const { data: subs, error } = await query;
    if (error) return new Response(JSON.stringify({ error: error.message }), { status: 500 });

    const notification = JSON.stringify({ title: "The Guthrie's \uD83C\uDFE1", body, url: "./", postId });

    let sent = 0;
    await Promise.all((subs ?? []).map(async (s) => {
      const subscription = { endpoint: s.endpoint, keys: { p256dh: s.p256dh, auth: s.auth } };
      try {
        await webpush.sendNotification(subscription, notification);
        sent++;
      } catch (e) {
        const code = (e as { statusCode?: number })?.statusCode;
        // Prune expired/invalid subscriptions.
        if (code === 404 || code === 410) {
          await supabase.from("push_subscriptions").delete().eq("endpoint", s.endpoint);
        }
      }
    }));

    return new Response(JSON.stringify({ sent }), {
      headers: { "Content-Type": "application/json" },
    });
  } catch (e) {
    return new Response(JSON.stringify({ error: String(e) }), { status: 400 });
  }
});
