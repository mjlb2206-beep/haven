-- Run once: Supabase > SQL Editor > New query > paste all > Run.
-- Adds Haven's content + operations tables, then fills them with demo content for Palm Stays and Casa Sol.

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

-- Demo content for the two demo companies. Safe to run more than once (skips a company that already has content).
-- Palm Stays (Miami, English) = ...0001   ·   Casa Sol Rentals (Cartagena, Spanish) = ...0002

do $$
declare ps uuid := '00000000-0000-4000-a000-000000000001'; cs uuid := '00000000-0000-4000-a000-000000000002';
begin
-- ============================== PALM STAYS ==============================
if not exists (select 1 from guide_sections where organization_id = ps) then
  insert into guide_sections (organization_id, category, title, title_es, body, body_es, icon, sort_order) values
  (ps,'arrival','Arriving','Llegada','Check-in is from 3:00 PM. Your door code appears in your portal on arrival day. Elevators are to the left of the lobby.','La entrada es desde las 3:00 PM. Tu código aparece en el portal el día de llegada. Los ascensores están a la izquierda del lobby.','🔑',1),
  (ps,'wifi','Wi-Fi','Wi-Fi','Your network name and password are on your Home screen. The router is in the living-room cabinet: if it drops, unplug it for 10 seconds.','El nombre de la red y la clave están en tu Inicio. El router está en el mueble de la sala: si se cae, desconéctalo 10 segundos.','📶',2),
  (ps,'tv','TV & streaming','TV y streaming','Use the Samsung remote. Netflix and YouTube are signed in: please sign out of any personal accounts before you leave.','Usa el control Samsung. Netflix y YouTube tienen sesión iniciada: cierra tus cuentas personales antes de salir.','📺',3),
  (ps,'kitchen','Kitchen','Cocina','Fully equipped: Nespresso, toaster, blender, pots and pans. Coffee pods are in the top drawer. Please run the dishwasher before checkout.','Equipada: Nespresso, tostadora, licuadora, ollas y sartenes. Las cápsulas están en el primer cajón. Por favor enciende el lavavajillas antes de salir.','🍳',4),
  (ps,'house_rules','House rules','Normas de la casa','No smoking anywhere in the building. Quiet hours 10 PM – 8 AM. No parties or events. Max occupancy as booked.','No se fuma en el edificio. Silencio de 10 PM a 8 AM. No se permiten fiestas. Ocupación máxima según la reserva.','📋',5),
  (ps,'trash','Trash & recycling','Basura y reciclaje','Trash chute is next to the elevators on every floor. Recycling bins are in the garage, level P1.','El ducto de basura está junto a los ascensores. El reciclaje está en el garaje, nivel P1.','♻️',6),
  (ps,'parking','Parking','Estacionamiento','Your assigned spot is shown on your Home screen. Guest parking passes are at the front desk.','Tu puesto asignado aparece en tu Inicio. Los pases de visitante están en recepción.','🚗',7),
  (ps,'pool','Pool & beach','Piscina y playa','Rooftop pool open 8 AM – 10 PM. Beach towels and two chairs are in the hall closet.','Piscina en la azotea de 8 AM a 10 PM. Toallas de playa y dos sillas en el clóset del pasillo.','🏖️',8);

  insert into amenities (organization_id, name, name_es, description, description_es, icon, hours, location, sort_order) values
  (ps,'Rooftop pool','Piscina en la azotea','Heated pool with ocean views and loungers.','Piscina climatizada con vista al mar.','🏊','8 AM – 10 PM','Rooftop, level 20',1),
  (ps,'Fitness center','Gimnasio','Cardio machines, free weights and yoga mats.','Máquinas de cardio, pesas y colchonetas.','💪','24 hours','Level 2',2),
  (ps,'Beach gear','Equipo de playa','Towels, two chairs and an umbrella.','Toallas, dos sillas y una sombrilla.','⛱️',null,'Hall closet',3),
  (ps,'Washer & dryer','Lavadora y secadora','In-unit, detergent provided.','En el apartamento, con detergente.','🧺',null,'Laundry closet',4),
  (ps,'Bikes','Bicicletas','Two city bikes with locks, free for guests.','Dos bicicletas con candado, gratis.','🚲','7 AM – 9 PM','Garage P1',5),
  (ps,'Workspace','Espacio de trabajo','Desk, monitor and fast Wi-Fi.','Escritorio, monitor y Wi-Fi rápido.','💻',null,'Second bedroom',6);

  insert into local_places (organization_id, category, name, description, description_es, address, price_level, distance_note, hours, featured, sort_order) values
  (ps,'coffee','Morning Brew','Best flat white on the block, great pastries.','El mejor flat white de la zona.','1820 Collins Ave',2,'0.3 mi · 6 min walk','7 AM – 4 PM',true,1),
  (ps,'eat','Casa Mare','Italian seafood, ask for a terrace table at sunset.','Mariscos italianos, pide terraza al atardecer.','2100 Collins Ave',3,'0.7 mi','6 PM – 11 PM',true,2),
  (ps,'eat','Taquería Sol','Casual tacos and fresh juices, kid friendly.','Tacos y jugos naturales, ideal con niños.','1650 Washington Ave',1,'0.4 mi','11 AM – 10 PM',false,3),
  (ps,'beach','Beach access 21st St','Lifeguard tower, showers and chair rentals.','Salvavidas, duchas y alquiler de sillas.','21st St & Collins',null,'5 min walk','Lifeguard 9 AM – 5 PM',true,4),
  (ps,'nightlife','The Rooftop Bar','Cocktails with skyline views.','Cócteles con vista a la ciudad.','1901 Collins Ave',3,'0.4 mi','5 PM – 1 AM',false,5),
  (ps,'explore','Art Deco walking tour','90-minute guided tour of the historic district.','Tour guiado de 90 minutos por el distrito histórico.','1001 Ocean Dr',2,'1.2 mi','Daily 10:30 AM',false,6),
  (ps,'essentials','Publix Supermarket','Groceries, pharmacy and ready meals.','Supermercado, farmacia y comida lista.','1920 West Ave',null,'0.6 mi','7 AM – 10 PM',false,7),
  (ps,'essentials','CVS Pharmacy','Open 24 hours.','Abierta 24 horas.','1421 Alton Rd',null,'0.9 mi','24 hours',false,8);

  insert into checkout_steps (organization_id, text, text_es, sort_order) values
  (ps,'Start the dishwasher and take out the trash.','Enciende el lavavajillas y saca la basura.',1),
  (ps,'Leave used towels in the bathtub.','Deja las toallas usadas en la bañera.',2),
  (ps,'Turn off the AC and close the balcony door.','Apaga el aire y cierra la puerta del balcón.',3),
  (ps,'Leave the parking pass on the kitchen counter.','Deja el pase de estacionamiento en la cocina.',4),
  (ps,'The door locks automatically when you leave.','La puerta se cierra sola al salir.',5);

  insert into emergency_contacts (organization_id, label, label_es, value, kind, sort_order) values
  (ps,'Emergency services','Emergencias','911','phone',1),
  (ps,'Nearest ER · Mount Sinai Medical Center','Urgencias · Mount Sinai Medical Center','4300 Alton Rd · 1.2 mi','address',2),
  (ps,'Building security','Seguridad del edificio','(305) 555-0142','phone',3),
  (ps,'Fire exits','Salidas de emergencia','End of each hallway','other',4);

  update properties set luggage_note = 'Luggage can stay at the front desk until 4 PM.', luggage_note_es = 'Puedes dejar el equipaje en recepción hasta las 4 PM.',
                        late_checkout_note = 'Late checkout until 1 PM when available: ask in the chat.', late_checkout_note_es = 'Salida tardía hasta la 1 PM si hay disponibilidad: pregunta en el chat.'
  where organization_id = ps and luggage_note is null;
