-- Findrn marketplace foundation
-- Apply with Supabase SQL Editor or Supabase CLI migrations.
-- Security note: public signup always creates a customer profile. Provider approval
-- and admin role assignment must happen through a trusted server/admin workflow.

begin;

do $$ begin
  create type public.findrn_role as enum ('customer', 'provider', 'admin');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.provider_status as enum ('pending', 'approved', 'rejected', 'suspended');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.service_status as enum ('draft', 'published', 'paused', 'archived');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.pricing_model as enum ('fixed', 'hourly', 'quote');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.service_location_mode as enum ('onsite', 'remote', 'hybrid');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.booking_status as enum ('requested', 'accepted', 'declined', 'cancelled', 'completed', 'disputed');
exception when duplicate_object then null; end $$;

do $$ begin
  create type public.payment_status as enum ('pending', 'authorized', 'paid', 'refunded', 'failed');
exception when duplicate_object then null; end $$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  avatar_url text,
  role public.findrn_role not null default 'customer',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  description text,
  icon text,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.provider_profiles (
  user_id uuid primary key references public.profiles(id) on delete cascade,
  business_name text not null,
  bio text not null default '',
  country_code text,
  city text,
  service_area text,
  status public.provider_status not null default 'pending',
  is_verified boolean not null default false,
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Keep direct contact details out of the publicly readable provider profile.
create table if not exists public.provider_private_details (
  user_id uuid primary key references public.provider_profiles(user_id) on delete cascade,
  phone text,
  contact_email text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  provider_id uuid not null references public.provider_profiles(user_id) on delete cascade,
  category_id uuid not null references public.categories(id),
  title text not null,
  description text not null,
  currency char(3) not null,
  price_amount numeric(12,2),
  pricing public.pricing_model not null default 'quote',
  duration_minutes integer,
  location_mode public.service_location_mode not null default 'onsite',
  city text,
  country_code text,
  status public.service_status not null default 'draft',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint services_price_nonnegative check (price_amount is null or price_amount >= 0),
  constraint services_duration_positive check (duration_minutes is null or duration_minutes > 0),
  constraint services_currency_format check (currency ~ '^[A-Z]{3}$')
);

create table if not exists public.bookings (
  id uuid primary key default gen_random_uuid(),
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.provider_profiles(user_id),
  service_id uuid not null references public.services(id),
  scheduled_start timestamptz,
  scheduled_end timestamptz,
  customer_note text,
  status public.booking_status not null default 'requested',
  quoted_amount numeric(12,2),
  currency char(3),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint booking_distinct_parties check (customer_id <> provider_id),
  constraint booking_schedule_order check (scheduled_end is null or scheduled_start is null or scheduled_end > scheduled_start),
  constraint booking_amount_nonnegative check (quoted_amount is null or quoted_amount >= 0)
);

create table if not exists public.booking_events (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.bookings(id) on delete cascade,
  actor_id uuid references public.profiles(id) on delete set null,
  from_status public.booking_status,
  to_status public.booking_status not null,
  note text,
  created_at timestamptz not null default now()
);

create table if not exists public.conversations (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid unique references public.bookings(id) on delete cascade,
  created_at timestamptz not null default now()
);

create table if not exists public.conversation_members (
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  user_id uuid not null references public.profiles(id) on delete cascade,
  joined_at timestamptz not null default now(),
  primary key (conversation_id, user_id)
);

create table if not exists public.messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references public.conversations(id) on delete cascade,
  sender_id uuid not null references public.profiles(id),
  body text not null,
  created_at timestamptz not null default now(),
  read_at timestamptz,
  constraint message_body_not_empty check (length(trim(body)) between 1 and 5000)
);

create table if not exists public.reviews (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id) on delete cascade,
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.provider_profiles(user_id),
  rating smallint not null check (rating between 1 and 5),
  review_text text,
  created_at timestamptz not null default now()
);

