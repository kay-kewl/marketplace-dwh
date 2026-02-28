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
                link_defs = self._build_link_defs(table)
                link_target = link_defs[0]['target'] if link_defs else None
                
                conf = {
                    "source_name": source_name,
                    "business_key": table.get('business_key') or table.get("business_key_ref"),
                    "hub_target": table.get("hub") or table.get("hub_ref"),
                    "sat_target": table.get("satellite") or table.get("sat"),
                    "link_target": link_target,
                    "link_defs": link_defs,
                    "attributes": [
                        a['name'] for a in table.get('attributes', []) if a['name'] not in ATTRIBUTES
                    ],
                    "link_parents": []
                }

                if link_defs:
                    conf["link_parents"] = link_defs[0].get('parents', [])

                self.topics[topic] = conf

    def _build_link_defs(self, table):
        link_defs = []
        single_link = table.get("link")
        if single_link:
            parents = []
            hub_refs = table.get("hub_refs", [])
            business_keys = table.get('business_keys', {})

            if isinstance(hub_refs, dict):
                for key, hub in hub_refs.items():
                    field = business_keys.get(key) if isinstance(business_keys, dict) else None
                    if not field:
                        field = key
                    parents.append({
                        "hub": hub,
                        "field": field
                    })
            elif isinstance(hub_refs, list):
                for item in hub_refs:
                    parents.append({
                        "hub": item.get("hub"),
                        "field": item.get("field") or item.get("bk_field")
                    })

            link_defs.append({
                "target": single_link,
                "parents": parents
            })

        if table.get("links"):
            source_hub = table.get("hub") or table.get("hub_ref")
            source_field = table.get("business_key") or table.get("business_key_ref")

            for link in table.get("links", []):
                target = link.get("name")
                hub_left = link.get("hub_left")
                hub_right = link.get("hub_right")
                if not target or not hub_left or not hub_right:
                    continue

                parent_left_field = source_field if hub_left == source_hub else None
                parent_right_field = source_field if hub_right == source_hub else None

                link_defs.append({
                    "target": target,
                    "parents": [
                        {"hub": hub_left, "field": parent_left_field},
                        {"hub": hub_right, "field": parent_right_field}
                    ]
                })

        return link_defs

    def get_conf(self, topic: str):
        return self.topics.get(topic)
    
    def get_topics(self):
        return list(self.topics.keys())
    