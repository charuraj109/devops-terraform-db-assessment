-- Seed: 100,000 bookings across 8 cities, 4 orgs, 4 statuses, spread over 90 days.
-- Large enough that the planner actually benefits from the index.
SELECT setseed(0.42);

INSERT INTO hotel_bookings
    (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
SELECT id, org_id, hotel_id, city,
       checkin, checkin + stay, amount, status, created_at
FROM (
    SELECT id, org_id, hotel_id, city, status, amount, created_at,
           (created_at::date + (1 + floor(random() * 60))::int) AS checkin,
           (1 + floor(random() * 6))::int                       AS stay
    FROM (
        SELECT gen_random_uuid() AS id,
               (ARRAY['11111111-1111-1111-1111-111111111111',
                      '22222222-2222-2222-2222-222222222222',
                      '33333333-3333-3333-3333-333333333333',
                      '44444444-4444-4444-4444-444444444444']::uuid[])[1 + floor(random() * 4)::int] AS org_id,
               'HTL-' || lpad((1 + floor(random() * 250))::int::text, 4, '0') AS hotel_id,
               (ARRAY['delhi','mumbai','bengaluru','pune','goa','jaipur','chennai','kolkata'])[1 + floor(random() * 8)::int] AS city,
               (ARRAY['confirmed','pending','cancelled','completed'])[1 + floor(random() * 4)::int] AS status,
               round((1500 + random() * 48500)::numeric, 2) AS amount,
               (now() - random() * interval '90 days')::timestamp AS created_at
        FROM generate_series(1, 100000)
    ) b
) s;

-- Every booking gets a creation event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'booking_created',
       jsonb_build_object('city', city, 'amount', amount, 'source', 'web'),
       created_at
FROM hotel_bookings;

-- Non-pending bookings get a status-change event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'status_changed',
       jsonb_build_object('from', 'pending', 'to', status),
       created_at + interval '10 minutes'
FROM hotel_bookings
WHERE status <> 'pending';

-- Cancelled bookings get a refund event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id, 'refund_issued',
       jsonb_build_object('refund_amount', amount),
       created_at + interval '1 day'
FROM hotel_bookings
WHERE status = 'cancelled';

ANALYZE hotel_bookings;
ANALYZE booking_events;
