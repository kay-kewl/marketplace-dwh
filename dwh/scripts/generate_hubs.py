import os
import yaml
from typing import Dict, Any, Set

class HubGenerator:
    def __init__(self, config_path: str):
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)
        self.hubs: Dict[str, Dict] = {}
        self._extract_hubs()
    
    def _extract_hubs(self):
        for source in self.config['sources']:
            for table in source['tables']:
                if 'hub' in table:
                    hub_name = table['hub']
                    self.hubs[hub_name] = {
                        'business_key': table['business_key'],
                        'key_type': table.get('business_key_type', 'VARCHAR(255)'),
                        'source': source['name'],
                        'description': table.get('description', f'Хаб для {hub_name}')
                    }
    
    def generate_hub_ddl(self, hub_name: str, config: Dict) -> str:
        business_key = config['business_key']
        key_type = config['key_type']
        description = config['description']
        
        ddl = f"""
CREATE TABLE IF NOT EXISTS dwh_detailed.{hub_name} (
    {hub_name}_id BIGINT PRIMARY KEY,
    {business_key} {key_type} NOT NULL,
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),
    
    CONSTRAINT fk_{hub_name}_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id),
    
    CONSTRAINT uk_{hub_name}_business_key 
        UNIQUE({business_key}, source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_{hub_name}_nk 
    ON dwh_detailed.{hub_name}({business_key});
    
CREATE INDEX IF NOT EXISTS idx_{hub_name}_source 
    ON dwh_detailed.{hub_name}(source_system_id);
"""
        return ddl
    
    def generate_all_hubs(self) -> str:
        output = ""
        for hub_name in sorted(self.hubs.keys()):
            output += self.generate_hub_ddl(hub_name, self.hubs[hub_name])
            output += "\n"
        
        return output

def main():
    os.makedirs("dwh/generated", exist_ok=True)
    
    generator = HubGenerator("dwh/docs/ddl_config.yaml")
    sql = generator.generate_all_hubs()
    
    output_path = "dwh/generated/002_hubs.sql"
    with open(output_path, "w", encoding='utf-8') as f:
        f.write(sql)

if __name__ == "__main__":
    main()