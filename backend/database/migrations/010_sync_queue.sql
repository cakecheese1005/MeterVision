CREATE TABLE sync_queue (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    reading_id UUID NOT NULL
        REFERENCES meter_readings(id)
        ON DELETE CASCADE,

    device_id VARCHAR(100),

    sync_status VARCHAR(20)
        DEFAULT 'pending'
        CHECK (
            sync_status IN (
                'pending',
                'success',
                'failed'
            )
        ),

    retry_count INTEGER DEFAULT 0,

    last_attempt TIMESTAMPTZ,

    synced_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_sync_status
ON sync_queue(sync_status);

CREATE INDEX idx_sync_reading
ON sync_queue(reading_id);