end if;

-- ============================== CASA SOL (Cartagena) ==============================
if not exists (select 1 from guide_sections where organization_id = cs) then
  insert into guide_sections (organization_id, category, title, title_es, body, body_es, icon, sort_order) values
  (cs,'arrival','Arriving','Llegada','Check-in from 3 PM. Luis will meet you at the door or leave the keys in the lockbox.','La entrada es desde las 3 PM. Luis te recibe en la puerta o deja las llaves en la caja de seguridad.','🔑',1),
  (cs,'wifi','Wi-Fi','Wi-Fi','Network and password are on your Home screen.','La red y la clave están en tu Inicio.','📶',2),
  (cs,'house_rules','House rules','Normas de la casa','No smoking indoors. Quiet hours 10 PM – 8 AM. Please save water.','No fumar adentro. Silencio de 10 PM a 8 AM. Por favor cuida el agua.','📋',3),
  (cs,'kitchen','Kitchen','Cocina','Coffee maker, blender and basic spices. Bottled water in the fridge on arrival.','Cafetera, licuadora y especias básicas. Agua en la nevera a tu llegada.','🍳',4);
  insert into amenities (organization_id, name, name_es, icon, hours, location, sort_order) values
  (cs,'Plunge pool','Piscina','🏊','8 AM – 9 PM','Terraza',1),
  (cs,'Air conditioning','Aire acondicionado','❄️',null,'Todas las habitaciones',2),
  (cs,'Beach towels','Toallas de playa','🏖️',null,'Clóset',3);
  insert into local_places (organization_id, category, name, description_es, address, price_level, distance_note, featured, sort_order) values
  (cs,'eat','La Cevichería','El ceviche más famoso del centro histórico.','Calle Stuart 7-14',2,'10 min a pie',true,1),
  (cs,'coffee','Época Café','Café de origen colombiano y postres.','Calle del Espíritu Santo',1,'5 min a pie',false,2),
  (cs,'beach','Playa Blanca','Excursión en lancha desde el muelle La Bodeguita.','Muelle La Bodeguita',2,'45 min en lancha',true,3),
  (cs,'nightlife','Café del Mar','Atardecer sobre la muralla.','Baluarte de Santo Domingo',3,'12 min a pie',false,4);
  insert into checkout_steps (organization_id, text, text_es, sort_order) values
  (cs,'Leave the keys in the lockbox.','Deja las llaves en la caja de seguridad.',1),
  (cs,'Turn off the AC and lights.','Apaga el aire y las luces.',2);
  insert into emergency_contacts (organization_id, label, label_es, value, kind, sort_order) values
  (cs,'Emergencies','Emergencias','123','phone',1),
  (cs,'Tourist police','Policía de turismo','+57 605 660 0000','phone',2);
end if;

-- Check-in timeline on demo reservations that are already in house.
update reservations set id_verified_at = coalesce(id_verified_at, (check_in - 2)::timestamptz + interval '10 hours'),
                        code_sent_at   = coalesce(code_sent_at,   check_in::timestamptz + interval '14 hours'),
                        checked_in_at  = coalesce(checked_in_at,  check_in::timestamptz + interval '15 hours 12 minutes')
where organization_id in (ps, cs) and check_in <= current_date and check_out > current_date and status <> 'cancelled';
end $$;
