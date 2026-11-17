-- Run this once in Supabase > Haven Beta > SQL Editor. It adds the integrations and messaging tables.
-- Safe on the live database: it only creates new things and does not touch existing data.

-- Integration-ready structure (task #ynzhgb, step 5).
-- Nothing here connects to a real channel yet. It gives every future PMS / channel-manager /
-- OTA connection one place to live, plus a normalized mapping from external ids to Haven rows,
-- so imports never create duplicates and the UI can show an honest status per connection.

create type public.integration_provider as enum (
  'manual_import', 'guesty', 'hostaway', 'hospitable', 'lodgify', 'ownerrez',
  'airbnb', 'vrbo', 'booking', 'stripe', 'whatsapp', 'other'
);

-- Honest lifecycle: 'planned' and 'pending_partner_access' are never shown as live.
create type public.integration_status as enum (
  'planned', 'pending_partner_access', 'connecting', 'live', 'error', 'disabled'
);

create table public.integration_accounts (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  provider         public.integration_provider not null,
  status           public.integration_status not null default 'planned',
  display_name     text,
  external_account_id text,                -- the account/listing-group id on the provider side
  -- Never store tokens in this table (members can read it). Secrets live in Supabase Vault;
  -- this holds only the vault secret name, written by a server-side function.
  credentials_ref  text,
  scopes           text[] not null default '{}',
  last_sync_at     timestamptz,
  last_error       text,
  settings         jsonb not null default '{}'::jsonb,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  unique (organization_id, provider, external_account_id)
);

-- One row per external object we have seen, pointing at the Haven row it became.
create type public.external_object_kind as enum ('property', 'reservation', 'guest', 'message', 'thread');

create table public.external_refs (
  id                 uuid primary key default gen_random_uuid(),
  organization_id    uuid not null references public.organizations (id) on delete cascade,
  integration_id     uuid not null references public.integration_accounts (id) on delete cascade,
  kind               public.external_object_kind not null,
  external_id        text not null,
  haven_id           uuid not null,          -- id in properties / reservations / guests / messages
  external_updated_at timestamptz,           -- for idempotent re-syncs (skip if not newer)
  raw                jsonb,                  -- last payload, for debugging mappings
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now(),
  unique (integration_id, kind, external_id)
);
create index external_refs_haven_idx on public.external_refs (organization_id, kind, haven_id);

-- Sync log so hosts (and we) can see what an import did.
create table public.sync_runs (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  integration_id   uuid not null references public.integration_accounts (id) on delete cascade,
  started_at       timestamptz not null default now(),
  finished_at      timestamptz,
  ok               boolean,
  created_count    int not null default 0,
  updated_count    int not null default 0,
  skipped_count    int not null default 0,
  error            text
);

-- Same tenant isolation as every other table.
alter table public.integration_accounts enable row level security;
alter table public.external_refs        enable row level security;
alter table public.sync_runs            enable row level security;

do $$
declare t text;
begin
  foreach t in array array['integration_accounts', 'external_refs', 'sync_runs'] loop
    execute format('create policy %1$s_select on public.%1$s for select using (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_insert on public.%1$s for insert with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_update on public.%1$s for update using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_delete on public.%1$s for delete using (public.is_org_member(organization_id))', t);
  end loop;
end $$;

-- Hosts may not mark a connection 'live' themselves; only server-side code (service role,
-- which bypasses RLS) does that after a real successful sync.
create or replace function public.integration_status_guard()
returns trigger language plpgsql as $$
begin
  if new.status = 'live' and (tg_op = 'INSERT' or old.status is distinct from 'live')
     and coalesce(auth.role(), '') <> 'service_role' then
    raise exception 'Only a verified sync can mark an integration live';
  end if;
  new.updated_at := now();
  return new;
end $$;

create trigger integration_status_guard
  before insert or update on public.integration_accounts
  for each row execute function public.integration_status_guard();

-- Native messaging foundation (task #fh5n2f).
-- One thread per reservation; messages from the guest (via session token), the host
-- (signed-in org member) or the system. `channel` is 'haven' today; external channels
-- (WhatsApp, SMS, OTA inboxes) land in the same tables later through external_refs.

create type public.message_sender  as enum ('guest', 'host', 'system');
create type public.message_channel as enum ('haven', 'whatsapp', 'sms', 'email', 'airbnb', 'vrbo', 'booking');

create table public.message_threads (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  reservation_id   uuid not null unique references public.reservations(id) on delete cascade,
  last_message_at  timestamptz,
  host_unread      int not null default 0,
  guest_unread     int not null default 0,
  created_at       timestamptz not null default now()
);

create table public.messages (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations(id) on delete cascade,
  thread_id        uuid not null references public.message_threads(id) on delete cascade,
  sender           public.message_sender not null,
  sender_user_id   uuid references auth.users(id),
  channel          public.message_channel not null default 'haven',
  body             text not null check (length(trim(body)) between 1 and 4000),
  language         text,                 -- 'en' / 'es', for the translate toggle
  created_at       timestamptz not null default now()
);
create index messages_thread_idx on public.messages (thread_id, created_at);
create index message_threads_org_idx on public.message_threads (organization_id, last_message_at desc);

alter table public.message_threads enable row level security;
alter table public.messages        enable row level security;

-- Hosts: read their org's threads and messages, write host messages as themselves.
create policy message_threads_select on public.message_threads for select using (public.is_org_member(organization_id));
create policy message_threads_update on public.message_threads for update using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id));
create policy messages_select on public.messages for select using (public.is_org_member(organization_id));
create policy messages_insert on public.messages for insert
  with check (public.is_org_member(organization_id) and sender = 'host' and sender_user_id = auth.uid() and channel = 'haven');

