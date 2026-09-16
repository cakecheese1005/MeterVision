CREATE TABLE consumers (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    consumer_number VARCHAR(30) UNIQUE NOT NULL,

    account_number VARCHAR(30) UNIQUE,

    consumer_name VARCHAR(150) NOT NULL,

    address TEXT NOT NULL,

    phone_number VARCHAR(20),

    meter_number VARCHAR(50) UNIQUE NOT NULL,

    meter_type VARCHAR(30) NOT NULL
        CHECK (meter_type IN ('digital', 'electromechanical')),

    subdivision VARCHAR(100),

    feeder VARCHAR(100),

    cycle VARCHAR(50),

    previous_reading NUMERIC(10,2) DEFAULT 0,

    is_active BOOLEAN DEFAULT TRUE,

    created_at TIMESTAMPTZ DEFAULT NOW(),

    updated_at TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX idx_consumers_consumer_number
ON consumers(consumer_number);

CREATE INDEX idx_consumers_meter_number
ON consumers(meter_number);

CREATE INDEX idx_consumers_subdivision
ON consumers(subdivision);