-- 002: booking_events (audit trail per booking)
CREATE TABLE IF NOT EXISTS booking_events (
    id          BIGSERIAL     PRIMARY KEY,
    booking_id  UUID          NOT NULL REFERENCES hotel_bookings(id),
    event_type  VARCHAR(100)  NOT NULL,
    payload     JSONB,
    created_at  TIMESTAMP     NOT NULL
);

-- Fetching the history of one booking is the typical access pattern,
-- and Postgres does not index foreign keys automatically.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);
