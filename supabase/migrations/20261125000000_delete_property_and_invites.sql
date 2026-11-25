-- Nov 25: delete a property from the dashboard, and let an invited person see what they were invited to.

-- Deletes a property and everything that belongs to it (reservations, their messages and requests,
-- guest sessions, access codes, property-only guide content). Guests with no other stays are removed too.
create or replace function public.delete_property(p_property uuid)
returns void language plpgsql security definer set search_path = public as $$
declare v_org uuid; v_guests uuid[];
begin
  select organization_id into v_org from properties where id = p_property;
  if v_org is null or not is_org_member(v_org) then raise exception 'not_allowed' using errcode = '42501'; end if;
  select array_agg(distinct guest_id) into v_guests from reservations where property_id = p_property;
  delete from guest_sessions where reservation_id in (select id from reservations where property_id = p_property);
  delete from issue_reports where property_id = p_property;
  delete from reservations where property_id = p_property;          -- threads + messages cascade
  delete from guests g where g.id = any(coalesce(v_guests, '{}')) and not exists (select 1 from reservations r where r.guest_id = g.id);
  delete from properties where id = p_property;                      -- access, guide rows etc. cascade
end $$;
revoke all on function public.delete_property(uuid) from public;
grant execute on function public.delete_property(uuid) to authenticated;

-- Public look-up for the invite screen: company name, role and the invited email. Nothing else.
create or replace function public.get_invitation(p_token uuid)
returns jsonb language sql stable security definer set search_path = public as $$
  select jsonb_build_object('company', coalesce(b.business_name, o.name), 'logo_url', b.logo_url, 'primary_color', b.primary_color,
                            'role', i.role, 'email', i.email, 'expired', i.expires_at < now(), 'accepted', i.accepted_at is not null)
  from team_invitations i join organizations o on o.id = i.organization_id left join brand_settings b on b.organization_id = o.id
  where i.token = p_token;
$$;
grant execute on function public.get_invitation(uuid) to anon, authenticated;
