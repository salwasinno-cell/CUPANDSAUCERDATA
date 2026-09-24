-- ============================================================================
-- Cup & Saucer — Master Product Data Entry
-- Supabase setup script
-- Run this ENTIRE file once in: Supabase Dashboard → SQL Editor → New query → Run
--
-- NOTE ON ACCESS: this version has NO login screen. Anyone who has the
-- deployed page's URL can read and write every product, exactly like a
-- shared spreadsheet link. Identity is just whatever a person types into
-- "Working as" in the app — it isn't verified. That's why every policy
-- below is `using (true)` rather than requiring an authenticated user.
-- Keep the Netlify URL out of anything public, and only share it with
-- your staff. If you ever want real accounts back, say so and the
-- Supabase Auth version can be restored.
-- ============================================================================

-- Needed for gen_random_uuid() / crypto functions (usually already on)
create extension if not exists pgcrypto;

-- ----------------------------------------------------------------------------
-- 1. PRODUCTS — one row per product. `values` holds the 23 field answers as
--    a JSON array, in the exact same order as the `schema` array in the HTML
--    file, so the app can read/write it directly by index.
-- ----------------------------------------------------------------------------
create table if not exists products (
  id          bigint primary key,
  values      jsonb not null default '[]'::jsonb,
  created_at  timestamptz not null default now(),
  created_by  text,
  updated_at  timestamptz not null default now(),
  updated_by  text,
  history     jsonb not null default '[]'::jsonb
);

-- ----------------------------------------------------------------------------
-- 2. APP_CONFIG — one single shared row holding the dynamic category list,
--    dynamic staff list, dynamic materials-per-category, and the SKU counter,
--    so every staff member's browser sees the same dropdown options live.
-- ----------------------------------------------------------------------------
create table if not exists app_config (
  id          int primary key default 1,
  data        jsonb not null default '{}'::jsonb,
  updated_at  timestamptz not null default now(),
  constraint app_config_singleton check (id = 1)
);
insert into app_config (id, data) values (1, '{}'::jsonb)
  on conflict (id) do nothing;

-- ----------------------------------------------------------------------------
-- 3. ACTIVITY_LOG — every edit/undo/import/etc. across every staff member,
--    persisted so the "History" panel isn't lost on refresh and is shared.
-- ----------------------------------------------------------------------------
create table if not exists activity_log (
  id     bigserial primary key,
  at     timestamptz not null default now(),
  actor  text,
  text   text not null
);

-- ----------------------------------------------------------------------------
-- 4. ROW LEVEL SECURITY — RLS stays ON (good practice, and needed for
--    Realtime), but every policy allows anyone with the anon key — i.e.
--    anyone who has this deployed page open — to read and write. There is
--    no per-user identity check, since the app has no login.
-- ----------------------------------------------------------------------------
alter table products     enable row level security;
alter table app_config   enable row level security;
alter table activity_log enable row level security;

drop policy if exists "staff read products"   on products;
drop policy if exists "staff insert products" on products;
drop policy if exists "staff update products" on products;
drop policy if exists "staff delete products" on products;
drop policy if exists "anyone with anon key reads products"   on products;
drop policy if exists "anyone with anon key inserts products" on products;
drop policy if exists "anyone with anon key updates products" on products;
drop policy if exists "anyone with anon key deletes products" on products;
create policy "anyone with anon key reads products"   on products for select using (true);
create policy "anyone with anon key inserts products" on products for insert with check (true);
create policy "anyone with anon key updates products" on products for update using (true);
create policy "anyone with anon key deletes products" on products for delete using (true);

drop policy if exists "staff read config"  on app_config;
drop policy if exists "staff update config" on app_config;
drop policy if exists "anyone with anon key reads config"  on app_config;
drop policy if exists "anyone with anon key updates config" on app_config;
create policy "anyone with anon key reads config"  on app_config for select using (true);
create policy "anyone with anon key updates config" on app_config for update using (true);

drop policy if exists "staff read activity"  on activity_log;
drop policy if exists "staff insert activity" on activity_log;
drop policy if exists "anyone with anon key reads activity"  on activity_log;
drop policy if exists "anyone with anon key inserts activity" on activity_log;
create policy "anyone with anon key reads activity"  on activity_log for select using (true);
create policy "anyone with anon key inserts activity" on activity_log for insert with check (true);

-- ----------------------------------------------------------------------------
-- 5. REALTIME — so every staff member's browser gets live updates the
--    instant a teammate adds, edits, or deletes a row.
-- ----------------------------------------------------------------------------
alter publication supabase_realtime add table products;
alter publication supabase_realtime add table app_config;
alter publication supabase_realtime add table activity_log;

-- ----------------------------------------------------------------------------
-- 6. STORAGE — a public bucket for product photos. Anyone with the anon key
--    can read, upload, replace, or delete, same reasoning as above.
-- ----------------------------------------------------------------------------
insert into storage.buckets (id, name, public)
  values ('product-images', 'product-images', true)
  on conflict (id) do nothing;

drop policy if exists "staff upload product images" on storage.objects;
drop policy if exists "staff update product images" on storage.objects;
drop policy if exists "staff delete product images" on storage.objects;
drop policy if exists "public read product images"  on storage.objects;
drop policy if exists "anyone with anon key uploads product images" on storage.objects;
drop policy if exists "anyone with anon key updates product images" on storage.objects;
drop policy if exists "anyone with anon key deletes product images" on storage.objects;

create policy "public read product images" on storage.objects
  for select using (bucket_id = 'product-images');
create policy "anyone with anon key uploads product images" on storage.objects
  for insert with check (bucket_id = 'product-images');
create policy "anyone with anon key updates product images" on storage.objects
  for update using (bucket_id = 'product-images');
create policy "anyone with anon key deletes product images" on storage.objects
  for delete using (bucket_id = 'product-images');

-- ============================================================================
-- Done. No staff accounts to create — just paste your Project URL + anon
-- public key into the HTML file (near the top of the <script> section) and
-- deploy to Netlify. Anyone with that page's URL is in.
-- ============================================================================
