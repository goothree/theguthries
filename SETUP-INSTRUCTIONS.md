# Family Site — Setup Instructions

You have two files:
- **`index.html`** — the complete website
- **`supabase-setup.sql`** — the database setup script

Follow these steps in order. Each step should only take a few minutes.

---

## Step 1: Create a Free Supabase Account

1. Go to **[supabase.com](https://supabase.com)** and click **Start your project**
2. Sign in with GitHub (easiest) or create an account with email
3. Click **New Project**
4. Fill in:
   - **Name:** `family-site` (or anything you like)
   - **Database Password:** choose a strong password and save it somewhere
   - **Region:** pick the one closest to you
5. Click **Create new project** and wait about 1 minute for it to set up

---

## Step 2: Run the Database Setup

1. In your Supabase project, click **SQL Editor** in the left sidebar
2. Click **New query**
3. Open the `supabase-setup.sql` file (in the folder I created) and copy **all** of its contents
4. Paste it into the SQL editor
5. Click **Run** (the green button)
6. You should see "Success" — your database and photo storage are now ready

---

## Step 3: Get Your Supabase Keys

1. In your Supabase project, click **Project Settings** (gear icon) in the left sidebar
2. Click **API**
3. You'll see two things you need:
   - **Project URL** — looks like `https://abcdefgh.supabase.co`
   - **anon public** key — a long string starting with `eyJ...`
4. Copy both of these — you'll need them in the next step

---

## Step 4: Add Your Keys to the Website

1. Open the `index.html` file in a plain text editor
   - On Mac: right-click → Open With → TextEdit
   - On Windows: right-click → Open With → Notepad
2. Near the top of the JavaScript section, find these two lines:
   ```
   const SUPABASE_URL  = 'YOUR_SUPABASE_URL';
   const SUPABASE_ANON = 'YOUR_SUPABASE_ANON_KEY';
   ```
3. Replace `YOUR_SUPABASE_URL` with your Project URL (keep the quotes)
4. Replace `YOUR_SUPABASE_ANON_KEY` with your anon public key (keep the quotes)
5. Save the file

---

## Step 5: Customize the Site Name (Optional)

In the same `index.html` file, search for `Our Family` and replace it with your family name — for example, `The Smiths` or `Johnson Family`. There are a few places where it appears.

---

## Step 6: Put the Site on GitHub

1. Go to **[github.com](https://github.com)** and sign in
2. Click the **+** button (top right) → **New repository**
3. Name it `family-site`, set it to **Private**, click **Create repository**
4. On the next page, click **uploading an existing file**
5. Drag and drop your `index.html` file into the upload area
6. Click **Commit changes**

---

## Step 7: Deploy to Cloudflare Pages

1. Log into your **Cloudflare dashboard** at [dash.cloudflare.com](https://dash.cloudflare.com)
2. Click **Workers & Pages** in the left sidebar
3. Click **Create application** → **Pages** → **Connect to Git**
4. Connect your GitHub account and select your `family-site` repository
5. Leave all build settings as defaults and click **Save and Deploy**
6. Wait about 30 seconds — Cloudflare will give you a URL like `family-site.pages.dev`

---

## Step 8: Connect Your Custom Domain

1. Still in Cloudflare Pages, click on your `family-site` project
2. Go to **Custom domains** → **Set up a custom domain**
3. Type in your domain (e.g., `family.yourdomain.com`) and click **Continue**
4. Cloudflare will automatically configure the DNS since you're already on Cloudflare — just confirm

---

## Step 9: Invite Family Members

Share the website link with your family. They can:
- Click **Create Account** to sign up
- Sign in and start posting photos and stories right away

> **Tip:** You can control who gets to sign up by going to **Supabase → Authentication → Settings** and enabling **"Confirm email"** — that way you can see who signs up before their account is active.

---

## That's It! 🎉

Your family site is live. It's:
- **Private** — only people with accounts can see anything
- **Free** — Cloudflare Pages and Supabase's free tier cover a small family easily
- **Yours** — no ads, no algorithm, just family

---

## Need Help?

If you get stuck on any step, just come back and describe where you are —
I can walk you through it in more detail.
