# Haven beta audit — Framer build vs. master brief

Builder: Claude · 2026-11-17 · answers tasks #v6zx25 and #dyhtlp on to/havensystems
Source of truth: `files/haven-master-brief.md` v2

**Bottom line:** the front end is demo-complete. Every guest and host page exists, works in English and Spanish, and has believable interactions. Nothing is stored yet: all data is Framer CMS content baked in at publish time, and every form or button "succeeds" without saving anything. The database for Milestone 1 is now written and tested (`supabase/migrations/20261117000000_haven_core.sql` + `supabase/seed.sql`). What's left is a Supabase project from Majo, then wiring the Framer pages to it.

---

## A. Already complete in the Framer build

**Marketing site**
- Landing page (`/`, `/es`), host login (`/host-login`).
- Each page has phone, tablet and desktop layouts.

**Guest side** (Palm Stays branding, "Powered by Haven")
- **Find My Stay:** last name + phone number.
- **Guest portal:** contextual home, guest pass, Need help?, Stay with us again.
- **Property guide:** accordions.
- **Local guide**, **Support**.
- **Amenities:** 9 amenities with request buttons.
- **Checkout:** checklist, extras, review, "I've checked out".
- **Exit** button back to Haven.

**Host side**, with a working sidebar on every page:
- **Overview** with a "New reservation" modal.
- **Properties:** list and detail.
- **Reservations:** list with working status tabs, and detail.
- **Guests:** live name search.
- **Messages:** 4 switchable threads with translations and quick replies.
- **Requests:** New / In progress / Done board.
- **Local guides:** category tabs and an "Add place" modal.
- **Analytics:** KPIs and charts with a 3/6-month toggle.
- **Settings › Branding:** form and live preview.

**Other pieces**
- **Languages:** every page has an `/es` twin, and the EN/ES switch links directly to the counterpart page.
- **White-label data:** a Host Brands CMS (Palm Stays, Casa Sol). Properties, Reservations, Requests and Places are CMS collections with EN and ES fields.

## B. Visual-only: looks real, does nothing

| Area | What happens today |
| --- | --- |
| Find My Stay | Any input goes to `/guest`; no lookup |
| Guest portal, guide, amenities, checkout | Hard-coded to Ocean House / Sofia / Palm Stays; not tied to a reservation |
| Door code | Shown openly (4821) with no verification ⚠ |
| Support requests, amenity and checkout buttons | Flip to "Sent ✓" / "Done ✓"; nothing is saved and the host never sees it |
| Host login | Any click enters `/host`; no auth, no session, host pages are public URLs |
| New reservation, Add place, Add property, branding Save | Modals and forms that save nothing |
| Requests board | Start / Mark done don't move cards; data is static CMS |
| Messages | Static threads; Send doesn't append |
| Analytics, overview KPIs | Static numbers |
| Branding per company | The portal always shows Palm Stays; it is not chosen by reservation |
| Multi-tenant | One company's data; no organization concept at runtime |

Key constraint: **site visitors can't write to Framer's CMS.** Anything that must save (reservations, issues, branding) has to come from an external backend through Framer code components, not CMS collections.

## C. Missing for beta launch

**1. Backend + data model.** Written and tested this session; Majo still needs to create the Supabase project.
- Tables: `organizations`, `organization_members`, `brand_settings`, `properties`, `property_access` (door codes kept apart), `guests`, `reservations`, `issue_reports`, `guest_sessions`.
- Every row carries `organization_id` and is protected by row-level security.
- Tested on Postgres 16: a Palm Stays host sees 2 properties and 0 Casa Sol rows, and is refused when inserting into Casa Sol.

**2. Secure guest access.** Written and tested.
- `lookup_stay(last_name, phone)` returns only a session token and is throttled after 5 misses.
- `get_stay(token)` returns reservation, property and brand, never the door code.
- `verify_stay(token, booking_ref)` is a second factor, also throttled.
- `get_stay_access(token)` returns the door code only to verified sessions, from check-in day to check-out day.
- `report_issue(token, category, text)` routes the issue to the right company automatically.

**3. Framer ↔ Supabase wiring.** Not started; this is the main build work.
- One shared Supabase client module.
- Code components for: stay lookup, portal data, door-code reveal, issue form, host login + session guard, issues list with status changes, reservations list + create form, branding form.

**4. Dynamic branding.** Logo, colors, contacts and "Powered by Haven" come from `brand_settings` through `get_stay`, applied in the portal header and contact cards.

