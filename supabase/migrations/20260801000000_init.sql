-- MyTop10 initial schema
-- Auth: Firebase UIDs (text). Use auth.jwt() ->> 'sub', NOT auth.uid().

create extension if not exists "pgcrypto";

create or replace function public.firebase_uid()
returns text
language sql
stable
as $$
  select auth.jwt() ->> 'sub';
$$;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Profiles
create table public.profiles (
  id text primary key,
  username text not null unique,
  full_name text not null,
  avatar_url text,
  bio text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint username_format check (username ~ '^[a-z0-9_]{3,24}$')
);

create trigger profiles_updated_at
before update on public.profiles
for each row execute function public.set_updated_at();

-- Categories
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  is_system boolean not null default false,
  created_by text references public.profiles (id) on delete set null,
  icon text,
  created_at timestamptz not null default now()
);

-- Top tens
create table public.top_tens (
  id uuid primary key default gen_random_uuid(),
  owner_id text not null references public.profiles (id) on delete cascade,
  title text not null,
  category_id uuid references public.categories (id) on delete set null,
  visibility text not null default 'public' check (visibility in ('private', 'followers', 'public')),
  cover_url text,
  upvotes int not null default 0,
  downvotes int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index top_tens_owner_idx on public.top_tens (owner_id);
create index top_tens_category_idx on public.top_tens (category_id);
create index top_tens_visibility_idx on public.top_tens (visibility);

create trigger top_tens_updated_at
before update on public.top_tens
for each row execute function public.set_updated_at();

-- Items
create table public.top_ten_items (
  id uuid primary key default gen_random_uuid(),
  top_ten_id uuid not null references public.top_tens (id) on delete cascade,
  rank int not null check (rank between 1 and 10),
  title text not null,
  note text,
  place_name text,
  lat double precision,
  lng double precision,
  address text,
  created_at timestamptz not null default now(),
  unique (top_ten_id, rank)
);

create index top_ten_items_list_idx on public.top_ten_items (top_ten_id);

-- Votes
create table public.votes (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles (id) on delete cascade,
  top_ten_id uuid not null references public.top_tens (id) on delete cascade,
  value int not null check (value in (-1, 1)),
  created_at timestamptz not null default now(),
  unique (user_id, top_ten_id)
);

-- Bookmarks
create table public.bookmarks (
  id uuid primary key default gen_random_uuid(),
  user_id text not null references public.profiles (id) on delete cascade,
  top_ten_id uuid not null references public.top_tens (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (user_id, top_ten_id)
);

-- Follows
create table public.follows (
  id uuid primary key default gen_random_uuid(),
  follower_id text not null references public.profiles (id) on delete cascade,
  following_id text not null references public.profiles (id) on delete cascade,
  created_at timestamptz not null default now(),
  unique (follower_id, following_id),
  check (follower_id <> following_id)
);

create index follows_follower_idx on public.follows (follower_id);
create index follows_following_idx on public.follows (following_id);

-- Vote counters
create or replace function public.refresh_vote_counts()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  target uuid;
begin
  target := coalesce(new.top_ten_id, old.top_ten_id);
  update public.top_tens t
  set
    upvotes = (select count(*) from public.votes v where v.top_ten_id = target and v.value = 1),
    downvotes = (select count(*) from public.votes v where v.top_ten_id = target and v.value = -1)
  where t.id = target;
  return coalesce(new, old);
end;
$$;

create trigger votes_refresh_counts
after insert or update or delete on public.votes
for each row execute function public.refresh_vote_counts();

-- Visibility helper
create or replace function public.can_view_top_ten(list public.top_tens)
returns boolean
language sql
stable
as $$
  select
    list.owner_id = public.firebase_uid()
    or list.visibility = 'public'
    or (
      list.visibility = 'followers'
      and exists (
        select 1 from public.follows f
        where f.following_id = list.owner_id
          and f.follower_id = public.firebase_uid()
      )
    );
$$;

-- RLS
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.top_tens enable row level security;
alter table public.top_ten_items enable row level security;
alter table public.votes enable row level security;
alter table public.bookmarks enable row level security;
alter table public.follows enable row level security;

-- Profiles policies
create policy "Profiles are publicly readable"
  on public.profiles for select
  to authenticated, anon
  using (true);

create policy "Users insert own profile"
  on public.profiles for insert
  to authenticated
  with check (id = public.firebase_uid());

create policy "Users update own profile"
  on public.profiles for update
  to authenticated
  using (id = public.firebase_uid())
  with check (id = public.firebase_uid());

-- Categories
create policy "Categories readable"
  on public.categories for select
  to authenticated, anon
  using (true);

create policy "Users create custom categories"
  on public.categories for insert
  to authenticated
  with check (created_by = public.firebase_uid() and is_system = false);

-- Top tens
create policy "View visible top tens"
  on public.top_tens for select
  to authenticated, anon
  using (public.can_view_top_ten(top_tens));

create policy "Owners insert top tens"
  on public.top_tens for insert
  to authenticated
  with check (owner_id = public.firebase_uid());

create policy "Owners update top tens"
  on public.top_tens for update
  to authenticated
  using (owner_id = public.firebase_uid())
  with check (owner_id = public.firebase_uid());

create policy "Owners delete top tens"
  on public.top_tens for delete
  to authenticated
  using (owner_id = public.firebase_uid());

-- Items
create policy "View items of visible lists"
  on public.top_ten_items for select
  to authenticated, anon
  using (
    exists (
      select 1 from public.top_tens t
      where t.id = top_ten_items.top_ten_id
        and public.can_view_top_ten(t)
    )
  );

create policy "Owners manage items"
  on public.top_ten_items for all
  to authenticated
  using (
    exists (
      select 1 from public.top_tens t
      where t.id = top_ten_items.top_ten_id
        and t.owner_id = public.firebase_uid()
    )
  )
  with check (
    exists (
      select 1 from public.top_tens t
      where t.id = top_ten_items.top_ten_id
        and t.owner_id = public.firebase_uid()
    )
  );

-- Votes
create policy "Votes readable"
  on public.votes for select
  to authenticated
  using (true);

create policy "Users manage own votes"
  on public.votes for all
  to authenticated
  using (user_id = public.firebase_uid())
  with check (user_id = public.firebase_uid());

-- Bookmarks
create policy "Users manage own bookmarks"
  on public.bookmarks for all
  to authenticated
  using (user_id = public.firebase_uid())
  with check (user_id = public.firebase_uid());

-- Follows
create policy "Follows readable"
  on public.follows for select
  to authenticated, anon
  using (true);

create policy "Users manage own follows"
  on public.follows for all
  to authenticated
  using (follower_id = public.firebase_uid())
  with check (follower_id = public.firebase_uid());

-- Seed system categories
insert into public.categories (name, slug, is_system, icon) values
  ('Restaurants', 'restaurants', true, 'fork.knife'),
  ('Coffee', 'coffee', true, 'cup.and.saucer.fill'),
  ('Movies', 'movies', true, 'film'),
  ('Albums', 'albums', true, 'music.note.list'),
  ('Books', 'books', true, 'book.fill'),
  ('Travel', 'travel', true, 'airplane'),
  ('Fitness', 'fitness', true, 'figure.run'),
  ('Games', 'games', true, 'gamecontroller.fill');

-- Storage buckets (run in dashboard if storage schema differs)
insert into storage.buckets (id, name, public)
values ('avatars', 'avatars', true)
on conflict (id) do nothing;

insert into storage.buckets (id, name, public)
values ('covers', 'covers', true)
on conflict (id) do nothing;

create policy "Avatar images are public"
  on storage.objects for select
  to authenticated, anon
  using (bucket_id = 'avatars');

create policy "Users upload own avatar"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );

create policy "Users update own avatar"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.firebase_uid()
  )
  with check (
    bucket_id = 'avatars'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );

create policy "Cover images are public"
  on storage.objects for select
  to authenticated, anon
  using (bucket_id = 'covers');

create policy "Users upload own covers"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'covers'
    and (storage.foldername(name))[1] = public.firebase_uid()
  );
