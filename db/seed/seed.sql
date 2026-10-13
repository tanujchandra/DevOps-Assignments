-- Seed data: 20,000 bookings, 5 organizations, 5 cities, 4 statuses,
-- plus booking_events for every booking (extra events depend on status).
--
-- Why 20,000 and not 100?  The assignment asks for at least 100 rows, but on a
-- tiny table PostgreSQL correctly prefers a sequential scan. With 20,000 rows the
-- planner uses the new index, so the optimisation is visible in EXPLAIN.
-- To change the volume edit the generate_series upper bound below.
--
-- setseed() makes random() repeatable, so every run produces similar data.
-- Re-running this file is safe: it empties both tables first.

TRUNCATE booking_events, hotel_bookings RESTART IDENTITY;

SELECT setseed(0.42);

INSERT INTO hotel_bookings
    (id, org_id, hotel_id, city, checkin_date, checkout_date, amount, status, created_at)
WITH base AS MATERIALIZED (
    SELECT
        -- 5 organizations
        (ARRAY[
            '11111111-1111-1111-1111-111111111111',
            '22222222-2222-2222-2222-222222222222',
            '33333333-3333-3333-3333-333333333333',
            '44444444-4444-4444-4444-444444444444',
            '55555555-5555-5555-5555-555555555555'
        ]::uuid[])[1 + floor(random() * 5)::int]                         AS org_id,
        'HOTEL-' || lpad((1 + floor(random() * 20))::int::text, 3, '0')  AS hotel_id,
        -- delhi appears 3x as often so the report query has plenty of rows
        (ARRAY['delhi','delhi','delhi','mumbai','mumbai','bengaluru','goa','jaipur'])
            [1 + floor(random() * 8)::int]                               AS city,
        round((1500 + random() * 28500)::numeric, 2)                     AS amount,
        -- 4 statuses, weighted
        (ARRAY['CONFIRMED','CONFIRMED','COMPLETED','COMPLETED','PENDING','CANCELLED'])
            [1 + floor(random() * 6)::int]                               AS status,
        -- spread over the last 60 days, so ~half fall inside the 30-day window
        (NOW() - random() * interval '60 days')::timestamp               AS created_at,
        floor(random() * 30)::int                                        AS lead_days,
        1 + floor(random() * 5)::int                                     AS stay_nights
    FROM generate_series(1, 20000)
)
SELECT
    gen_random_uuid(),
    org_id,
    hotel_id,
    city,
    created_at::date + 1 + lead_days,
    created_at::date + 1 + lead_days + stay_nights,
    amount,
    status,
    created_at
FROM base;

-- Every booking gets a BOOKING_CREATED event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id,
       'BOOKING_CREATED',
       jsonb_build_object(
           'source', (ARRAY['web','mobile','api'])[1 + floor(random() * 3)::int],
           'amount', amount,
           'city',   city
       ),
       created_at
FROM hotel_bookings;

-- Paid bookings get a payment event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id,
       'PAYMENT_CAPTURED',
       jsonb_build_object('method', (ARRAY['card','upi','netbanking'])[1 + floor(random() * 3)::int],
                          'amount', amount),
       created_at + interval '5 minutes'
FROM hotel_bookings
WHERE status IN ('CONFIRMED', 'COMPLETED');

-- Completed stays have a check-in event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id,
       'GUEST_CHECKED_IN',
       jsonb_build_object('hotel_id', hotel_id),
       checkin_date::timestamp + interval '14 hours'
FROM hotel_bookings
WHERE status = 'COMPLETED';

-- Cancelled bookings have a cancellation event
INSERT INTO booking_events (booking_id, event_type, payload, created_at)
SELECT id,
       'BOOKING_CANCELLED',
       jsonb_build_object('reason', (ARRAY['customer_request','payment_failed','hotel_unavailable'])[1 + floor(random() * 3)::int]),
       created_at + interval '1 day'
FROM hotel_bookings
WHERE status = 'CANCELLED';

-- Refresh planner statistics and the visibility map so the index can be used
-- for Index Only Scans straight away.
VACUUM (ANALYZE) hotel_bookings;
VACUUM (ANALYZE) booking_events;
