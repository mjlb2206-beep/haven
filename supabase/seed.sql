-- Demo data: two separate host companies, to show tenant isolation.
-- Host logins are created in Supabase Auth (Dashboard > Authentication > Add user),
-- then linked with:  insert into organization_members (organization_id, user_id, role) values (<org id>, <auth user id>, 'owner');

insert into public.organizations (id, name, slug, plan) values
  ('00000000-0000-4000-a000-000000000001', 'Palm Stays', 'palm-stays', 'growth'),
  ('00000000-0000-4000-a000-000000000002', 'Casa Sol Rentals', 'casa-sol', 'starter');

insert into public.brand_settings (organization_id, business_name, tagline, primary_color, accent_color, phone, whatsapp, email, instagram, website, caretaker_name, caretaker_phone, default_language) values
  ('00000000-0000-4000-a000-000000000001', 'Palm Stays', 'Miami Beach stays, done right', '#1E5B6E', '#F2B880', '+1 305 555 0142', '+1 305 555 0142', 'hello@palmstays.com', '@palmstays.miami', 'palmstays.com', 'Marta', '+1 305 555 0199', 'en'),
  ('00000000-0000-4000-a000-000000000002', 'Casa Sol Rentals', 'Tu casa en Cartagena', '#C2552D', '#F4D35E', '+57 300 555 0101', '+57 300 555 0101', 'hola@casasol.co', '@casasol.ctg', 'casasol.co', 'Luis', '+57 300 555 0177', 'es');

insert into public.properties (id, organization_id, name, slug, area, address, layout, layout_es, description, description_es, wifi_name, wifi_password, parking, parking_es) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-a000-000000000001', 'Ocean House', 'ocean-house', 'Miami Beach', '1200 Collins Ave, Unit 1204', '2BR · 2BA · sleeps 4', '2 dorm. · 2 baños · 4 huéspedes', 'Bright corner unit with ocean views.', 'Departamento de esquina con vista al mar.', 'OceanHouse_5G', 'saltwater24', 'Garage spot P2-14, enter on 5th St', 'Cochera P2-14, entrada por la calle 5'),
  ('00000000-0000-4000-b000-000000000002', '00000000-0000-4000-a000-000000000001', 'Palm Loft', 'palm-loft', 'Wynwood', '250 NW 24th St, 3B', '1BR · 1BA · sleeps 2', '1 dorm. · 1 baño · 2 huéspedes', 'Loft steps from the murals.', 'Loft a pasos de los murales.', 'PalmLoft', 'murals2026', 'Street parking, zone 12', 'Estacionamiento en la calle, zona 12'),
  ('00000000-0000-4000-b000-000000000003', '00000000-0000-4000-a000-000000000002', 'Casa Azul', 'casa-azul', 'Cartagena', 'Calle del Cuartel 36-12', '3BR · 3BA · sleeps 6', '3 dorm. · 3 baños · 6 huéspedes', 'Colonial house with a plunge pool.', 'Casa colonial con piscina.', 'CasaAzul', 'cartagena36', 'No parking; taxi drop-off at the door', 'Sin estacionamiento; el taxi te deja en la puerta');

insert into public.property_access (property_id, organization_id, door_code, access_notes, access_notes_es) values
  ('00000000-0000-4000-b000-000000000001', '00000000-0000-4000-a000-000000000001', '4821#', 'Smart lock on unit 1204', 'Cerradura inteligente en la unidad 1204'),
  ('00000000-0000-4000-b000-000000000002', '00000000-0000-4000-a000-000000000001', '7730#', 'Lockbox by the gate', 'Caja de llaves junto al portón'),
  ('00000000-0000-4000-b000-000000000003', '00000000-0000-4000-a000-000000000002', '1936', 'Keypad on the blue door', 'Teclado en la puerta azul');

insert into public.guests (id, organization_id, first_name, last_name, phone, email, country, language) values
  ('00000000-0000-4000-c000-000000000001', '00000000-0000-4000-a000-000000000001', 'Sofia', 'Martinez', '+54 9 11 5555 0101', 'sofia.m@example.com', 'Argentina', 'es'),
  ('00000000-0000-4000-c000-000000000002', '00000000-0000-4000-a000-000000000001', 'James', 'Lee', '+1 416 555 0123', 'james.lee@example.com', 'Canada', 'en'),
  ('00000000-0000-4000-c000-000000000003', '00000000-0000-4000-a000-000000000002', 'Mateo', 'Gomez', '+57 310 555 0144', 'mateo.g@example.com', 'Colombia', 'es');

-- Dates relative to today so the demo always has an in-house and an upcoming stay.
insert into public.reservations (organization_id, property_id, guest_id, booking_ref, check_in, check_out, adults, status, total_cents) values
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-b000-000000000001', '00000000-0000-4000-c000-000000000001', 'HV-20418', current_date - 1, current_date + 3, 2, 'in_house', 192000),
  ('00000000-0000-4000-a000-000000000001', '00000000-0000-4000-b000-000000000002', '00000000-0000-4000-c000-000000000002', 'HV-20422', current_date + 2, current_date + 4, 1, 'upcoming', 64000),
  ('00000000-0000-4000-a000-000000000002', '00000000-0000-4000-b000-000000000003', '00000000-0000-4000-c000-000000000003', 'CS-1107', current_date, current_date + 5, 4, 'arriving', 410000);
