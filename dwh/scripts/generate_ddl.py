import os
import subprocess

def generate_hash_functions():
    content = """
CREATE OR REPLACE FUNCTION dwh_detailed.md5_hash(input_text TEXT)
RETURNS BIGINT AS $$
DECLARE
    hash_bytes BYTEA;
    hash_int BIGINT;
BEGIN
    hash_bytes := DECODE(SUBSTRING(MD5(COALESCE(input_text, '')), 1, 16), 'hex');
    hash_int := (
        (GET_BYTE(hash_bytes, 0)::BIGINT << 56) |
        (GET_BYTE(hash_bytes, 1)::BIGINT << 48) |
        (GET_BYTE(hash_bytes, 2)::BIGINT << 40) |
        (GET_BYTE(hash_bytes, 3)::BIGINT << 32) |
        (GET_BYTE(hash_bytes, 4)::BIGINT << 24) |
        (GET_BYTE(hash_bytes, 5)::BIGINT << 16) |
        (GET_BYTE(hash_bytes, 6)::BIGINT << 8) |
        GET_BYTE(hash_bytes, 7)::BIGINT
    );
    RETURN hash_int;
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;

CREATE OR REPLACE FUNCTION dwh_detailed.calc_hash_diff(attributes TEXT[])
RETURNS BIGINT AS $$
DECLARE
    concat_text TEXT := '';
    elem TEXT;
BEGIN
    FOREACH elem IN ARRAY attributes
    LOOP
        IF concat_text = '' THEN
            concat_text := COALESCE(elem, '');
        ELSE
            concat_text := concat_text || '|' || COALESCE(elem, '');
        END IF;
    END LOOP;
    RETURN dwh_detailed.md5_hash(concat_text);
END;
$$ LANGUAGE plpgsql IMMUTABLE STRICT;
"""
    with open("dwh/generated/000_hash_functions.sql", "w", encoding='utf-8') as f:
        f.write(content)
        
def generate_source_system():
    content = """
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
"""
    with open("dwh/generated/001_source_system.sql", "w", encoding='utf-8') as f:
        f.write(content)
def main():
    os.makedirs("dwh/generated", exist_ok=True)
    os.makedirs("dwh/ddl", exist_ok=True)
    
    generate_hash_functions()
    generate_source_system()
    
    generators = [
        ("generate_hubs.py", "002_hubs.sql"),
        ("generate_links.py", "003_links.sql"),
        ("generate_satellites.py", "004_satellites.sql")
    ]
    
    for script, output_file in generators:
        script_path = f"dwh/scripts/{script}"
        if not os.path.exists(script_path):
            continue
        try:
            result = subprocess.run(
                ["python", script_path],
                capture_output=True,
                text=True,
                cwd="."
            )
        except Exception as e:
            print(f"  {script_path}: {e}")
    
    output_path = "dwh/ddl/001_dwh_schema.sql"
    with open(output_path, "w", encoding='utf-8') as outfile:
        outfile.write(f"""
BEGIN;

CREATE SCHEMA IF NOT EXISTS dwh_detailed;
SET search_path TO dwh_detailed, public;

""")
        
        sql_files = [
            "000_hash_functions.sql",
            "001_source_system.sql", 
            "002_hubs.sql",
            "003_links.sql",
            "004_satellites.sql"
        ]
        
        for filename in sql_files:
            filepath = f"dwh/generated/{filename}"
            if os.path.exists(filepath):
                with open(filepath, "r", encoding='utf-8') as infile:
                    outfile.write(f"-- {filename}\n")
                    outfile.write(infile.read())
                    outfile.write("\n")
            else:
                outfile.write(f"-- {filename} не найден, пропущен\n\n")
        
        outfile.write("""
COMMIT;
""")
    
if __name__ == "__main__":
    main()