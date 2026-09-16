-- ============================================================
-- MeterVision / PSPCL Development Seed Data
-- ============================================================
-- RUN THIS AFTER ALL 11 MIGRATION FILES.
--
-- DEVELOPMENT / TEST DATA ONLY.
--
-- Test credentials:
--
-- seed.admin@pspcl.com  -> Admin@123
-- officer@pspcl.com     -> Officer@123
-- lcr@pspcl.com         -> Lcr@123
--
-- Passwords are generated using PostgreSQL pgcrypto/bcrypt.
-- ============================================================


CREATE EXTENSION IF NOT EXISTS pgcrypto;


BEGIN;


-- ============================================================
-- 1. USERS
-- ============================================================

INSERT INTO users (
    id,
    name,
    email,
    password_hash,
    role,
    phone_number,
    is_active
)
VALUES

(
    '11111111-1111-4111-8111-111111111111',
    'Seed Admin',
    'seed.admin@pspcl.com',
    crypt('Admin@123', gen_salt('bf')),
    'admin',
    '9876500001',
    TRUE
),

(
    '22222222-2222-4222-8222-222222222222',
    'Rajesh Kumar',
    'officer@pspcl.com',
    crypt('Officer@123', gen_salt('bf')),
    'officer',
    '9876500002',
    TRUE
),

(
    '33333333-3333-4333-8333-333333333333',
    'Simran Kaur',
    'lcr@pspcl.com',
    crypt('Lcr@123', gen_salt('bf')),
    'lcr',
    '9876500003',
    TRUE
)

ON CONFLICT (email) DO UPDATE SET
    name = EXCLUDED.name,
    password_hash = EXCLUDED.password_hash,
    role = EXCLUDED.role,
    phone_number = EXCLUDED.phone_number,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();


-- ============================================================
-- 2. CONSUMERS
-- ============================================================

INSERT INTO consumers (
    id,
    consumer_number,
    account_number,
    consumer_name,
    address,
    phone_number,
    meter_number,
    meter_type,
    subdivision,
    feeder,
    cycle,
    previous_reading,
    is_active
)
VALUES

(
    '44444444-4444-4444-8444-444444444441',
    'PSPCL-C-0001',
    'ACC-10001',
    'Harpreet Singh',
    'Model Town, Ludhiana, Punjab',
    '9876501001',
    'MTR-D-0001',
    'digital',
    'Ludhiana Central',
    'Feeder-LDH-01',
    'Monthly',
    12450.00,
    TRUE
),

(
    '44444444-4444-4444-8444-444444444442',
    'PSPCL-C-0002',
    'ACC-10002',
    'Neha Sharma',
    'Civil Lines, Ludhiana, Punjab',
    '9876501002',
    'MTR-D-0002',
    'digital',
    'Ludhiana Central',
    'Feeder-LDH-02',
    'Monthly',
    8750.00,
    TRUE
),

(
    '44444444-4444-4444-8444-444444444443',
    'PSPCL-C-0003',
    'ACC-10003',
    'Gurpreet Singh',
    'Gill Road, Ludhiana, Punjab',
    '9876501003',
    'MTR-E-0003',
    'electromechanical',
    'Ludhiana South',
    'Feeder-LDH-03',
    'Monthly',
    21980.00,
    TRUE
),

(
    '44444444-4444-4444-8444-444444444444',
    'PSPCL-C-0004',
    'ACC-10004',
    'Amanpreet Kaur',
    'Dugri, Ludhiana, Punjab',
    '9876501004',
    'MTR-D-0004',
    'digital',
    'Ludhiana South',
    'Feeder-LDH-04',
    'Monthly',
    15320.00,
    TRUE
)

ON CONFLICT (consumer_number) DO UPDATE SET
    consumer_name = EXCLUDED.consumer_name,
    address = EXCLUDED.address,
    phone_number = EXCLUDED.phone_number,
    meter_number = EXCLUDED.meter_number,
    meter_type = EXCLUDED.meter_type,
    subdivision = EXCLUDED.subdivision,
    feeder = EXCLUDED.feeder,
    cycle = EXCLUDED.cycle,
    previous_reading = EXCLUDED.previous_reading,
    is_active = EXCLUDED.is_active,
    updated_at = NOW();


-- ============================================================
-- 3. OFFICER ASSIGNMENTS
-- ============================================================

INSERT INTO officer_assignments (
    id,
    officer_id,
    consumer_id,
    assigned_by,
    is_active
)
VALUES

(
    '88888888-8888-4888-8888-888888888881',
    '22222222-2222-4222-8222-222222222222',
    '44444444-4444-4444-8444-444444444441',
    '11111111-1111-4111-8111-111111111111',
    TRUE
),

(
    '88888888-8888-4888-8888-888888888882',
    '22222222-2222-4222-8222-222222222222',
    '44444444-4444-4444-8444-444444444442',
    '11111111-1111-4111-8111-111111111111',
    TRUE
),

