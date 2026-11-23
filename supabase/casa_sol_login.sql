-- Casa Sol login (second demo company), 2 steps.
--
-- STEP 1 (no SQL): Supabase > Authentication > Users > "Add user" > "Create new user"
--   Email:    any email you control (or e.g. casasol.demo@yourdomain.com)
--   Password: choose one (don't share it in chat)
--   Tick "Auto Confirm User", then Create.
--
-- STEP 2: replace the email below with the one you used, then SQL Editor > Run.
insert into public.organization_members (organization_id, user_id, role)
select '00000000-0000-4000-a000-000000000002', id, 'owner'
from auth.users where email = 'casasol.demo@yourdomain.com'   -- <-- change this
on conflict do nothing;

-- Check: you should see your Casa Sol email next to "Casa Sol Rentals".
select u.email, o.name as company
from public.organization_members m
join auth.users u on u.id = m.user_id
join public.organizations o on o.id = m.organization_id;
