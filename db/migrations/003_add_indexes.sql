-- 003: index for the dashboard query
--
--   SELECT org_id, status, COUNT(*), SUM(amount)
--   FROM hotel_bookings
--   WHERE city = 'delhi' AND created_at >= NOW() - INTERVAL '30 days'
--   GROUP BY org_id, status;
--
-- Key columns : (city, created_at)
--     city        -> equality filter, goes FIRST
--     created_at  -> range filter, goes SECOND (one contiguous slice of the index)
-- INCLUDE     : (org_id, status, amount)
--     extra columns the query reads for GROUP BY / SUM, so Postgres can
--     answer from the index alone (Index Only Scan) without touching the table.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_at
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);
