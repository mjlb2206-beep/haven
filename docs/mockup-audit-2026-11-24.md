# Haven: what is still a mockup (audit, Nov 24 2026)

Scan of every page in the Framer project (EN pages; ES mirrors them).
LIVE = reads/writes Supabase. MOCKUP = fixed text/sample data, or a button that does nothing.

## Guest side

| Page | Live | Still mockup |
|---|---|---|
| /find-my-stay | Lookup form (last name + phone / last 4) | Right-hand photo card ("Your stay is ready · Ocean House · Nov 14–18") |
| /guest | Greeting, property/area, dates, guests, unit, parking, layout, Wi-Fi + password, door code, booking ref, check-in/out, days left, brand name/logo/color, Exit | Context line ("rooftop pool is open…"), check-in timeline (Booked / ID verified / Code sent / Checked in), "Today's recommendations", Digital guest pass + "Add to Wallet" + "Tap to unlock", "Need help?" contact card (sample, not the host's phone/WhatsApp), "Alex replies in about 4 minutes", luggage line on the checkout card, avatar "SM" + stay chip in the top bar |
| /support | Chat with host, New request form | Header text ("Alex sees it…"), Quick Actions buttons (do nothing), "Your requests" history (#2041 etc.), Emergency info card (911, Mount Sinai ER, building security), floating chat bubble badge "1" |
| /guide (Property guide) | — | Entire page (Ocean House sample) |
| /amenities | — | Entire page |
| /local (Local guide) | — | Entire page ("curated by Alex") |
| /checkout | — | Entire page (steps, luggage, review) |

## Host side

| Area | Live | Still mockup |
|---|---|---|
| Top bar | Account / sign out | Search box (⌘K), notification bell + red dot, "New reservation" button (opens a form that never saves; the real one is on Reservations) |
| Sidebar | Company card (name, logo, property count, plan, menu) | Count badges (Properties 4, Reservations 12, Messages 3, Requests 1), "Haven AI · beta / Join the beta" card |
| /host Overview | All numbers and lists | Heading "Good morning, Alex · Saturday, November 16" |
| /host/properties | List, status, edit, add | Heading action buttons |
| /host/reservations | List, tabs, search, new reservation, Sheets import (houses + bookings) | — |
| /host/guests | Everything | — |
| /host/messages | Inbox + replies | — |
| /host/requests | Kanban board | — |
| /host/settings | Branding tab (logo upload, colors, contacts, guest link) | Tabs General / Languages / Team / Billing, header "Save changes" / "Preview portal" buttons |
| /host/local-guides | — | Entire page (Framer CMS sample places) |
| /host/analytics | — | Entire page ($14,850 revenue, charts, languages) |
| Property detail / Reservation detail pages | — | Framer CMS sample pages, not Supabase; live lists don't link to them |

## Marketing (static by design)
Homepage, /for-hosts, host-login testimonial: content pages, fine as static.
Gap: no self-serve sign-up. A new host can't create their own company; companies are created by SQL today.

## Backend features shown in the design but not built
Emails/notifications, payments & upsells (Stripe), automations, ID verification, digital pass / smart locks,
OTA sync (Airbnb/Vrbo/iCal), owner reports, team invites, billing.
