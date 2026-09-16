CREATE TABLE ocr_results (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    reading_id UUID NOT NULL UNIQUE
        REFERENCES meter_readings(id)
        ON DELETE CASCADE,

    predicted_reading VARCHAR(30),

    confidence DECIMAL(5,4),

    status VARCHAR(30)
        NOT NULL
        CHECK (
            status IN (
                'success',
                'failed',
                'low_confidence',
                'verified'
            )
        ),

    model_version VARCHAR(50),

    classification VARCHAR(100),

    processing_time_ms INTEGER,

    verification_remarks TEXT,

    processed_at TIMESTAMPTZ DEFAULT NOW()
);


CREATE INDEX idx_ocr_reading
ON ocr_results(reading_id);


CREATE INDEX idx_ocr_status
ON ocr_results(status);