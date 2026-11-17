-- Run AFTER creating the two host logins in Supabase > Authentication > Users > Add user.
-- Replace the two emails with the ones you created, then Run.
insert into public.organization_members (organization_id, user_id, role)
select '00000000-0000-4000-a000-000000000001', id, 'owner' from auth.users where email = 'palm@example.com'   -- Palm Stays
union all
select '00000000-0000-4000-a000-000000000002', id, 'owner' from auth.users where email = 'casasol@example.com' -- Casa Sol Rentals
on conflict do nothing;

-- Check: should list both emails with their company.
select u.email, o.name from public.organization_members m
join auth.users u on u.id = m.user_id join public.organizations o on o.id = m.organization_id;