(
    '88888888-8888-4888-8888-888888888883',
    '22222222-2222-4222-8222-222222222222',
    '44444444-4444-4444-8444-444444444443',
    '11111111-1111-4111-8111-111111111111',
    TRUE
),

(
    '88888888-8888-4888-8888-888888888884',
    '22222222-2222-4222-8222-222222222222',
    '44444444-4444-4444-8444-444444444444',
    '11111111-1111-4111-8111-111111111111',
    TRUE
)

ON CONFLICT (officer_id, consumer_id) DO UPDATE SET
    assigned_by = EXCLUDED.assigned_by,
    is_active = EXCLUDED.is_active;


-- ============================================================
-- 4. METER READINGS
-- ============================================================

INSERT INTO meter_readings (
    id,
    consumer_id,
    officer_id,
    reading_value,
    previous_reading,
    units_consumed,
    latitude,
    longitude,
    reading_status,
    captured_at
)
VALUES

(
    '55555555-5555-4555-8555-555555555551',
    '44444444-4444-4444-8444-444444444441',
    '22222222-2222-4222-8222-222222222222',
    12620.00,
    12450.00,
    170.00,
    30.9010000,
    75.8573000,
    'completed',
    NOW() - INTERVAL '5 days'
),

(
    '55555555-5555-4555-8555-555555555552',
    '44444444-4444-4444-8444-444444444442',
    '22222222-2222-4222-8222-222222222222',
    9015.00,
    8750.00,
    265.00,
    30.9040000,
    75.8500000,
    'review',
    NOW() - INTERVAL '3 days'
),

(
    '55555555-5555-4555-8555-555555555553',
    '44444444-4444-4444-8444-444444444443',
    '22222222-2222-4222-8222-222222222222',
    22110.00,
    21980.00,
    130.00,
    30.8870000,
    75.8450000,
    'pending',
    NOW() - INTERVAL '1 day'
),

(
    '55555555-5555-4555-8555-555555555554',
    '44444444-4444-4444-8444-444444444444',
    '22222222-2222-4222-8222-222222222222',
    15500.00,
    15320.00,
    180.00,
    30.8800000,
    75.8300000,
    'rejected',
    NOW() - INTERVAL '7 days'
);


-- ============================================================
-- 5. METER IMAGES
-- ============================================================

INSERT INTO meter_images (
    id,
    reading_id,
    image_url,
    blur_score,
    image_quality,
    ai_classification
)
VALUES

(
    '66666666-6666-4666-8666-666666666661',
    '55555555-5555-4555-8555-555555555551',
    'https://example.com/meter-images/reading-001.jpg',
    245.70,
    'ok',
    'Image Okay Digital Meter'
),

(
    '66666666-6666-4666-8666-666666666662',
    '55555555-5555-4555-8555-555555555552',
    'https://example.com/meter-images/reading-002.jpg',
    82.40,
    'blur',
    'Blur Image Digital Meter'
),

(
    '66666666-6666-4666-8666-666666666663',
    '55555555-5555-4555-8555-555555555553',
    'https://example.com/meter-images/reading-003.jpg',
    198.20,
    'ok',
    'Image Okay Electro Mechanical Meter'
),

(
    '66666666-6666-4666-8666-666666666664',
    '55555555-5555-4555-8555-555555555554',
    'https://example.com/meter-images/reading-004.jpg',
    64.10,
    'reflection',
    'Reflection Digital Meter'
);


-- ============================================================
-- 6. OCR RESULTS
-- ============================================================

INSERT INTO ocr_results (
    id,
    reading_id,
    predicted_reading,
    confidence,
    status,
    model_version,
    processing_time_ms
)
VALUES

(
    '77777777-7777-4777-8777-777777777771',
    '55555555-5555-4555-8555-555555555551',
    '12620',
    0.98,
    'success',
    'meter-ocr-v1.0',
    420
),

(
    '77777777-7777-4777-8777-777777777772',
    '55555555-5555-4555-8555-555555555552',
    '9015',
    0.61,
    'low_confidence',
    'meter-ocr-v1.0',
    510
),

(
    '77777777-7777-4777-8777-777777777773',
    '55555555-5555-4555-8555-555555555553',
    '22110',
    0.93,
    'success',
    'meter-ocr-v1.0',
    455
),

(
    '77777777-7777-4777-8777-777777777774',
    '55555555-5555-4555-8555-555555555554',
    '15580',
    0.42,
    'failed',
    'meter-ocr-v1.0',
    620
);


-- ============================================================
-- 7. ANOMALIES
-- ============================================================

INSERT INTO anomalies (
    id,
    reading_id,
    anomaly_type,
    reason,
    severity,
    status,
    detected_by,
    resolved_at
)
VALUES

(
    '88888888-8888-4888-8888-888888888891',
    '55555555-5555-4555-8555-555555555552',
    'ocr_low_confidence',
    'OCR confidence is below the configured review threshold.',
    'medium',
    'pending',
    'ai',
    NULL
),

