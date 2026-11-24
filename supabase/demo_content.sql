-- Demo content for the two demo companies. Safe to run more than once (skips a company that already has content).
-- Palm Stays (Miami, English) = ...0001   ·   Casa Sol Rentals (Cartagena, Spanish) = ...0002

do $$
declare ps uuid := '00000000-0000-4000-a000-000000000001'; cs uuid := '00000000-0000-4000-a000-000000000002';
begin
-- ============================== PALM STAYS ==============================
if not exists (select 1 from guide_sections where organization_id = ps) then
  insert into guide_sections (organization_id, category, title, title_es, body, body_es, icon, sort_order) values
  (ps,'arrival','Arriving','Llegada','Check-in is from 3:00 PM. Your door code appears in your portal on arrival day. Elevators are to the left of the lobby.','La entrada es desde las 3:00 PM. Tu código aparece en el portal el día de llegada. Los ascensores están a la izquierda del lobby.','🔑',1),
  (ps,'wifi','Wi-Fi','Wi-Fi','Your network name and password are on your Home screen. The router is in the living-room cabinet: if it drops, unplug it for 10 seconds.','El nombre de la red y la clave están en tu Inicio. El router está en el mueble de la sala: si se cae, desconéctalo 10 segundos.','📶',2),
  (ps,'tv','TV & streaming','TV y streaming','Use the Samsung remote. Netflix and YouTube are signed in: please sign out of any personal accounts before you leave.','Usa el control Samsung. Netflix y YouTube tienen sesión iniciada: cierra tus cuentas personales antes de salir.','📺',3),
  (ps,'kitchen','Kitchen','Cocina','Fully equipped: Nespresso, toaster, blender, pots and pans. Coffee pods are in the top drawer. Please run the dishwasher before checkout.','Equipada: Nespresso, tostadora, licuadora, ollas y sartenes. Las cápsulas están en el primer cajón. Por favor enciende el lavavajillas antes de salir.','🍳',4),
  (ps,'house_rules','House rules','Normas de la casa','No smoking anywhere in the building. Quiet hours 10 PM – 8 AM. No parties or events. Max occupancy as booked.','No se fuma en el edificio. Silencio de 10 PM a 8 AM. No se permiten fiestas. Ocupación máxima según la reserva.','📋',5),
  (ps,'trash','Trash & recycling','Basura y reciclaje','Trash chute is next to the elevators on every floor. Recycling bins are in the garage, level P1.','El ducto de basura está junto a los ascensores. El reciclaje está en el garaje, nivel P1.','♻️',6),
  (ps,'parking','Parking','Estacionamiento','Your assigned spot is shown on your Home screen. Guest parking passes are at the front desk.','Tu puesto asignado aparece en tu Inicio. Los pases de visitante están en recepción.','🚗',7),
  (ps,'pool','Pool & beach','Piscina y playa','Rooftop pool open 8 AM – 10 PM. Beach towels and two chairs are in the hall closet.','Piscina en la azotea de 8 AM a 10 PM. Toallas de playa y dos sillas en el clóset del pasillo.','🏖️',8);

  insert into amenities (organization_id, name, name_es, description, description_es, icon, hours, location, sort_order) values
  (ps,'Rooftop pool','Piscina en la azotea','Heated pool with ocean views and loungers.','Piscina climatizada con vista al mar.','🏊','8 AM – 10 PM','Rooftop, level 20',1),
  (ps,'Fitness center','Gimnasio','Cardio machines, free weights and yoga mats.','Máquinas de cardio, pesas y colchonetas.','💪','24 hours','Level 2',2),
  (ps,'Beach gear','Equipo de playa','Towels, two chairs and an umbrella.','Toallas, dos sillas y una sombrilla.','⛱️',null,'Hall closet',3),
  (ps,'Washer & dryer','Lavadora y secadora','In-unit, detergent provided.','En el apartamento, con detergente.','🧺',null,'Laundry closet',4),
  (ps,'Bikes','Bicicletas','Two city bikes with locks, free for guests.','Dos bicicletas con candado, gratis.','🚲','7 AM – 9 PM','Garage P1',5),
  (ps,'Workspace','Espacio de trabajo','Desk, monitor and fast Wi-Fi.','Escritorio, monitor y Wi-Fi rápido.','💻',null,'Second bedroom',6);

  insert into local_places (organization_id, category, name, description, description_es, address, price_level, distance_note, hours, featured, sort_order) values
  (ps,'coffee','Morning Brew','Best flat white on the block, great pastries.','El mejor flat white de la zona.','1820 Collins Ave',2,'0.3 mi · 6 min walk','7 AM – 4 PM',true,1),
  (ps,'eat','Casa Mare','Italian seafood, ask for a terrace table at sunset.','Mariscos italianos, pide terraza al atardecer.','2100 Collins Ave',3,'0.7 mi','6 PM – 11 PM',true,2),
  (ps,'eat','Taquería Sol','Casual tacos and fresh juices, kid friendly.','Tacos y jugos naturales, ideal con niños.','1650 Washington Ave',1,'0.4 mi','11 AM – 10 PM',false,3),
  (ps,'beach','Beach access 21st St','Lifeguard tower, showers and chair rentals.','Salvavidas, duchas y alquiler de sillas.','21st St & Collins',null,'5 min walk','Lifeguard 9 AM – 5 PM',true,4),
  (ps,'nightlife','The Rooftop Bar','Cocktails with skyline views.','Cócteles con vista a la ciudad.','1901 Collins Ave',3,'0.4 mi','5 PM – 1 AM',false,5),
  (ps,'explore','Art Deco walking tour','90-minute guided tour of the historic district.','Tour guiado de 90 minutos por el distrito histórico.','1001 Ocean Dr',2,'1.2 mi','Daily 10:30 AM',false,6),
  (ps,'essentials','Publix Supermarket','Groceries, pharmacy and ready meals.','Supermercado, farmacia y comida lista.','1920 West Ave',null,'0.6 mi','7 AM – 10 PM',false,7),
  (ps,'essentials','CVS Pharmacy','Open 24 hours.','Abierta 24 horas.','1421 Alton Rd',null,'0.9 mi','24 hours',false,8);

  insert into checkout_steps (organization_id, text, text_es, sort_order) values
  (ps,'Start the dishwasher and take out the trash.','Enciende el lavavajillas y saca la basura.',1),
  (ps,'Leave used towels in the bathtub.','Deja las toallas usadas en la bañera.',2),
  (ps,'Turn off the AC and close the balcony door.','Apaga el aire y cierra la puerta del balcón.',3),
  (ps,'Leave the parking pass on the kitchen counter.','Deja el pase de estacionamiento en la cocina.',4),
  (ps,'The door locks automatically when you leave.','La puerta se cierra sola al salir.',5);

  insert into emergency_contacts (organization_id, label, label_es, value, kind, sort_order) values
  (ps,'Emergency services','Emergencias','911','phone',1),
  (ps,'Nearest ER · Mount Sinai Medical Center','Urgencias · Mount Sinai Medical Center','4300 Alton Rd · 1.2 mi','address',2),
  (ps,'Building security','Seguridad del edificio','(305) 555-0142','phone',3),
  (ps,'Fire exits','Salidas de emergencia','End of each hallway','other',4);

  update properties set luggage_note = 'Luggage can stay at the front desk until 4 PM.', luggage_note_es = 'Puedes dejar el equipaje en recepción hasta las 4 PM.',
                        late_checkout_note = 'Late checkout until 1 PM when available: ask in the chat.', late_checkout_note_es = 'Salida tardía hasta la 1 PM si hay disponibilidad: pregunta en el chat.'
  where organization_id = ps and luggage_note is null;
