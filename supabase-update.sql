-- ============================================================================
-- Cup & Saucer — Master Product Data Entry
-- DATABASE UPDATE (safe to run more than once — it never deletes or changes products)
--
-- Run this whole file once in: Supabase Dashboard → SQL Editor → New query → Run
-- It adds:
--   1. saving the product order (same on every device)
--   2. saving only the changed fields, so two people editing the same product
--      at the same time never overwrite each other
-- ============================================================================

-- 1. Product order ------------------------------------------------------------
-- 1a. Each product remembers its position in the list
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


-- 2. Field-by-field saving ----------------------------------------------------
-- Save only the fields that changed, so two people editing different fields
-- of the same product at the same time never overwrite each other.
create or replace function patch_product_values(p_id bigint, p_idx int[], p_vals text[], p_updated_by text)
returns timestamptz
language plpgsql
security definer
set search_path = public
as $$
declare
  v  jsonb;
  ts timestamptz := clock_timestamp();
begin
  select values into v from products where id = p_id for update;
  if not found then
    return null;                       -- product doesn't exist (the app will re-create it)
  end if;
  if v is null or jsonb_typeof(v) <> 'array' then v := '[]'::jsonb; end if;
  for i in 1 .. coalesce(array_length(p_idx, 1), 0) loop
    while jsonb_array_length(v) <= p_idx[i] loop
      v := v || '[""]'::jsonb;
    end loop;
    v := jsonb_set(v, array[p_idx[i]::text], to_jsonb(coalesce(p_vals[i], '')));
  end loop;
  if coalesce(array_length(p_idx, 1), 0) > 0 then
    update products set values = v, updated_at = ts, updated_by = p_updated_by where id = p_id;
  end if;
  return ts;
end;
$$;

grant execute on function patch_product_values(bigint, int[], text[], text) to anon, authenticated;

-- 3. Make the changes visible to the app right away
notify pgrst, 'reload schema';