-- Keep thread counters in step with new messages.
create or replace function public.messages_after_insert()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  update message_threads set
    last_message_at = new.created_at,
    host_unread  = host_unread  + (case when new.sender = 'guest' then 1 else 0 end),
    guest_unread = guest_unread + (case when new.sender <> 'guest' then 1 else 0 end)
  where id = new.thread_id;
  return new;
end $$;
create trigger messages_after_insert after insert on public.messages
  for each row execute function public.messages_after_insert();

-- Host opens a reservation's thread (created on first use) and marks it read.
create or replace function public.host_open_thread(p_reservation uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_id uuid;
begin
  select organization_id into v_org from reservations where id = p_reservation;
  if v_org is null or not is_org_member(v_org) then raise exception 'not_allowed' using errcode = '42501'; end if;
  insert into message_threads (organization_id, reservation_id) values (v_org, p_reservation)
    on conflict (reservation_id) do update set host_unread = 0 returning id into v_id;
  return v_id;
end $$;

-- Guest side: everything goes through the session token, like the other guest RPCs.
create or replace function public.guest_send_message(p_token uuid, p_body text, p_language text default null)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_res reservations%rowtype; v_thread uuid; v_id uuid;
begin
  select r.* into v_res from guest_sessions s join reservations r on r.id = s.reservation_id
  where s.token = p_token and s.expires_at > now();
  if not found then raise exception 'invalid_session' using errcode = '28000'; end if;
  -- simple flood guard: 20 guest messages per 10 minutes per stay
  if (select count(*) from messages m join message_threads t on t.id = m.thread_id
      where t.reservation_id = v_res.id and m.sender = 'guest' and m.created_at > now() - interval '10 minutes') >= 20 then
    raise exception 'too_many_messages' using errcode = '54000';
  end if;
  insert into message_threads (organization_id, reservation_id) values (v_res.organization_id, v_res.id)
    on conflict (reservation_id) do update set reservation_id = excluded.reservation_id returning id into v_thread;
  insert into messages (organization_id, thread_id, sender, body, language)
  values (v_res.organization_id, v_thread, 'guest', trim(p_body), p_language) returning id into v_id;
  return v_id;
end $$;

create or replace function public.guest_get_messages(p_token uuid)
returns table (id uuid, sender public.message_sender, body text, language text, created_at timestamptz)
language plpgsql security definer set search_path = public as $$
declare v_res uuid;
begin
  select s.reservation_id into v_res from guest_sessions s where s.token = p_token and s.expires_at > now();
  if v_res is null then raise exception 'invalid_session' using errcode = '28000'; end if;
  update message_threads t set guest_unread = 0 where t.reservation_id = v_res;
  return query
    select m.id, m.sender, m.body, m.language, m.created_at
    from messages m join message_threads t on t.id = m.thread_id
    where t.reservation_id = v_res order by m.created_at;
end $$;

revoke all on function public.host_open_thread(uuid) from public;
grant execute on function public.host_open_thread(uuid) to authenticated;
grant execute on function public.guest_send_message(uuid, text, text) to anon, authenticated;
grant execute on function public.guest_get_messages(uuid) to anon, authenticated;
grant select, update on public.message_threads to authenticated;
grant select, insert on public.messages to authenticated;

-- Live updates for the host inbox.
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.messages, public.message_threads;
  end if;
end $$;
