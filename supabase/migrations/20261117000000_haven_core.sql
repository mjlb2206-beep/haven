-- Haven core schema (Milestone 1: functional multi-tenant core)
-- Target: Supabase (Postgres 15+). Every client row carries organization_id and is
-- protected by row-level security. Guests never get table access: they go through
-- SECURITY DEFINER functions that check a short-lived stay session.

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------- enums
create type public.member_role        as enum ('owner', 'manager', 'caretaker');
create type public.reservation_status as enum ('upcoming', 'arriving', 'in_house', 'checked_out', 'cancelled');
create type public.issue_category     as enum ('maintenance', 'cleanliness', 'wifi', 'parking', 'access', 'amenities', 'noise', 'other');
create type public.issue_status       as enum ('new', 'in_progress', 'resolved');
create type public.booking_channel    as enum ('direct', 'airbnb', 'vrbo', 'booking', 'other');

-- ---------------------------------------------------------------- tenants
create table public.organizations (
  id          uuid primary key default gen_random_uuid(),
  name        text not null,
  slug        text not null unique check (slug ~ '^[a-z0-9-]{2,60}$'),
  plan        text not null default 'starter',
  created_at  timestamptz not null default now()
);

create table public.organization_members (
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id         uuid not null references auth.users(id) on delete cascade,
  role            public.member_role not null default 'manager',
  created_at      timestamptz not null default now(),
  primary key (organization_id, user_id)
);

create table public.brand_settings (
  organization_id  uuid primary key references public.organizations(id) on delete cascade,
  business_name    text not null,
  tagline          text,
  logo_url         text,
  primary_color    text not null default '#1E5B6E' check (primary_color ~ '^#[0-9A-Fa-f]{6}$'),
  accent_color     text not null default '#F2B880' check (accent_color  ~ '^#[0-9A-Fa-f]{6}$'),
  phone            text,
  whatsapp         text,
  email            text,
  instagram        text,
  website          text,
  caretaker_name   text,
  caretaker_phone  text,
  default_language text not null default 'en' check (default_language in ('en', 'es')),
  show_powered_by  boolean not null default true,
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------- properties
create table public.properties (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  name             text not null,
  slug             text not null,
  area             text,
  address          text,
  layout           text,
  layout_es        text,
  description      text,
  description_es   text,
  photo_url        text,
  wifi_name        text,
  wifi_password    text,
  parking          text,
  parking_es       text,
  check_in_time    time not null default '15:00',
  check_out_time   time not null default '11:00',
  created_at       timestamptz not null default now(),
  unique (organization_id, slug)
);

-- Sensitive access info lives apart from the property row, so a broad
-- "select properties" can never leak it. Guests reach it only via get_stay_access().
create table public.property_access (
  property_id      uuid primary key references public.properties(id) on delete cascade,
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  door_code        text,
  access_notes     text,
  access_notes_es  text,
  updated_at       timestamptz not null default now()
);

-- ---------------------------------------------------------------- guests & reservations
create table public.guests (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  first_name       text not null,
  last_name        text not null,
  phone            text not null,
  phone_digits     text generated always as (regexp_replace(phone, '\D', '', 'g')) stored,
  email            text,
  country          text,
  language         text not null default 'en' check (language in ('en', 'es', 'ru', 'pt', 'fr')),
  created_at       timestamptz not null default now()
);
create index guests_lookup_idx on public.guests (organization_id, lower(last_name));

create table public.reservations (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  property_id      uuid not null references public.properties(id) on delete restrict,
  guest_id         uuid not null references public.guests(id) on delete restrict,
  booking_ref      text not null,
  check_in         date not null,
  check_out        date not null,
  adults           smallint not null default 1 check (adults between 1 and 30),
  children         smallint not null default 0 check (children between 0 and 30),
  status           public.reservation_status not null default 'upcoming',
  channel          public.booking_channel not null default 'direct',
  external_id      text,               -- id in the source channel, for future integrations
  total_cents      integer check (total_cents >= 0),
  currency         text not null default 'USD',
  host_notes       text,
  created_at       timestamptz not null default now(),
  check (check_out > check_in),
  unique (organization_id, booking_ref)
);
create index reservations_dates_idx on public.reservations (organization_id, check_in, check_out);

-- ---------------------------------------------------------------- issues
create table public.issue_reports (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  property_id      uuid not null references public.properties(id) on delete cascade,
  reservation_id   uuid references public.reservations(id) on delete set null,
  category         public.issue_category not null,
  description      text not null check (char_length(description) between 3 and 2000),
  status           public.issue_status not null default 'new',
  source           text not null default 'guest_portal',
  assignee         text,
  created_at       timestamptz not null default now(),
  first_response_at timestamptz,
  resolved_at      timestamptz
);
create index issue_reports_org_idx on public.issue_reports (organization_id, status, created_at desc);

-- ---------------------------------------------------------------- guest sessions
-- Created by lookup_stay(). The token is what the guest portal keeps (URL or storage).
create table public.guest_sessions (
  token            uuid primary key default gen_random_uuid(),
  reservation_id   uuid not null references public.reservations(id) on delete cascade,
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  verified_at      timestamptz,          -- set once the booking reference is confirmed
  expires_at       timestamptz not null,
  created_at       timestamptz not null default now()
);

-- Failed lookups, for basic brute-force throttling.
create table public.lookup_attempts (
  id          bigserial primary key,
  key         text not null,
  created_at  timestamptz not null default now()
);
create index lookup_attempts_key_idx on public.lookup_attempts (key, created_at);

-- ---------------------------------------------------------------- helpers
create or replace function public.is_org_member(org uuid)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from organization_members m where m.organization_id = org and m.user_id = auth.uid());
$$;