(
    '88888888-8888-4888-8888-888888888892',
    '55555555-5555-4555-8555-555555555554',
    'reading_mismatch',
    'OCR reading differs from the submitted meter reading.',
    'high',
    'pending',
    'ai',
    NULL
),

(
    '88888888-8888-4888-8888-888888888893',
    '55555555-5555-4555-8555-555555555551',
    'consumption_check',
    'Reading is within the expected range.',
    'low',
    'resolved',
    'system',
    NOW() - INTERVAL '4 days'
);


-- ============================================================
-- 8. LCR CASES
-- ============================================================

INSERT INTO lcr_cases (
    id,
    anomaly_id,
    reading_id,
    assigned_to,
    status,
    corrected_reading,
    remarks,
    reviewed_at
)
VALUES

(
    '99999999-9999-4999-8999-999999999991',
    '88888888-8888-4888-8888-888888888892',
    '55555555-5555-4555-8555-555555555554',
    '33333333-3333-4333-8333-333333333333',
    'pending',
    NULL,
    'Manual verification required because OCR and submitted reading differ.',
    NULL
),

(
    '99999999-9999-4999-8999-999999999992',
    '88888888-8888-4888-8888-888888888893',
    '55555555-5555-4555-8555-555555555551',
    '33333333-3333-4333-8333-333333333333',
    'approved',
    12620.00,
    'Reading verified during review.',
    NOW() - INTERVAL '4 days'
);


-- ============================================================
-- 9. NOTIFICATIONS
-- ============================================================

INSERT INTO notifications (
    id,
    user_id,
    title,
    message,
    notification_type,
    is_read
)
VALUES

(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa1',
    '22222222-2222-4222-8222-222222222222',
    'Reading Review Required',
    'Reading PSPCL-C-0002 requires manual review because OCR confidence is low.',
    'anomaly',
    FALSE
),

(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa2',
    '33333333-3333-4333-8333-333333333333',
    'LCR Case Assigned',
    'A meter reading discrepancy case has been assigned to you.',
    'lcr',
    FALSE
),

(
    'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaa3',
    '22222222-2222-4222-8222-222222222222',
    'Assignment Updated',
    'New consumers have been assigned to your field officer account.',
    'assignment',
    TRUE
);


-- ============================================================
-- 10. SYNC QUEUE
-- ============================================================

INSERT INTO sync_queue (
    id,
    reading_id,
    device_id,
    sync_status,
    retry_count,
    last_attempt,
    synced_at
)
VALUES

(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb1',
    '55555555-5555-4555-8555-555555555551',
    'ANDROID-OFFICER-001',
    'success',
    1,
    NOW() - INTERVAL '5 days',
    NOW() - INTERVAL '5 days'
),

(
    'bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbb2',
    '55555555-5555-4555-8555-555555555552',
    'ANDROID-OFFICER-001',
    'pending',
    0,
    NULL,
    NULL
);


-- ============================================================
-- 11. AUDIT LOGS
-- ============================================================

INSERT INTO audit_logs (
    id,
    user_id,
    action,
    entity_type,
    entity_id,
    description,
    ip_address
)
VALUES

(
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc1',
    '11111111-1111-4111-8111-111111111111',
    'login',
    'user',
    '11111111-1111-4111-8111-111111111111',
    'Development admin login.',
    '127.0.0.1'
),

(
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc2',
    '22222222-2222-4222-8222-222222222222',
    'create',
    'meter_reading',
    '55555555-5555-4555-8555-555555555551',
    'Meter reading submitted by field officer.',
    '127.0.0.1'
),

(
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc3',
    '11111111-1111-4111-8111-111111111111',
    'approve',
    'lcr_case',
    '99999999-9999-4999-8999-999999999992',
    'Development LCR case approved.',
    '127.0.0.1'
),

(
    'cccccccc-cccc-4ccc-8ccc-ccccccccccc4',
    '33333333-3333-4333-8333-333333333333',
    'update',
    'lcr_case',
    '99999999-9999-4999-8999-999999999992',
    'LCR verification completed.',
    '127.0.0.1'
);


COMMIT;


-- ============================================================
-- VERIFICATION
-- ============================================================

SELECT 'users' AS table_name, COUNT(*) AS row_count
FROM users

UNION ALL

SELECT 'consumers', COUNT(*)
FROM consumers

UNION ALL

SELECT 'officer_assignments', COUNT(*)
FROM officer_assignments

UNION ALL

SELECT 'meter_readings', COUNT(*)
FROM meter_readings

UNION ALL

SELECT 'meter_images', COUNT(*)
FROM meter_images

UNION ALL

SELECT 'ocr_results', COUNT(*)
FROM ocr_results

UNION ALL

SELECT 'anomalies', COUNT(*)
FROM anomalies

UNION ALL

SELECT 'lcr_cases', COUNT(*)
FROM lcr_cases

UNION ALL

SELECT 'notifications', COUNT(*)
FROM notifications

UNION ALL

SELECT 'sync_queue', COUNT(*)
FROM sync_queue

UNION ALL

SELECT 'audit_logs', COUNT(*)
FROM audit_logs;