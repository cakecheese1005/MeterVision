CREATE TABLE officer_assignments (

    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),

    officer_id UUID NOT NULL
        REFERENCES users(id)
        ON DELETE CASCADE,

    consumer_id UUID NOT NULL
        REFERENCES consumers(id)
        ON DELETE CASCADE,

    assigned_by UUID
        REFERENCES users(id)
        ON DELETE SET NULL,

    assigned_at TIMESTAMPTZ DEFAULT NOW(),

    is_active BOOLEAN DEFAULT TRUE,

    UNIQUE(officer_id, consumer_id)
);

CREATE INDEX idx_assignment_officer
ON officer_assignments(officer_id);

CREATE INDEX idx_assignment_consumer
ON officer_assignments(consumer_id);