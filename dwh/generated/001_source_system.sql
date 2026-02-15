
CREATE TABLE IF NOT EXISTS dwh_detailed.source_system (
    source_system_id BIGINT PRIMARY KEY,
    source_code VARCHAR(50) NOT NULL,
    source_name VARCHAR(100) NOT NULL,
    source_description VARCHAR(500),
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP DEFAULT NOW(),
    updated_at TIMESTAMP DEFAULT NOW(),
    CONSTRAINT uk_source_system_code UNIQUE(source_code)
);

CREATE INDEX IF NOT EXISTS idx_source_system_code 
    ON dwh_detailed.source_system(source_code);

INSERT INTO dwh_detailed.source_system (source_system_id, source_code, source_name, source_description)
SELECT 
    dwh_detailed.md5_hash(source_code),
    source_code,
    source_name,
    source_description
FROM (VALUES
    ('user_service', 'User Service', 'Сервис управления пользователями'),
    ('order_service', 'Order Service', 'Сервис обработки заказов'),
    ('logistics_service', 'Logistics Service', 'Сервис логистики')
) AS src(source_code, source_name, source_description)
ON CONFLICT (source_code) DO UPDATE SET
    source_name = EXCLUDED.source_name,
    source_description = EXCLUDED.source_description,
    updated_at = NOW();

CREATE OR REPLACE FUNCTION dwh_detailed.get_source_id(p_source_code VARCHAR)
RETURNS BIGINT AS $$
DECLARE
    v_source_id BIGINT;
BEGIN
    SELECT source_system_id INTO v_source_id
    FROM dwh_detailed.source_system
    WHERE source_code = p_source_code;
    RETURN v_source_id;
END;
$$ LANGUAGE plpgsql STABLE;
