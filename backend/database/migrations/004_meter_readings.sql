CREATE TABLE meter_readings (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    consumer_id UUID NOT NULL
        REFERENCES consumers(id)
        ON DELETE CASCADE,

    officer_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE SET NULL,

    reading_value NUMERIC(10,2) NOT NULL,

    previous_reading NUMERIC(10,2),

    units_consumed NUMERIC(10,2),

    latitude DECIMAL(10,7),

    longitude DECIMAL(10,7),

    reading_status VARCHAR(20)
        DEFAULT 'pending'
        CHECK (
            reading_status IN (
                'pending',
                'completed',
                'review',
                'rejected'
            )
        ),

    captured_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_readings_consumer
ON meter_readings(consumer_id);

CREATE INDEX idx_readings_officer
ON meter_readings(officer_id);

CREATE INDEX idx_readings_status
ON meter_readings(reading_status);