**5. Host onboarding path.** For beta, Majo creates each client's login and organization by hand in the Supabase dashboard. Self-serve signup comes later.

**6. Legal and trust basics.** Privacy policy and terms (you're storing guest names and phones), plus a real sending email for password resets.

## D. Build order: next 7 days

| Day | Work | Done when |
| --- | --- | --- |
| 1 | Majo: create Supabase project, send URL + anon key. Claude: run migration + seed, create 2 test host logins (Palm Stays, Casa Sol) | Both demo companies live in the database |
| 2 | Shared Supabase module in Framer; host login (email/password, forgot password) + session guard on all `/host` pages | Logged-out visit to `/host` goes to login; login lands on dashboard |
| 3 | Find My Stay → `lookup_stay`; portal pages read `get_stay` (name, dates, property, Wi-Fi, parking, brand colors/logo/contacts), EN + ES | Sofia and Mateo each see their own property and company branding |
| 4 | Door code card: "Confirm booking reference" → `verify_stay` → `get_stay_access`. Support "Report a problem" → `report_issue` | Wrong ref shows no code; issue appears in DB under the right org |
| 5 | Host Requests page reads `issue_reports` (live), status buttons update it; overview counts open issues | Guest issue appears on the right host dashboard and can be resolved |
| 6 | Host Reservations: live list + "New reservation" saves guest + reservation and shows the portal link; Branding settings saves `brand_settings` | A host adds a stay and the guest can look it up immediately |
| 7 | End-to-end test with both companies, phone + desktop, EN + ES; publish; beta checklist; demo script | Checklist (G) all green |

Kept as labeled placeholders, not built:
- Airbnb/Vrbo/Booking.com (the `channel` and `external_id` columns already exist)
- n8n automations
- AI messaging and review ingestion
- Upsell payments
- Advanced analytics

The Analytics page can keep demo numbers, labeled "Sample data", until the issue metrics view (`issue_metrics`, already in the schema) is wired.

## E. What Claude can do directly vs. what needs Majo

**Claude, directly:**
- Schema, policies, functions, seed (done).
- Running the migration once given access.
- All Framer code components, overrides and page wiring.
- EN/ES strings, QA, publish checks, docs, demo script.

**Majo:**
1. Create the Supabase account and project, then share the **Project URL** and the **anon (public) key**. Never share the service-role key in chat; it isn't needed in the front end.
2. Either run the SQL file in Supabase's SQL editor or give Claude database access.
3. Create host logins in Supabase Auth (or let Claude do it with dashboard access).
4. Confirm the Framer plan allows custom code and publishing on a domain; decide the domain.
5. Decide the email sender for password resets (Supabase default is fine for beta).
6. Privacy policy and terms text, plus pricing for the first clients.

## F. Blockers to selling a credible beta next week

1. **No Supabase project yet.** Days 2–7 depend on it.
2. **Rebuilding host lists as code components** (instead of CMS lists) is the largest single effort. It is doable in the days above, but keep the scope at Requests + Reservations + Branding.
3. **Framer editing session stability.** The Framer connection dropped several times this week, which slows wiring work. Nothing to fix, just plan buffer.
4. **Door code currently public in the prototype.** Fixed in the backend design; the Framer card must switch to the verified flow before any real property is loaded.
5. **No legal pages.** Needed before real guest data.

## G. "Beta ready" checklist (before showing clients)

- [ ] Host can log in, log out and reset a password; `/host` pages are blocked when logged out
- [ ] Two companies exist and neither can see the other's properties, reservations or issues
- [ ] Host can add a reservation (guest name, phone, property, dates) and copy the guest portal link
- [ ] Guest finds the stay with last name + phone, in English and Spanish
- [ ] Portal shows the right property, dates, Wi-Fi, parking and the right company's logo, colors and contacts
- [ ] Door code hidden until the booking reference is confirmed, and only during the stay
- [ ] Guest reports a problem; it appears on the right host's Requests page within seconds; host can mark it resolved
- [ ] Everything not yet real (channels, automations, AI, payments, sample analytics) is visibly labeled "Coming soon" or "Sample data"
- [ ] Tested on a phone and a desktop; EN/ES switch works on every page
- [ ] Privacy policy and terms linked in the footer
- [ ] Demo data reset to a clean, believable state; demo script rehearsed

## Next three highest-value steps

1. Supabase project + migration (unblocks everything).
2. Guest lookup → real portal data with dynamic branding: the core "wow" moment, and proof of multi-tenancy.
3. Issue reporting end to end (guest form → host Requests): the first real operational value for a property manager.
