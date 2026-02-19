import json 
from dataclasses import dataclass
from typing import Optional, Any

@dataclass
class ParsedMessage:
    topic: str
    partition: int
    offset: int
    key_bytes: Optional[bytes]
    value_bytes: Optional[bytes]
    key_json: Optional[dict]
    payload: Optional[dict]
    op: Optional[str]
    ts_ms: Optional[int]
    error: Optional[str] = None

def parse_message(msg) -> ParsedMessage:
    key_bytes = msg.key()
    value_bytes = msg.value()

    pm = ParsedMessage(
        topic=msg.topic(),
        partition=msg.partition(),
        offset=msg.offset(),
        key_bytes=key_bytes,
        value_bytes=value_bytes,
        key_json=None,
        payload=None,
        op=None,
        ts_ms=None,
    )

    try:
        if key_bytes:
            pm.key_json = json.loads(key_bytes.decode('utf-8'))
        if value_bytes:
            value_json = json.loads(value_bytes.decode('utf-8'))
            payload = value_json.get('payload', value_json)

            pm.payload = payload
            if payload:
                pm.op = payload.get('op')
                src = payload.get('source', {})
                pm.ts_ms = src.get('ts_ms') or payload.get('ts_ms')

    except Exception as e:
        pm.error = str(e)

    return pm