end if;

-- ============================== CASA SOL (Cartagena) ==============================
if not exists (select 1 from guide_sections where organization_id = cs) then
  insert into guide_sections (organization_id, category, title, title_es, body, body_es, icon, sort_order) values
  (cs,'arrival','Arriving','Llegada','Check-in from 3 PM. Luis will meet you at the door or leave the keys in the lockbox.','La entrada es desde las 3 PM. Luis te recibe en la puerta o deja las llaves en la caja de seguridad.','🔑',1),
  (cs,'wifi','Wi-Fi','Wi-Fi','Network and password are on your Home screen.','La red y la clave están en tu Inicio.','📶',2),
  (cs,'house_rules','House rules','Normas de la casa','No smoking indoors. Quiet hours 10 PM – 8 AM. Please save water.','No fumar adentro. Silencio de 10 PM a 8 AM. Por favor cuida el agua.','📋',3),
  (cs,'kitchen','Kitchen','Cocina','Coffee maker, blender and basic spices. Bottled water in the fridge on arrival.','Cafetera, licuadora y especias básicas. Agua en la nevera a tu llegada.','🍳',4);
  insert into amenities (organization_id, name, name_es, icon, hours, location, sort_order) values
  (cs,'Plunge pool','Piscina','🏊','8 AM – 9 PM','Terraza',1),
  (cs,'Air conditioning','Aire acondicionado','❄️',null,'Todas las habitaciones',2),
  (cs,'Beach towels','Toallas de playa','🏖️',null,'Clóset',3);
  insert into local_places (organization_id, category, name, description_es, address, price_level, distance_note, featured, sort_order) values
  (cs,'eat','La Cevichería','El ceviche más famoso del centro histórico.','Calle Stuart 7-14',2,'10 min a pie',true,1),
  (cs,'coffee','Época Café','Café de origen colombiano y postres.','Calle del Espíritu Santo',1,'5 min a pie',false,2),
  (cs,'beach','Playa Blanca','Excursión en lancha desde el muelle La Bodeguita.','Muelle La Bodeguita',2,'45 min en lancha',true,3),
  (cs,'nightlife','Café del Mar','Atardecer sobre la muralla.','Baluarte de Santo Domingo',3,'12 min a pie',false,4);
  insert into checkout_steps (organization_id, text, text_es, sort_order) values
  (cs,'Leave the keys in the lockbox.','Deja las llaves en la caja de seguridad.',1),
  (cs,'Turn off the AC and lights.','Apaga el aire y las luces.',2);
  insert into emergency_contacts (organization_id, label, label_es, value, kind, sort_order) values
  (cs,'Emergencies','Emergencias','123','phone',1),
  (cs,'Tourist police','Policía de turismo','+57 605 660 0000','phone',2);
end if;

-- Check-in timeline on demo reservations that are already in house.
update reservations set id_verified_at = coalesce(id_verified_at, (check_in - 2)::timestamptz + interval '10 hours'),
                        code_sent_at   = coalesce(code_sent_at,   check_in::timestamptz + interval '14 hours'),
                        checked_in_at  = coalesce(checked_in_at,  check_in::timestamptz + interval '15 hours 12 minutes')
where organization_id in (ps, cs) and check_in <= current_date and check_out > current_date and status <> 'cancelled';
end $$;
