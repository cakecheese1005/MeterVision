CREATE TABLE meter_images (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    reading_id UUID NOT NULL
        REFERENCES meter_readings(id)
        ON DELETE CASCADE,

    image_url TEXT NOT NULL,

    blur_score FLOAT,

    image_quality VARCHAR(30)
        CHECK (
            image_quality IN (
                'ok',
                'blur',
                'reflection',
                'irrelevant'
            )
        ),

    ai_classification TEXT,

    uploaded_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_images_reading
ON meter_images(reading_id);