# Changelog

All notable changes to Haven are recorded here. This project uses [Semantic Versioning](https://semver.org/); versions below 1.0 are pre-release.

## [0.2.1-beta] — 2026-11-16

### Added
- Guest **Amenities** (`/amenities`) and **Checkout** (`/checkout`) pages, in English and Spanish, linked from the guest app bar.
- **Exit** button in the guest app bar (Salir in Spanish) that returns to the Haven home page.

### Changed
- Guests now find their reservation with **last name + phone number** instead of check-in date.

### Fixed
- Language switch: every EN / ES button is now a direct page link instead of a component variable, so switching navigates instantly in both directions.

## [0.2.0-beta] — 2026-11-16

### Added
- **Full host platform:** Properties (+ detail), Reservations with status tabs (+ detail), Guests with search, Messages inbox, Requests board, Local Guides with category filters and an "Add place" modal, Analytics, Settings. The sidebar works on every host page.
- **Spanish everywhere:** every page now has an `/es/...` twin, translated, using Spanish CMS fields and Spanish copies of shared components.
- `i18n/es-full.json`: complete Spanish string table.

### Fixed
- **Language switch:** switching from Spanish back to English no longer hangs. Each page's switch now links explicitly to its own English and Spanish versions.

## [0.1.0-beta] — 2026-11-16

First beta of the Haven prototype, built in Framer.

### Added
- **Brand and design system:** Haven logo, color tokens (cream, sage, deep sage, charcoal, coral accent), Plus Jakarta Sans text styles, button, nav, guest pass and guide item components.
- **Landing page:** sticky nav with mobile drawer, hero with floating dashboard, stacking guest-journey cards, guest dashboard preview, interactive "right now" phone (before / during / checkout), property guide accordions, horizontal local guide, support, digital guest pass, white-label section, host dashboard preview, benefits, how it works, footer.
- **Guest flow:** Find My Stay lookup, guest portal, property guide, local guide with map, support and requests. All pages have tablet and phone layouts, with a bottom tab bar on phones.
- **Host flow:** host login, host dashboard (metrics, arrivals, requests, property performance, messages, automations), and the Branding & personalization settings page with a live preview.
- **White-label branding:** Host Brands CMS collection (Palm Stays, Casa Sol Rentals) driving the hosted-by strip, Need help?, Stay with us again and the branded guest pass, plus "Powered by Haven" attribution.
- **Languages:** EN / ES switch and a fully translated Spanish guest portal (`/es/guest`).

### Known limitations
- Prototype only. No backend, authentication or saved settings.
- No booking-channel integrations by design for this version.