create or replace function public.touch_resolution() returns trigger language plpgsql as $$
begin
  if new.status <> 'new' and new.first_response_at is null then new.first_response_at := now(); end if;
  if new.status = 'resolved' and new.resolved_at is null then new.resolved_at := now(); end if;
  if new.status <> 'resolved' then new.resolved_at := null; end if;
  return new;
end $$;
create trigger issue_reports_resolution before update on public.issue_reports
  for each row execute function public.touch_resolution();

-- ---------------------------------------------------------------- row-level security
alter table public.organizations        enable row level security;
alter table public.organization_members enable row level security;
alter table public.brand_settings       enable row level security;
alter table public.properties           enable row level security;
alter table public.property_access      enable row level security;
alter table public.guests               enable row level security;
alter table public.reservations         enable row level security;
alter table public.issue_reports        enable row level security;
alter table public.guest_sessions       enable row level security;   -- no policies: functions only
alter table public.lookup_attempts      enable row level security;   -- no policies: functions only

create policy org_read on public.organizations for select using (public.is_org_member(id));
create policy members_read on public.organization_members for select using (public.is_org_member(organization_id));

do $$
declare t text;
begin
  foreach t in array array['brand_settings','properties','property_access','guests','reservations','issue_reports'] loop
    execute format('create policy %1$s_select on public.%1$s for select using (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_insert on public.%1$s for insert with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_update on public.%1$s for update using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_delete on public.%1$s for delete using (public.is_org_member(organization_id))', t);
  end loop;
end $$;

-- A reservation, guest, property and access row must all belong to the same organization.
create or replace function public.check_same_org() returns trigger language plpgsql as $$
begin
  if tg_table_name = 'reservations' then
    if not exists (select 1 from properties p where p.id = new.property_id and p.organization_id = new.organization_id)
       or not exists (select 1 from guests g where g.id = new.guest_id and g.organization_id = new.organization_id) then
      raise exception 'reservation must reference a property and guest of the same organization';
    end if;
  elsif tg_table_name in ('property_access', 'issue_reports') then
    if not exists (select 1 from properties p where p.id = new.property_id and p.organization_id = new.organization_id) then
      raise exception '% must reference a property of the same organization', tg_table_name;
    end if;
  end if;
  return new;
end $$;
create trigger reservations_same_org   before insert or update on public.reservations    for each row execute function public.check_same_org();
create trigger access_same_org         before insert or update on public.property_access for each row execute function public.check_same_org();
create trigger issue_reports_same_org  before insert or update on public.issue_reports   for each row execute function public.check_same_org();

