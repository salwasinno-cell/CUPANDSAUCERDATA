# Cup & Saucer — Master Product Data Entry — Deployment Guide

The tool is a real, multi-staff app: every product, image, category, and
edit is stored in a shared **Supabase** database instead of one browser's
local storage. Everyone who opens the page sees the same live sheet, in
real time. **There is no sign-in.** Whoever opens the page just types their
name into "Working as" at the top — same as before — and that name is what
shows up as who created/edited each product and in the activity history.

You need two free accounts: **Supabase** (database + image storage) and
**Netlify** (hosting the page itself).

---

## 1. Create your Supabase project

1. Go to https://supabase.com → sign up (free) → **New project**.
2. Pick any name/region, set a database password (save it somewhere), wait
   ~2 minutes for it to finish provisioning.
3. In the left sidebar, go to **SQL Editor → New query**.
4. Open the file **`supabase-setup.sql`** (included alongside this guide),
   copy its entire contents, paste into the SQL editor, and click **Run**.
   This creates the `products`, `app_config`, and `activity_log` tables,
   turns on realtime sync, and creates the `product-images` storage bucket.
5. In the left sidebar, go to **Project Settings → API**. Copy two values:
   - **Project URL** (looks like `https://xxxxxxxxxxxx.supabase.co`)
   - **anon public** key (a long string under "Project API keys")

There are no staff accounts to create — nobody logs in.

## 2. Paste your keys into the HTML file

Open **`product-data-entry-premium.html`** in a text editor and find this
block near the top of the `<script>` section (search for `SUPABASE_URL`):

```js
const SUPABASE_URL = 'https://YOUR-PROJECT-REF.supabase.co';
const SUPABASE_ANON_KEY = 'YOUR-ANON-PUBLIC-KEY';
```

Replace both placeholder strings with the **Project URL** and **anon
public** key you copied in step 1. Save the file. If you forget this step,
the page shows an obvious warning banner instead of failing silently.

## 3. Deploy to Netlify

**Easiest way (drag and drop, no account setup beyond signing up):**

1. Go to https://app.netlify.com → sign up free → go to **Sites**.
2. Drag your edited `product-data-entry-premium.html` file (rename it to
   `index.html` first) onto the Netlify dashboard where it says
   "Drag and drop your site output folder here."
3. Netlify gives you a live URL immediately (e.g.
   `random-name-123.netlify.app`). You can rename it under **Site
   configuration → Change site name**, or attach your own domain there too.

That's it — share that URL with your staff. Everyone who opens it is in,
immediately, with the sheet fully shared and synced live.

---

## Important: what "no sign-in" actually means

There's a real tradeoff here worth understanding, not just a convenience:

- **Anyone with the page's URL can read and write every product** — add,
  edit, delete, upload/replace photos, all of it. It works exactly like an
  unprotected shared spreadsheet link: the security is "nobody outside the
  team knows the URL," not an actual login check.
- The "Working as" name is **not verified** — it's just a label someone
  types in. Nothing stops a person from typing someone else's name.
- **Don't post the Netlify URL anywhere public** (a public wiki, a public
  Slack, indexed anywhere search engines crawl). Share it directly with
  staff instead — message it, don't publish it.
- If this ever needs to be locked down properly — say, the URL leaks, or
  you want real per-person accountability — Supabase Auth (email/password
  login per staff member, enforced server-side) is the fix, and it's a
  contained change to bring back. Just ask.

For a small internal team sharing a private link, this is a reasonable and
common tradeoff — just going in with eyes open about what it means.

---

## What's real

- **Every product row** is saved to Postgres the moment you edit it —
  visible to everyone else within about a second.
- **Product images** upload to Supabase Storage and are shown from a real
  public URL — no longer lost on refresh or trapped in one browser. Replacing
  or removing a photo (or deleting/clearing rows) also deletes the old file
  from Storage, so unused images don't pile up.
- **Categories, subcategories, materials, and the staff list** you add
  through "Manage Lists" sync live to everyone too.
- **Activity history** is a shared, persisted log across the whole team.
- **Bulk operations** (CSV import, bulk edit, bulk duplicate, bulk delete,
  undo/redo) save in a single batched request instead of one request per row.
- **Concurrent-editing safety**: if a teammate's edit arrives while you're
  actively typing in that same row, the app holds the incoming update back
  instead of overwriting your in-progress keystrokes, and applies it the
  moment you move on.
- If a connection drops, the app falls back to a local backup copy in that
  browser and automatically resyncs to Supabase once it's reachable again.
- **Free tier limits** (fine for normal catalog work, worth knowing):
  Supabase free tier gives 500 MB database storage, 1 GB file storage, and
  pauses a project after 7 days with zero API requests (anyone visiting the
  page wakes it back up in a few seconds). If your catalog and photo
  library grow very large, you'll eventually want Supabase's paid tier —
  that's a "when you hit it" problem, not a launch blocker.
- Conflict handling is last-write-wins per row: if two people edit the
  exact same product within the same second, the later save wins. For a
  small internal team entering distinct products this essentially never
  comes up in practice.
