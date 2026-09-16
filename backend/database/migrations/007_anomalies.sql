CREATE TABLE anomalies (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    reading_id UUID NOT NULL
        REFERENCES meter_readings(id)
        ON DELETE CASCADE,

    anomaly_type VARCHAR(50) NOT NULL,

    reason TEXT,

    severity VARCHAR(20)
        CHECK (
            severity IN (
                'low',
                'medium',
                'high'
            )
        ),

    status VARCHAR(20)
        DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'resolved'
            )
        ),

    detected_by VARCHAR(20)
        DEFAULT 'ai'
        CHECK (
            detected_by IN (
                'ai',
                'system',
                'manual'
            )
        ),

    created_at TIMESTAMPTZ DEFAULT NOW(),

    resolved_at TIMESTAMPTZ
);

CREATE INDEX idx_anomaly_reading
ON anomalies(reading_id);

CREATE INDEX idx_anomaly_status
ON anomalies(status);

CREATE INDEX idx_anomaly_severity
ON anomalies(severity);