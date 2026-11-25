-- Haven content + operations tables (Nov 24).
-- Replaces the mockup data on the guest pages (Property Guide, Amenities, Local Guide, Checkout,
-- emergency info, check-in timeline) and adds owners, team invites, notifications and self-serve sign-up.
--
-- Content rows have an optional property_id:  NULL = applies to every property of the company,
-- a property id = only that property. Guests read everything through get_stay_content(token).

-- ------------------------------------------------------------------ helpers
-- Any row that names a property must belong to the same company as that property.
create or replace function public.check_property_org() returns trigger language plpgsql as $$
begin
  if new.property_id is not null and not exists (
       select 1 from properties p where p.id = new.property_id and p.organization_id = new.organization_id) then
    raise exception '% must reference a property of the same organization', tg_table_name;
  end if;
  return new;
end $$;

-- ------------------------------------------------------------------ property guide
create table public.guide_sections (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id     uuid references public.properties(id) on delete cascade,
  category        text not null default 'other'
                  check (category in ('arrival','wifi','tv','kitchen','appliances','house_rules','trash','parking','pool','other')),
  title           text not null,
  title_es        text,
  body            text not null default '',
  body_es         text,
  icon            text,
  sort_order      int not null default 0,
  is_published    boolean not null default true,
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------------ amenities
create table public.amenities (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id     uuid references public.properties(id) on delete cascade,
  name            text not null,
  name_es         text,
  description     text,
  description_es  text,
  icon            text,
  hours           text,
  location        text,
  sort_order      int not null default 0,
  is_published    boolean not null default true,
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------------ local guide
create table public.local_places (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id     uuid references public.properties(id) on delete cascade,
  category        text not null default 'explore'
                  check (category in ('eat','coffee','nightlife','explore','essentials','beach','shopping')),
  name            text not null,
  description     text,
  description_es  text,
  address         text,
  maps_url        text,
  phone           text,
  website         text,
  price_level     smallint check (price_level between 1 and 4),
  distance_note   text,
  hours           text,
  photo_url       text,
  featured        boolean not null default false,
  sort_order      int not null default 0,
  is_published    boolean not null default true,
  updated_at      timestamptz not null default now()
);

-- ------------------------------------------------------------------ checkout
create table public.checkout_steps (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id     uuid references public.properties(id) on delete cascade,
  text            text not null,
  text_es         text,
  sort_order      int not null default 0
);
alter table public.properties
  add column if not exists luggage_note        text,
  add column if not exists luggage_note_es     text,
  add column if not exists late_checkout_note  text,
  add column if not exists late_checkout_note_es text;

-- ------------------------------------------------------------------ emergency info
create table public.emergency_contacts (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  property_id     uuid references public.properties(id) on delete cascade,
  label           text not null,
  label_es        text,
  value           text not null,
  kind            text not null default 'phone' check (kind in ('phone','address','other')),
  sort_order      int not null default 0
);

-- ------------------------------------------------------------------ owners (for owner reports later)
create table public.owners (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  name            text not null,
  email           text,
  phone           text,
  notes           text,
  created_at      timestamptz not null default now()
);
alter table public.properties add column if not exists owner_id uuid references public.owners(id) on delete set null;

-- ------------------------------------------------------------------ check-in timeline on reservations
alter table public.reservations
  add column if not exists id_verified_at  timestamptz,
  add column if not exists code_sent_at    timestamptz,
  add column if not exists checked_in_at   timestamptz,
  add column if not exists checked_out_at  timestamptz;

-- ------------------------------------------------------------------ RLS: company members manage their own rows
alter table public.guide_sections     enable row level security;
alter table public.amenities          enable row level security;
alter table public.local_places       enable row level security;
alter table public.checkout_steps     enable row level security;
alter table public.emergency_contacts enable row level security;
alter table public.owners             enable row level security;

do $$
declare t text;
begin
  foreach t in array array['guide_sections','amenities','local_places','checkout_steps','emergency_contacts','owners'] loop
    execute format('create policy %1$s_select on public.%1$s for select using (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_insert on public.%1$s for insert with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_update on public.%1$s for update using (public.is_org_member(organization_id)) with check (public.is_org_member(organization_id))', t);
    execute format('create policy %1$s_delete on public.%1$s for delete using (public.is_org_member(organization_id))', t);
    execute format('grant select, insert, update, delete on public.%1$s to authenticated', t);
  end loop;
  foreach t in array array['guide_sections','amenities','local_places','checkout_steps','emergency_contacts'] loop
    execute format('create trigger %1$s_same_org before insert or update on public.%1$s for each row execute function public.check_property_org()', t);
  end loop;
end $$;
create index guide_sections_org_idx     on public.guide_sections     (organization_id, property_id, sort_order);
create index amenities_org_idx          on public.amenities          (organization_id, property_id, sort_order);
create index local_places_org_idx       on public.local_places       (organization_id, category, sort_order);
create index checkout_steps_org_idx     on public.checkout_steps     (organization_id, property_id, sort_order);
create index emergency_contacts_org_idx on public.emergency_contacts (organization_id, property_id, sort_order);

-- ------------------------------------------------------------------ guest read: everything for one stay
-- Same token rules as get_stay. Company-wide rows + rows for the guest's property, published only.
create or replace function public.get_stay_content(p_token uuid)
returns jsonb language plpgsql stable security definer set search_path = public as $$
declare v_res reservations%rowtype; v_prop properties%rowtype;
begin
  select r.* into v_res from guest_sessions s join reservations r on r.id = s.reservation_id
  where s.token = p_token and s.expires_at > now();
  if not found then return null; end if;
  select * into v_prop from properties where id = v_res.property_id;
  return jsonb_build_object(
    'guide', coalesce((select jsonb_agg(to_jsonb(g) - 'organization_id' - 'property_id' - 'is_published' - 'updated_at' order by g.sort_order, g.title)
                       from guide_sections g where g.organization_id = v_res.organization_id and g.is_published
                         and (g.property_id is null or g.property_id = v_res.property_id)), '[]'::jsonb),
    'amenities', coalesce((select jsonb_agg(to_jsonb(a) - 'organization_id' - 'property_id' - 'is_published' - 'updated_at' order by a.sort_order, a.name)
                       from amenities a where a.organization_id = v_res.organization_id and a.is_published
                         and (a.property_id is null or a.property_id = v_res.property_id)), '[]'::jsonb),
    'places', coalesce((select jsonb_agg(to_jsonb(l) - 'organization_id' - 'property_id' - 'is_published' - 'updated_at' order by l.featured desc, l.sort_order, l.name)
                       from local_places l where l.organization_id = v_res.organization_id and l.is_published
                         and (l.property_id is null or l.property_id = v_res.property_id)), '[]'::jsonb),
    'checkout', jsonb_build_object(
        'steps', coalesce((select jsonb_agg(jsonb_build_object('text', c.text, 'text_es', c.text_es) order by c.sort_order)
                           from checkout_steps c where c.organization_id = v_res.organization_id
                             and (c.property_id is null or c.property_id = v_res.property_id)), '[]'::jsonb),
        'luggage_note', v_prop.luggage_note, 'luggage_note_es', v_prop.luggage_note_es,
        'late_checkout_note', v_prop.late_checkout_note, 'late_checkout_note_es', v_prop.late_checkout_note_es),
    'emergency', coalesce((select jsonb_agg(jsonb_build_object('label', e.label, 'label_es', e.label_es, 'value', e.value, 'kind', e.kind) order by e.sort_order)
                       from emergency_contacts e where e.organization_id = v_res.organization_id
                         and (e.property_id is null or e.property_id = v_res.property_id)), '[]'::jsonb),
    'timeline', jsonb_build_object('booked_at', v_res.created_at, 'id_verified_at', v_res.id_verified_at,
        'code_sent_at', v_res.code_sent_at, 'checked_in_at', v_res.checked_in_at, 'checked_out_at', v_res.checked_out_at),
    'requests', coalesce((select jsonb_agg(jsonb_build_object('id', i.id, 'category', i.category, 'description', i.description,
                            'status', i.status, 'created_at', i.created_at, 'resolved_at', i.resolved_at) order by i.created_at desc)
                          from issue_reports i where i.reservation_id = v_res.id), '[]'::jsonb)
  );
end $$;
grant execute on function public.get_stay_content(uuid) to anon, authenticated;

-- ------------------------------------------------------------------ notifications (top-bar bell)
create table public.notifications (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  user_id         uuid references auth.users(id) on delete cascade,   -- NULL = everyone in the company
  kind            text not null,                                     -- message | request | arrival | system
  title           text not null,
  body            text,
  link            text,
  read_at         timestamptz,
  created_at      timestamptz not null default now()
);
create index notifications_org_idx on public.notifications (organization_id, created_at desc);
alter table public.notifications enable row level security;
create policy notifications_select on public.notifications for select
  using (public.is_org_member(organization_id) and (user_id is null or user_id = auth.uid()));
create policy notifications_update on public.notifications for update
  using (public.is_org_member(organization_id) and (user_id is null or user_id = auth.uid()))
  with check (public.is_org_member(organization_id));
grant select, update on public.notifications to authenticated;

create or replace function public.notify_new_guest_message() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_name text;
begin
  if new.sender <> 'guest' then return new; end if;
  select g.first_name || ' ' || g.last_name into v_name
  from message_threads t join reservations r on r.id = t.reservation_id join guests g on g.id = r.guest_id
  where t.id = new.thread_id;
  insert into notifications (organization_id, kind, title, body, link)
  values (new.organization_id, 'message', 'New message from ' || coalesce(v_name, 'a guest'), left(new.body, 140), '/host/messages');
  return new;
end $$;
create trigger messages_notify after insert on public.messages
  for each row execute function public.notify_new_guest_message();

create or replace function public.notify_new_request() returns trigger
language plpgsql security definer set search_path = public as $$
declare v_prop text;
begin
  select name into v_prop from properties where id = new.property_id;
  insert into notifications (organization_id, kind, title, body, link)
  values (new.organization_id, 'request', 'New request · ' || coalesce(v_prop, ''), left(new.description, 140), '/host/requests');
  return new;
end $$;
create trigger issue_reports_notify after insert on public.issue_reports
  for each row execute function public.notify_new_request();

-- ------------------------------------------------------------------ team invitations
create table public.team_invitations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations(id) on delete cascade,
  email           text not null check (email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  role            public.member_role not null default 'manager',
  token           uuid not null unique default gen_random_uuid(),
  invited_by      uuid references auth.users(id) default auth.uid(),
  created_at      timestamptz not null default now(),
  expires_at      timestamptz not null default now() + interval '7 days',
  accepted_at     timestamptz
);
alter table public.team_invitations enable row level security;
create policy team_invitations_select on public.team_invitations for select using (public.is_org_member(organization_id));
create policy team_invitations_insert on public.team_invitations for insert with check (public.is_org_member(organization_id));
create policy team_invitations_delete on public.team_invitations for delete using (public.is_org_member(organization_id));
grant select, insert, delete on public.team_invitations to authenticated;

-- The invited person signs in (same email as the invite) and calls this with the token from their link.
create or replace function public.accept_invitation(p_token uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare v_inv team_invitations%rowtype; v_email text;
begin
  select email into v_email from auth.users where id = auth.uid();
  if v_email is null then raise exception 'not_signed_in' using errcode = '28000'; end if;
  select * into v_inv from team_invitations where token = p_token and accepted_at is null and expires_at > now();
  if not found then raise exception 'invalid_invitation' using errcode = '22023'; end if;
  if lower(v_inv.email) <> lower(v_email) then raise exception 'wrong_account' using errcode = '42501'; end if;
  insert into organization_members (organization_id, user_id, role) values (v_inv.organization_id, auth.uid(), v_inv.role)
    on conflict do nothing;
  update team_invitations set accepted_at = now() where id = v_inv.id;
  return v_inv.organization_id;
end $$;
revoke all on function public.accept_invitation(uuid) from public;
grant execute on function public.accept_invitation(uuid) to authenticated;

-- ------------------------------------------------------------------ self-serve sign-up
-- A signed-in user with no company creates one; they become its owner. One free company per account.
create or replace function public.create_organization(p_name text, p_language text default 'en')
returns uuid language plpgsql security definer set search_path = public as $$
declare v_id uuid; v_slug text; v_base text; n int := 1;
begin
  if auth.uid() is null then raise exception 'not_signed_in' using errcode = '28000'; end if;
  if length(trim(coalesce(p_name, ''))) < 2 then raise exception 'invalid_name' using errcode = '22023'; end if;
  if exists (select 1 from organization_members where user_id = auth.uid()) then
    raise exception 'already_has_company' using errcode = '23505';
  end if;
  v_base := trim(both '-' from regexp_replace(lower(trim(p_name)), '[^a-z0-9]+', '-', 'g'));
  if length(v_base) < 2 then v_base := 'host'; end if;
  v_base := left(v_base, 50); v_slug := v_base;
  while exists (select 1 from organizations where slug = v_slug) loop n := n + 1; v_slug := v_base || '-' || n; end loop;
  insert into organizations (name, slug, plan) values (trim(p_name), v_slug, 'starter') returning id into v_id;
  insert into organization_members (organization_id, user_id, role) values (v_id, auth.uid(), 'owner');
  insert into brand_settings (organization_id, business_name, default_language)
    values (v_id, trim(p_name), case when p_language = 'es' then 'es' else 'en' end);
  return v_id;
end $$;
revoke all on function public.create_organization(text, text) from public;
grant execute on function public.create_organization(text, text) to authenticated;

-- ------------------------------------------------------------------ live updates for the bell
do $$ begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    alter publication supabase_realtime add table public.notifications;
  end if;
end $$;

-- ------------------------------------------------------------------ team list (emails live in auth.users, which hosts can't read)
create or replace function public.get_team()
returns table (user_id uuid, email text, role public.member_role, joined_at timestamptz, is_me boolean)
language sql stable security definer set search_path = public as $$
  select m.user_id, u.email::text, m.role, m.created_at, m.user_id = auth.uid()
  from organization_members m join auth.users u on u.id = m.user_id
  where m.organization_id in (select organization_id from organization_members where user_id = auth.uid())
  order by m.created_at;
$$;
revoke all on function public.get_team() from public;
grant execute on function public.get_team() to authenticated;

-- Owners can remove teammates (never themselves).
create or replace function public.remove_member(p_user uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid;
begin
  select organization_id into v_org from organization_members where user_id = auth.uid() and role = 'owner' limit 1;
  if v_org is null then raise exception 'only_owners' using errcode = '42501'; end if;
  if p_user = auth.uid() then raise exception 'cannot_remove_self' using errcode = '22023'; end if;
  delete from organization_members where organization_id = v_org and user_id = p_user;
end $$;
revoke all on function public.remove_member(uuid) from public;
grant execute on function public.remove_member(uuid) to authenticated;
