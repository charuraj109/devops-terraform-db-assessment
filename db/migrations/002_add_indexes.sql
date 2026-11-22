-- Covering index for the "city + last 30 days, grouped by org/status" query.
-- city (equality) first, created_at (range) second, then INCLUDE the columns the
-- query reads so Postgres can answer it with an index-only scan.
CREATE INDEX IF NOT EXISTS idx_hotel_bookings_city_created_cover
    ON hotel_bookings (city, created_at)
    INCLUDE (org_id, status, amount);

-- Lookup of events by booking.
CREATE INDEX IF NOT EXISTS idx_booking_events_booking_id
    ON booking_events (booking_id);

VACUUM ANALYZE hotel_bookings;
VACUUM ANALYZE booking_events;