create table if not exists public.payment_records (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null unique references public.bookings(id),
  customer_id uuid not null references public.profiles(id),
  provider_id uuid not null references public.provider_profiles(user_id),
  amount numeric(12,2) not null check (amount >= 0),
  currency char(3) not null check (currency ~ '^[A-Z]{3}$'),
  status public.payment_status not null default 'pending',
  processor text,
  processor_reference text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  kind text not null,
  title text not null,
  body text not null default '',
  read_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists services_provider_status_idx on public.services(provider_id, status);
create index if not exists services_category_status_idx on public.services(category_id, status);
create index if not exists services_location_idx on public.services(country_code, city);
create index if not exists bookings_customer_created_idx on public.bookings(customer_id, created_at desc);
create index if not exists bookings_provider_created_idx on public.bookings(provider_id, created_at desc);
create index if not exists messages_conversation_created_idx on public.messages(conversation_id, created_at);
create index if not exists notifications_user_created_idx on public.notifications(user_id, created_at desc);

create or replace function public.findrn_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;

create or replace function public.findrn_set_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

create or replace function public.findrn_create_profile()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (
    new.id,
    coalesce(nullif(trim(new.raw_user_meta_data ->> 'full_name'), ''), '')
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists findrn_auth_user_created on auth.users;
create trigger findrn_auth_user_created
after insert on auth.users
for each row execute function public.findrn_create_profile();

create or replace function public.findrn_protect_profile_role()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() = old.id and new.role is distinct from old.role then
    raise exception 'Profile roles can only be changed by a trusted administrator.';
  end if;
  return new;
end;
$$;

drop trigger if exists findrn_profile_role_guard on public.profiles;
create trigger findrn_profile_role_guard
before update on public.profiles
for each row execute function public.findrn_protect_profile_role();

create or replace function public.findrn_protect_provider_review()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  if auth.uid() = old.user_id and (
    new.status is distinct from old.status or
    new.is_verified is distinct from old.is_verified or
    new.reviewed_at is distinct from old.reviewed_at
  ) then
    raise exception 'Provider review fields can only be changed by an administrator.';
  end if;
  return new;
end;
$$;

drop trigger if exists findrn_provider_review_guard on public.provider_profiles;
create trigger findrn_provider_review_guard
before update on public.provider_profiles
for each row execute function public.findrn_protect_provider_review();

create or replace function public.findrn_create_booking_conversation()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  new_conversation_id uuid;
begin
  insert into public.booking_events (booking_id, actor_id, to_status)
  values (new.id, new.customer_id, new.status);

  insert into public.conversations (booking_id)
  values (new.id)
  returning id into new_conversation_id;

  insert into public.conversation_members (conversation_id, user_id)
  values (new_conversation_id, new.customer_id), (new_conversation_id, new.provider_id);

  return new;
end;
$$;

drop trigger if exists findrn_booking_created on public.bookings;
create trigger findrn_booking_created
after insert on public.bookings
for each row execute function public.findrn_create_booking_conversation();

create or replace function public.findrn_respond_to_booking(
  p_booking_id uuid,
  p_decision public.booking_status,
  p_note text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  current_booking public.bookings;
begin
  if p_decision not in ('accepted', 'declined') then
    raise exception 'Decision must be accepted or declined.';
  end if;

  select * into current_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found or current_booking.provider_id <> auth.uid() then
    raise exception 'Booking not found or access denied.';
  end if;

  if current_booking.status <> 'requested' then
    raise exception 'Only requested bookings can be answered.';
  end if;

  update public.bookings
  set status = p_decision, updated_at = now()
  where id = p_booking_id
  returning * into current_booking;

  insert into public.booking_events (booking_id, actor_id, from_status, to_status, note)
  values (p_booking_id, auth.uid(), 'requested', p_decision, left(p_note, 1000));

  return current_booking;
end;
$$;

create or replace function public.findrn_cancel_booking(
  p_booking_id uuid,
  p_note text default null
)
returns public.bookings
language plpgsql
security definer
set search_path = public
as $$
declare
  current_booking public.bookings;
  old_status public.booking_status;
begin
  select * into current_booking
  from public.bookings
  where id = p_booking_id
  for update;

  if not found or (current_booking.customer_id <> auth.uid() and current_booking.provider_id <> auth.uid() and not public.findrn_is_admin()) then
    raise exception 'Booking not found or access denied.';
  end if;

  if current_booking.status not in ('requested', 'accepted') then
    raise exception 'This booking can no longer be cancelled.';
  end if;

  old_status := current_booking.status;
  update public.bookings
  set status = 'cancelled', updated_at = now()
  where id = p_booking_id
  returning * into current_booking;

  insert into public.booking_events (booking_id, actor_id, from_status, to_status, note)
  values (p_booking_id, auth.uid(), old_status, 'cancelled', left(p_note, 1000));

  return current_booking;
end;
$$;

-- Public category catalogue; personal and transactional data remains protected.
insert into public.categories (name, slug, icon, sort_order)
values
  ('Home services', 'home-services', 'home', 1),
  ('Cleaning', 'cleaning', 'sparkles', 2),
  ('Repairs & maintenance', 'repairs-maintenance', 'wrench', 3),
  ('Moving & delivery', 'moving-delivery', 'truck', 4),
  ('Beauty & wellness', 'beauty-wellness', 'heart', 5),
  ('Lessons & skills', 'lessons-skills', 'graduation-cap', 6),
  ('Events & occasions', 'events-occasions', 'calendar', 7),
  ('Tech support', 'tech-support', 'laptop', 8),
  ('Automotive', 'automotive', 'car', 9),
  ('Pet care', 'pet-care', 'paw-print', 10),
  ('Personal assistance', 'personal-assistance', 'hand-helping', 11),
  ('Other services', 'other-services', 'plus', 12)
on conflict (slug) do nothing;

-- Updated-at triggers.
drop trigger if exists findrn_profiles_updated_at on public.profiles;
create trigger findrn_profiles_updated_at before update on public.profiles
for each row execute function public.findrn_set_updated_at();
drop trigger if exists findrn_provider_profiles_updated_at on public.provider_profiles;
create trigger findrn_provider_profiles_updated_at before update on public.provider_profiles
for each row execute function public.findrn_set_updated_at();
drop trigger if exists findrn_services_updated_at on public.services;
create trigger findrn_services_updated_at before update on public.services
for each row execute function public.findrn_set_updated_at();
drop trigger if exists findrn_bookings_updated_at on public.bookings;
create trigger findrn_bookings_updated_at before update on public.bookings
for each row execute function public.findrn_set_updated_at();
drop trigger if exists findrn_payments_updated_at on public.payment_records;
create trigger findrn_payments_updated_at before update on public.payment_records
for each row execute function public.findrn_set_updated_at();

-- Enable RLS everywhere.
alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.provider_profiles enable row level security;
alter table public.provider_private_details enable row level security;
alter table public.services enable row level security;
alter table public.bookings enable row level security;
alter table public.booking_events enable row level security;
alter table public.conversations enable row level security;
alter table public.conversation_members enable row level security;
alter table public.messages enable row level security;
alter table public.reviews enable row level security;
alter table public.payment_records enable row level security;
alter table public.notifications enable row level security;

-- Profiles.
drop policy if exists "Profiles readable by owner or admin" on public.profiles;
create policy "Profiles readable by owner or admin" on public.profiles
for select to authenticated using (id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Profiles editable by owner or admin" on public.profiles;
create policy "Profiles editable by owner or admin" on public.profiles
for update to authenticated using (id = auth.uid() or public.findrn_is_admin())
with check (id = auth.uid() or public.findrn_is_admin());

-- Categories.
drop policy if exists "Active categories are public" on public.categories;
create policy "Active categories are public" on public.categories
for select to anon, authenticated using (is_active or public.findrn_is_admin());
drop policy if exists "Admins manage categories" on public.categories;
create policy "Admins manage categories" on public.categories
for all to authenticated using (public.findrn_is_admin()) with check (public.findrn_is_admin());

-- Provider profiles.
drop policy if exists "Approved providers are public" on public.provider_profiles;
create policy "Approved providers are public" on public.provider_profiles
for select to anon, authenticated using (status = 'approved' or user_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Users submit own provider profile" on public.provider_profiles;
create policy "Users submit own provider profile" on public.provider_profiles
for insert to authenticated with check (user_id = auth.uid() and status = 'pending' and is_verified = false);
drop policy if exists "Owners edit own provider profile" on public.provider_profiles;
create policy "Owners edit own provider profile" on public.provider_profiles
for update to authenticated using (user_id = auth.uid() or public.findrn_is_admin())
with check (user_id = auth.uid() or public.findrn_is_admin());

-- Private provider contact details: only the provider and admins can read/update.
drop policy if exists "Provider private details owner/admin read" on public.provider_private_details;
create policy "Provider private details owner/admin read" on public.provider_private_details
for select to authenticated using (user_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Provider private details owner/admin insert" on public.provider_private_details;
create policy "Provider private details owner/admin insert" on public.provider_private_details
for insert to authenticated with check (user_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Provider private details owner/admin update" on public.provider_private_details;
create policy "Provider private details owner/admin update" on public.provider_private_details
for update to authenticated using (user_id = auth.uid() or public.findrn_is_admin())
with check (user_id = auth.uid() or public.findrn_is_admin());

-- Services.
drop policy if exists "Published services are public" on public.services;
create policy "Published services are public" on public.services
for select to anon, authenticated using (
  (status = 'published' and exists (
    select 1 from public.provider_profiles p
    where p.user_id = provider_id and p.status = 'approved'
  ))
  or provider_id = auth.uid()
  or public.findrn_is_admin()
);
drop policy if exists "Approved providers create services" on public.services;
create policy "Approved providers create services" on public.services
for insert to authenticated with check (
  provider_id = auth.uid()
  and exists (select 1 from public.provider_profiles p where p.user_id = auth.uid() and p.status = 'approved')
);
drop policy if exists "Providers update own services" on public.services;
create policy "Providers update own services" on public.services
for update to authenticated using (provider_id = auth.uid() or public.findrn_is_admin())
with check (provider_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Providers delete own draft services" on public.services;
create policy "Providers delete own draft services" on public.services
for delete to authenticated using ((provider_id = auth.uid() and status = 'draft') or public.findrn_is_admin());

-- Bookings. State changes go through the guarded RPC functions above.
drop policy if exists "Booking participants read bookings" on public.bookings;
create policy "Booking participants read bookings" on public.bookings
for select to authenticated using (customer_id = auth.uid() or provider_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Customers request published services" on public.bookings;
create policy "Customers request published services" on public.bookings
for insert to authenticated with check (
  customer_id = auth.uid()
  and provider_id <> auth.uid()
  and exists (
    select 1 from public.services s
    join public.provider_profiles p on p.user_id = s.provider_id
    where s.id = service_id and s.provider_id = provider_id
      and s.status = 'published' and p.status = 'approved'
  )
);

-- Booking event history is append-only for participants; admins can inspect it.
drop policy if exists "Participants read booking events" on public.booking_events;
create policy "Participants read booking events" on public.booking_events
for select to authenticated using (
  exists (select 1 from public.bookings b where b.id = booking_id and (b.customer_id = auth.uid() or b.provider_id = auth.uid()))
  or public.findrn_is_admin()
);

-- Conversation access.
drop policy if exists "Members read conversations" on public.conversations;
create policy "Members read conversations" on public.conversations
for select to authenticated using (
  exists (select 1 from public.conversation_members m where m.conversation_id = id and m.user_id = auth.uid())
  or public.findrn_is_admin()
);
drop policy if exists "Members read conversation membership" on public.conversation_members;
create policy "Members read conversation membership" on public.conversation_members
for select to authenticated using (user_id = auth.uid() or public.findrn_is_admin());
drop policy if exists "Members read messages" on public.messages;
create policy "Members read messages" on public.messages
for select to authenticated using (
  exists (select 1 from public.conversation_members m where m.conversation_id = conversation_id and m.user_id = auth.uid())
  or public.findrn_is_admin()
);
drop policy if exists "Members send messages as themselves" on public.messages;
create policy "Members send messages as themselves" on public.messages
for insert to authenticated with check (
  sender_id = auth.uid()
  and exists (select 1 from public.conversation_members m where m.conversation_id = conversation_id and m.user_id = auth.uid())
);

-- Reviews: customers can review only their completed bookings, once.
drop policy if exists "Reviews are public" on public.reviews;
create policy "Reviews are public" on public.reviews
for select to anon, authenticated using (true);
drop policy if exists "Customers review completed bookings" on public.reviews;
create policy "Customers review completed bookings" on public.reviews
for insert to authenticated with check (
  customer_id = auth.uid()
  and exists (
    select 1 from public.bookings b
    where b.id = booking_id and b.customer_id = auth.uid()
      and b.provider_id = provider_id and b.status = 'completed'
  )
);

-- Payment state is written only by trusted server/webhook code (service role).
drop policy if exists "Payment participants read payment records" on public.payment_records;
create policy "Payment participants read payment records" on public.payment_records
for select to authenticated using (customer_id = auth.uid() or provider_id = auth.uid() or public.findrn_is_admin());

-- Notifications are private to their recipient.
drop policy if exists "Users read own notifications" on public.notifications;
create policy "Users read own notifications" on public.notifications
for select to authenticated using (user_id = auth.uid() or public.findrn_is_admin());

-- Explicit API privileges; RLS still decides which rows are visible or writable.
grant usage on schema public to anon, authenticated;
grant select on public.categories, public.provider_profiles, public.services, public.reviews to anon, authenticated;
grant select, update on public.profiles to authenticated;
grant select, insert, update on public.provider_profiles to authenticated;
grant select, insert, update on public.provider_private_details to authenticated;
grant select, insert, update, delete on public.services to authenticated;
grant select, insert on public.bookings to authenticated;
grant select on public.booking_events, public.conversations, public.conversation_members to authenticated;
grant select, insert on public.messages to authenticated;
grant select, insert on public.reviews to authenticated;
grant select on public.payment_records, public.notifications to authenticated;
grant execute on function public.findrn_respond_to_booking(uuid, public.booking_status, text) to authenticated;
grant execute on function public.findrn_cancel_booking(uuid, text) to authenticated;

commit;
