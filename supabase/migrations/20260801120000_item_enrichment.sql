-- Enrich Top 10 items with tags, photos, ratings, visit tracking.
-- Add list sort_order for drag-reorder of a user's lists.

alter table public.top_tens
  add column if not exists sort_order int not null default 0;

alter table public.top_ten_items
  add column if not exists tags text[] not null default '{}',
  add column if not exists photo_urls text[] not null default '{}',
  add column if not exists rating int check (rating is null or rating between 1 and 5),
  add column if not exists is_favorite boolean not null default false,
  add column if not exists visited_on date,
  add column if not exists updated_at timestamptz not null default now();

drop trigger if exists top_ten_items_updated_at on public.top_ten_items;
create trigger top_ten_items_updated_at
before update on public.top_ten_items
for each row execute function public.set_updated_at();

-- Allow temporary ranks during drag-reorder (app still caps at 10 visible items).
alter table public.top_ten_items drop constraint if exists top_ten_items_rank_check;
alter table public.top_ten_items
  add constraint top_ten_items_rank_check check (rank between 1 and 100);

create index if not exists top_tens_owner_sort_idx
  on public.top_tens (owner_id, sort_order, updated_at desc);

create index if not exists top_ten_items_tags_gin
  on public.top_ten_items using gin (tags);

insert into storage.buckets (id, name, public)
values ('item-photos', 'item-photos', true)
on conflict (id) do nothing;

drop policy if exists "Item photos are public" on storage.objects;
create policy "Item photos are public"
  on storage.objects for select
  to authenticated, anon
  using (bucket_id = 'item-photos');

drop policy if exists "Users upload item photos" on storage.objects;
create policy "Users upload item photos"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );

drop policy if exists "Users update item photos" on storage.objects;
create policy "Users update item photos"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = public.firebase_uid()
  )
  with check (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );

drop policy if exists "Users delete item photos" on storage.objects;
create policy "Users delete item photos"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'item-photos'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );
