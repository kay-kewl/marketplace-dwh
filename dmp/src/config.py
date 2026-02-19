import yaml
import logging

logger = logging.getLogger(__name__)

ATTRIBUTES = {
    "effective_from",
    "effective_to",
    "is_current",
    "created_at",
    "updated_at",
    "created_by",
    "updated_by",
}

class ConfigLoader:
    def __init__(self, path: str):
        self.topics = {}
        with open(path, 'r', encoding='utf-8') as f:
            raw = yaml.safe_load(f)

        self._parse(raw)

    def _parse(self, raw):
        for source in raw.get('sources', []):
            source_name = source['name']
            for table in source.get('tables', []):
                topic = f"{source_name}.public.{table['name']}"
                
                conf = {
                    "source_name": source_name,
                    "business_key": table.get('business_key') or table.get("business_key_ref"),
                    "hub_target": table.get("hub") or table.get("hub_ref"),
                    "sat_target": table.get("satellite") or table.get("sat"),
                    "link_target": table.get("link"),
                    "attributes": [
                        a['name'] for a in table.get('attributes', []) if a['name'] not in ATTRIBUTES
                    ],
                    "link_parents": []
                }

                if conf['link_target']:
                    hub_refs = table.get('hub_refs', [])
                    business_keys = table.get('business_keys', {})
                    if isinstance(hub_refs, dict):
                        for key, hub in hub_refs.items():
                            field = business_keys.get(key) if isinstance(business_keys, dict) else None
                            if not field:
                                field = key
                            conf['link_parents'].append({
                                "hub": hub,
                                "field": field
                            })
                    elif isinstance(hub_refs, list):
                        for item in hub_refs:
                            conf['link_parents'].append({
                                "hub": item.get("hub"),
                                "field": item.get("field") or item.get("bk_field")
                            })

                self.topics[topic] = conf
                logger.info(f"Loaded config for topic {topic}: {conf}")

    def get_conf(self, topic: str):
        return self.topics.get(topic)
    
    def get_topics(self):
        return list(self.topics.keys())
    