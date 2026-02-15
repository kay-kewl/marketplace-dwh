
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