-- ---------------------------------------------------------------- guest-facing functions
-- 1. Find a stay with last name + phone. Returns a session token, never data.
create or replace function public.lookup_stay(p_last_name text, p_phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_digits text := right(regexp_replace(coalesce(p_phone, ''), '\D', '', 'g'), 10);
  v_key    text := lower(trim(coalesce(p_last_name, ''))) || ':' || v_digits;
  v_res    reservations%rowtype;
  v_token  uuid;
begin
  if length(v_digits) < 7 or length(trim(coalesce(p_last_name, ''))) < 2 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  if (select count(*) from lookup_attempts where key = v_key and created_at > now() - interval '15 minutes') >= 5 then
    raise exception 'too_many_attempts' using errcode = '54000';
  end if;

  select r.* into v_res
  from reservations r join guests g on g.id = r.guest_id
  where lower(g.last_name) = lower(trim(p_last_name))
    and right(g.phone_digits, 10) = v_digits
    and r.status <> 'cancelled'
    and r.check_out >= current_date
  order by r.check_in
  limit 1;

  if not found then
    insert into lookup_attempts (key) values (v_key);
    return null;
  end if;

  insert into guest_sessions (reservation_id, organization_id, expires_at)
  values (v_res.id, v_res.organization_id, (v_res.check_out + 1)::timestamptz)
  returning token into v_token;
  return v_token;
end $$;

-- 2. Everything the portal shows, resolved reservation -> property -> organization.
--    No door code here.
create or replace function public.get_stay(p_token uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object(
    'reservation', jsonb_build_object('booking_ref', r.booking_ref, 'check_in', r.check_in, 'check_out', r.check_out,
                                      'adults', r.adults, 'children', r.children, 'status', r.status),
    'guest',       jsonb_build_object('first_name', g.first_name, 'language', g.language),
    'property',    jsonb_build_object('name', p.name, 'area', p.area, 'address', p.address, 'layout', p.layout,
                                      'layout_es', p.layout_es, 'description', p.description, 'description_es', p.description_es,
                                      'photo_url', p.photo_url, 'wifi_name', p.wifi_name, 'wifi_password', p.wifi_password,
                                      'parking', p.parking, 'parking_es', p.parking_es,
                                      'check_in_time', p.check_in_time, 'check_out_time', p.check_out_time),
    'brand',       to_jsonb(b) - 'organization_id' - 'updated_at',
    'verified',    s.verified_at is not null
  )
  from guest_sessions s
  join reservations r on r.id = s.reservation_id
  join guests g       on g.id = r.guest_id
  join properties p   on p.id = r.property_id
  left join brand_settings b on b.organization_id = r.organization_id
  where s.token = p_token and s.expires_at > now();
$$;

-- 3. Second factor before access info: the booking reference from the confirmation.
create or replace function public.verify_stay(p_token uuid, p_booking_ref text)
returns boolean language plpgsql security definer set search_path = public as $$
declare v_ok boolean;
begin
  if (select count(*) from lookup_attempts where key = 'verify:' || p_token::text and created_at > now() - interval '15 minutes') >= 5 then
    raise exception 'too_many_attempts' using errcode = '54000';
  end if;
  select upper(trim(r.booking_ref)) = upper(trim(coalesce(p_booking_ref, ''))) into v_ok
  from guest_sessions s join reservations r on r.id = s.reservation_id
  where s.token = p_token and s.expires_at > now();
  if coalesce(v_ok, false) then
    update guest_sessions set verified_at = now() where token = p_token;
    return true;
  end if;
  insert into lookup_attempts (key) values ('verify:' || p_token::text);
  return false;
end $$;

-- 4. Door code: only for a verified session, and only from check-in day to check-out day.
create or replace function public.get_stay_access(p_token uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('door_code', a.door_code, 'access_notes', a.access_notes, 'access_notes_es', a.access_notes_es)
  from guest_sessions s
  join reservations r on r.id = s.reservation_id
  join property_access a on a.property_id = r.property_id
  where s.token = p_token and s.expires_at > now() and s.verified_at is not null
    and current_date between r.check_in and r.check_out;
$$;

-- 5. Guest reports a problem; it lands in the right organization automatically.
create or replace function public.report_issue(p_token uuid, p_category public.issue_category, p_description text)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_res reservations%rowtype;
begin
  select r.* into v_res from guest_sessions s join reservations r on r.id = s.reservation_id
  where s.token = p_token and s.expires_at > now();
  if not found then raise exception 'invalid_session' using errcode = '28000'; end if;
  insert into issue_reports (organization_id, property_id, reservation_id, category, description)
  values (v_res.organization_id, v_res.property_id, v_res.id, p_category, trim(p_description))
  returning id into v_id;
  return v_id;
end $$;

-- ---------------------------------------------------------------- host convenience views
create or replace view public.issue_metrics with (security_invoker = true) as
select organization_id, property_id, category,
       count(*)                                   as total,
       count(*) filter (where status <> 'resolved') as open,
       avg(extract(epoch from first_response_at - created_at) / 60) filter (where first_response_at is not null) as avg_response_min,
       avg(extract(epoch from resolved_at - created_at) / 3600)     filter (where resolved_at is not null)      as avg_resolution_h,
       date_trunc('month', created_at)            as month
from public.issue_reports
group by organization_id, property_id, category, date_trunc('month', created_at);

-- ---------------------------------------------------------------- grants
revoke all on public.guest_sessions, public.lookup_attempts from anon, authenticated;
revoke execute on function public.lookup_stay(text, text), public.get_stay(uuid), public.verify_stay(uuid, text),
                           public.get_stay_access(uuid), public.report_issue(uuid, public.issue_category, text) from public;
grant  execute on function public.lookup_stay(text, text), public.get_stay(uuid), public.verify_stay(uuid, text),
                           public.get_stay_access(uuid), public.report_issue(uuid, public.issue_category, text) to anon, authenticated;
