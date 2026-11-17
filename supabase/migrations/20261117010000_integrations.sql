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
