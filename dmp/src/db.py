import json
import logging
import time
import base64
from decimal import Decimal
from datetime import datetime, timezone, date, timedelta
import psycopg2
from psycopg2 import sql
from psycopg2.extras import execute_values

logger = logging.getLogger(__name__)


def normalize_value(value, attribute_name=None):
    if attribute_name:
        attribute = attribute_name.lower()
        numeric_value = value
        if isinstance(value, str):
            stripped = value.strip()
            if stripped and stripped.lstrip('-').isdigit():
                numeric_value = int(stripped)

        if isinstance(numeric_value, (int, float, Decimal)):
            try:
                n = float(numeric_value)
                looks_like_date_only = (
                    attribute.endswith('_date') or attribute == 'date_of_birth' or
                    ('date' in attribute and not ('time' in attribute or 'datetime' in attribute 
                                                  or attribute.endswith('_at')))
                )

                looks_like_timestamp = (
                    attribute.endswith('_at') or attribute.endswith('_datetime') or 'time' in attribute
                    or 'datetime' in attribute or 'timestamp' in attribute or 'date' in attribute
                )

                if looks_like_date_only:
                    days = int(n)
                    if -200000 <= days <= 200000:
                        return date(1970, 1, 1) + timedelta(days=days)

                if looks_like_timestamp:
                    if abs(n) > 10 ** 14:
                        seconds = n / 1_000_000.0
                    elif abs(n) > 10 ** 11:
                        seconds = n / 1_000.0
                    elif abs(n) > 10 ** 9:
                        seconds = n
                    elif looks_like_date_only:
                        days = int(n)
                        return date(1970, 1, 1) + timedelta(days=days)
                    else:
                        seconds = n

                    dt = datetime.fromtimestamp(seconds, tz=timezone.utc).replace(tzinfo=None)
                    if looks_like_date_only:
                        return dt.date()

                    return dt
            except Exception:
                pass
        
        if isinstance(value, dict):
            if 'scale' in value and 'value' in value:
                try:
                    scale = int(value['scale'])
                    val = value['value']
                    if isinstance(val, str):
                        decoded = base64.b64decode(val)
                        unscaled = int.from_bytes(decoded, byteorder='big', signed=True)
                        return Decimal(unscaled).scaleb(-scale)
                except Exception:
                    return json.dumps(value, ensure_ascii=False)
            return json.dumps(value, ensure_ascii=False)

        if isinstance(value, list):
            return json.dumps(value, ensure_ascii=False)

        return value

class DBManager:
    def __init__(self, destination):
        self.destination = destination
        self.conn = None
        self._connect()

    def _connect(self):
        while not self.conn:
            try:
                self.conn = psycopg2.connect(self.destination)
                self.conn.autocommit = False
            except Exception as e:
                logger.error(f"Database connection failed: {e}. Retrying in 5 seconds...")
                time.sleep(5)

    def close(self):
        if self.conn:
            self.conn.close()
            self.conn = None

    def insert_records(self, current, items: list):
        if not items:
            return []

        q = """
            INSERT INTO dwh_detailed.stg_kafka_events 
            (topic, partition, "offset", kafka_ts_ms, key_bytes, value_bytes, payload_json, op, source_ts_ms, error_msg)
            VALUES %s
            ON CONFLICT (topic, partition, "offset") DO NOTHING
            RETURNING topic, partition, "offset"
        """

        rows = []
        for item in items:
            message = item['message']
            parsed = item['parsed']
            
            ts_info = message.timestamp()
            kafka_ts = ts_info[1] if ts_info and ts_info[1] and ts_info[1] > 0 else None
            rows.append((
                parsed.topic,
                parsed.partition,
                parsed.offset,
                kafka_ts,
                parsed.key_bytes,
                parsed.value_bytes,
                json.dumps(parsed.payload) if parsed.payload else None,
                parsed.op,
                parsed.ts_ms,
                parsed.error
            ))

        execute_values(current, q, rows, page_size=len(rows))
        return current.fetchall()
    
    def load_hub(self, current, table, bk_column, bk_value, source):
        if bk_value is None:
            return
        
        q = sql.SQL("""
            INSERT INTO dwh_detailed.{tbl} ({id_col}, {bk_col}, source_system_id)
            VALUES (dwh_detailed.md5_hash(%s), %s, dwh_detailed.get_source_id(%s))
            ON CONFLICT ({id_col}) DO NOTHING
        """).format(
            tbl=sql.Identifier(table),
            id_col=sql.Identifier(f"{table}_id"),
            bk_col=sql.Identifier(bk_column)
        )

        current.execute(q, (str(bk_value), bk_value, source))

    def load_link(self, current, table, parents, source):
        sorted_parents = sorted(parents, key=lambda x: x['hub'])
        columns, values, parameters, hash_parts = [], [], [], []
        for parent in sorted_parents:
            if parent['val'] is None:
                return None
            
            columns.append(sql.Identifier(f"{parent['hub']}_id"))
            values.append(sql.SQL("dwh_detailed.md5_hash(%s)"))
            parameters.append(str(parent['val']))
            hash_parts.append({"h": parent['hub'], "v": str(parent['val'])})

        link_hk_json = json.dumps(hash_parts, separators=(',', ':'))

        columns.append(sql.Identifier(f"{table}_id"))
        values.append(sql.SQL("dwh_detailed.md5_hash(%s)"))
        parameters.append(link_hk_json)

        columns.append(sql.Identifier("source_system_id"))
        values.append(sql.SQL("dwh_detailed.get_source_id(%s)"))
        parameters.append(source)

        q = sql.SQL("""
            INSERT INTO dwh_detailed.{tbl} ({cols})
            VALUES ({vals})
            ON CONFLICT ({id_col}) DO NOTHING
        """).format(
            tbl=sql.Identifier(table),
            cols=sql.SQL(', ').join(columns),
            vals=sql.SQL(', ').join(values),
            id_col=sql.Identifier(f"{table}_id")
        )

        current.execute(q, parameters)
        return link_hk_json

    def load_satellite(self, current, table, hub, hub_bk, source, attributes, row, is_deleted):
        if hub_bk is None:
            return
        
        attribute_values = [row.get(attr) for attr in attributes]
        hash_input = json.dumps(attribute_values + [is_deleted], default=str)
        
        columns = [
            sql.Identifier(f"{hub}_id"), sql.Identifier("source_system_id"), sql.Identifier("hash_diff"), 
            sql.Identifier("effective_from")
        ]

        values = [
            sql.SQL("dwh_detailed.md5_hash(%s)"), sql.SQL("dwh_detailed.get_source_id(%s)"), 
            sql.SQL("dwh_detailed.md5_hash(%s)"), sql.SQL("NOW()")
        ]

        parameters = [str(hub_bk), source, hash_input]

        for attribute, value in zip(attributes, attribute_values):
            value = normalize_value(value, attribute)
            columns.append(sql.Identifier(attribute))
            values.append(sql.SQL("%s"))
            parameters.append(value)

        q = sql.SQL("""
            INSERT INTO dwh_detailed.{tbl} ({cols})
            VALUES ({vals})
        """).format(
            tbl=sql.Identifier(table),
            cols=sql.SQL(', ').join(columns),
            vals=sql.SQL(', ').join(values),
        )

        current.execute(q, parameters)
        