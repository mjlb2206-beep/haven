-- Keeps the demo guests' stays current: re-dates the 13 demo reservations relative to today,
-- every day at 06:00 UTC, so Ferreira / Schulz / Bennett / Morales logins always work.
create or replace function public.refresh_demo_stays()
returns void language sql security definer set search_path = public as $$
  update reservations r set check_in = current_date + v.d_in, check_out = current_date + v.d_out,
    status = case when current_date + v.d_out < current_date then 'checked_out'::reservation_status
                  when v.d_in = 0 then 'arriving'::reservation_status
                  when v.d_in < 0 then 'in_house'::reservation_status else 'upcoming'::reservation_status end
  from (values
    ('00000000-0000-4000-d000-000000000011'::uuid, -2, 3),
    ('00000000-0000-4000-d000-000000000012'::uuid, 0, 4),
    ('00000000-0000-4000-d000-000000000013'::uuid, 0, 2),
    ('00000000-0000-4000-d000-000000000014'::uuid, 1, 5),
    ('00000000-0000-4000-d000-000000000015'::uuid, 3, 10),
    ('00000000-0000-4000-d000-000000000016'::uuid, 4, 8),
    ('00000000-0000-4000-d000-000000000017'::uuid, 6, 9),
    ('00000000-0000-4000-d000-000000000018'::uuid, -9, -4),
    ('00000000-0000-4000-d000-000000000019'::uuid, -12, -8),
    ('00000000-0000-4000-d000-000000000020'::uuid, -20, -13),
    ('00000000-0000-4000-d000-000000000021'::uuid, -1, 2),
    ('00000000-0000-4000-d000-000000000022'::uuid, 2, 7),
    ('00000000-0000-4000-d000-000000000023'::uuid, -10, -6)
  ) as v(id, d_in, d_out)
  where r.id = v.id;
  update guest_sessions s set expires_at = (r.check_out + 1)::timestamptz
  from reservations r where r.id = s.reservation_id and r.id::text like '00000000-0000-4000-d000-%';
$$;
revoke all on function public.refresh_demo_stays() from public, anon, authenticated;

select public.refresh_demo_stays();

-- Daily refresh (Supabase includes pg_cron; this enables it if it isn't yet).
create extension if not exists pg_cron;
select cron.unschedule('haven-demo-refresh') where exists (select 1 from cron.job where jobname = 'haven-demo-refresh');
select cron.schedule('haven-demo-refresh', '0 6 * * *', 'select public.refresh_demo_stays()');
