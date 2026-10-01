-- ============================================================================
-- Cup & Saucer — Master Product Data Entry
-- ONE-TIME UPDATE: saves the product order (drag ⠿ / ↑↓ / "Sort by…")
-- so it's the same on every device and survives reloads.
--
-- Run this whole file once in: Supabase Dashboard → SQL Editor → New query → Run
-- Safe to run more than once. It does not change or delete any product data.
-- ============================================================================

-- 1. Each product remembers its position in the list
alter table products add column if not exists sort_order double precision;
create index if not exists products_sort_order_idx on products (sort_order);

-- 2. Save a whole new order in a single request (used when dragging or sorting)
create or replace function set_product_order(p_ids bigint[], p_orders double precision[])
returns void
language sql
security definer
set search_path = public
as $$
  update products p
     set sort_order = u.ord
    from unnest(p_ids, p_orders) as u(id, ord)
   where p.id = u.id;
$$;

grant execute on function set_product_order(bigint[], double precision[]) to anon, authenticated;

-- 3. Make the new column visible to the app right away
notify pgrst, 'reload schema';
