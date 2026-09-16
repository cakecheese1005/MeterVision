CREATE TABLE lcr_cases (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    anomaly_id UUID
        REFERENCES anomalies(id)
        ON DELETE SET NULL,

    reading_id UUID NOT NULL
        REFERENCES meter_readings(id)
        ON DELETE CASCADE,

    assigned_to UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    status VARCHAR(30)
        DEFAULT 'pending'
        CHECK (
            status IN (
                'pending',
                'approved',
                'rejected',
                'revisit_required'
            )
        ),

    corrected_reading NUMERIC(10,2),

    remarks TEXT,

    reviewed_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_lcr_status
ON lcr_cases(status);

CREATE INDEX idx_lcr_user
ON lcr_cases(assigned_to);