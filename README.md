# Haven

**Your stay, all in one place.**

Haven is a digital guest experience platform for short-term rentals, boutique stays, vacation rentals and property managers. Guests get one calm place for reservation details, check-in, Wi-Fi, amenities, local recommendations, support and checkout. Hosts get a separate dashboard to run properties, reservations, guest requests and local guides.

> **Status: v0.1.0-beta.** This is an interactive Framer prototype for design and product validation. No backend, authentication or real data storage yet.

![Haven landing page](docs/screenshots/01-landing-hero.jpg)

## What's in the prototype

| Page | Path | Notes |
| --- | --- | --- |
| Landing | `/` | Marketing site: guest journey, dashboard preview, contextual "right now" demo, property guide, local guide, support, guest pass, white-label section, hosts, benefits, how it works |
| Find My Stay | `/find-my-stay` | Guest lookup with last name + check-in date (no account) |
| Guest Portal | `/guest` | Host-branded portal (Palm Stays): right-now cards, reservation, check-in status, guest pass, Need help?, Stay with us again |
| Guest Portal (Español) | `/es/guest` | Full Spanish version, linked by the EN / ES switch |
| Property Guide | `/guide` | Expandable instructions, amenities, safety |
| Local Guide | `/local` | Neighborhood map, host picks, essentials |
| Support | `/support` | Quick actions, tracked requests, chat, emergency info |
| Host Login | `/host-login` | Email, password, remember me |
| Host Dashboard | `/host` | Metrics, arrivals, requests, property performance, messages, automations |
| Host Settings · Branding | `/host-settings` | Business name, logo, colors, contact, languages, "Powered by Haven" toggle, live preview |

Every page has Desktop (1200), Tablet (810) and Phone (390) layouts. On phones the guest portal behaves like a native app with a bottom tab bar and a floating chat button.

## Platform model: one Haven, many host brands

Haven is the SaaS platform. Each host or property manager shows guests their **own** brand, with a subtle *Powered by Haven*.

- Host branding is data, not hard-coded design. In Framer it lives in the **Host Brands** CMS collection; see [`data/host-brands.schema.json`](data/host-brands.schema.json) and [`data/host-brands.sample.json`](data/host-brands.sample.json).
- Demo hosts: **Palm Stays** (Miami Beach) and **Casa Sol Rentals** (Cartagena). Both are fictional.
- Guest portal sections that read host data: the hosted-by strip, **Need help?** (Phone/WhatsApp, Email, Instagram, caretaker), **Stay with us again**, and the branded guest pass.

| Palm Stays guest portal | Branding settings |
| --- | --- |
| ![Guest portal](docs/screenshots/07-guest-portal-palm-stays.jpg) | ![Branding settings](docs/screenshots/14-host-branding-settings.jpg) |

## Languages

Many guests speak Spanish (for example, from Argentina), alongside guests from Canada, Russia and elsewhere. v0.1 ships:

- An **EN / ES** switch in the guest portal, linking `/guest` and `/es/guest`.
- String files for both languages in [`i18n/en.json`](i18n/en.json) and [`i18n/es.json`](i18n/es.json).
- Russian appears in settings as a planned "beta" language.

Only the main portal page is translated so far. Browser translation remains a fallback for other languages.

## Design system

- **Colors:** cream, sage, deep sage, charcoal, with coral as the single accent. See [`design/tokens.json`](design/tokens.json).
- **Type:** Plus Jakarta Sans, with responsive text styles.
- **Logo:** a rounded doorway with a keyhole that also reads as a location pin. See [`brand/`](brand).
- **Icons:** Phosphor (thin line).

## Repository layout

```
brand/      Haven and demo-host logos (SVG)
data/       Host brand schema and sample data
design/     Design tokens
docs/       Screenshots
i18n/       English and Spanish UI strings
VERSION     Current version (0.1.0-beta)
CHANGELOG.md
```

The design source itself lives in Framer: https://framer.com/projects/RuIZ5kkZaTiHvPQYrEGL

## Out of scope for v0.1

- Real authentication, verification and database storage (forms and settings are visual only)
- Channel integrations (Airbnb, Vrbo, Booking.com and similar)
- Full translation of every page
- Per-host theming across the entire portal. Today brand colors apply to host-specific elements.

See [CHANGELOG.md](CHANGELOG.md) for details.
