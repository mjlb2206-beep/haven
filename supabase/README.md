# Haven backend (Supabase)

- `migrations/20261117000000_haven_core.sql`: Milestone 1 schema, row-level security and guest functions.
- `seed.sql`: two demo companies (Palm Stays, Casa Sol) with properties, guests and reservations dated around today.

Apply: Supabase dashboard → SQL editor → run the migration, then the seed. Or `supabase db push` with the CLI.

Guest flow (callable with the anon key):

1. `rpc('lookup_stay', { p_last_name, p_phone })` → session token
2. `rpc('get_stay', { p_token })` → reservation, property, brand (no door code)
3. `rpc('verify_stay', { p_token, p_booking_ref })` → true/false
4. `rpc('get_stay_access', { p_token })` → door code, only when verified and during the stay
5. `rpc('report_issue', { p_token, p_category, p_description })` → issue id

Hosts sign in with Supabase Auth; `organization_members` links a login to its company and RLS scopes every table to it.
