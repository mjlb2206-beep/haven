-- Guest access: last name + phone (full number OR just the last 4 digits).
-- Decision (Majo, Nov 17): no SMS codes. Matching last name + phone is the verification,
-- so the session is verified at lookup and the door code shows during the stay.
-- Brute force is limited by the existing throttle: 5 misses per name+digits per 15 min.

create or replace function public.lookup_stay(p_last_name text, p_phone text)
returns uuid language plpgsql security definer set search_path = public as $$
declare
  v_all    text := regexp_replace(coalesce(p_phone, ''), '\D', '', 'g');
  v_last4  boolean := length(v_all) = 4;
  v_digits text := case when length(v_all) = 4 then v_all else right(v_all, 10) end;
  v_name   text := lower(trim(coalesce(p_last_name, '')));
  v_key    text := v_name || ':' || v_digits;
  v_res    reservations%rowtype;
  v_token  uuid;
begin
  if not (length(v_all) = 4 or length(v_all) >= 7) or length(v_name) < 2 then
    raise exception 'invalid_input' using errcode = '22023';
  end if;
  -- per name+digits, and per name alone (stops cycling through 10,000 last-4 combos)
  if (select count(*) from lookup_attempts where key = v_key and created_at > now() - interval '15 minutes') >= 5
     or (select count(*) from lookup_attempts where key like v_name || ':%' and created_at > now() - interval '1 hour') >= 20 then
    raise exception 'too_many_attempts' using errcode = '54000';
  end if;

  select r.* into v_res
  from reservations r join guests g on g.id = r.guest_id
  where lower(g.last_name) = v_name
    and (case when v_last4 then right(g.phone_digits, 4) = v_digits
              else right(g.phone_digits, 10) = v_digits end)
    and r.status <> 'cancelled'
    and r.check_out >= current_date
  order by r.check_in
  limit 1;

  if not found then
    insert into lookup_attempts (key) values (v_key);
    return null;
  end if;

  insert into guest_sessions (reservation_id, organization_id, expires_at, verified_at)
  values (v_res.id, v_res.organization_id, (v_res.check_out + 1)::timestamptz, now())
  returning token into v_token;
  return v_token;
end $$;

grant execute on function public.lookup_stay(text, text) to anon, authenticated;
