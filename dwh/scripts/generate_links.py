import os
import yaml
from typing import List, Dict, Any

class LinkGenerator:    
    def __init__(self, config_path: str):
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)
        self.links: List[Dict] = []
        self._extract_links()
    
    def _extract_links(self):
        for source in self.config['sources']:
            for table in source['tables']:
                if 'links' in table:
                    for link in table['links']:
                        link['source'] = source['name']
                        link['source_table'] = table['name']
                        self.links.append(link)
                if 'link' in table:
                    link_info = {
                        'name': table['link'],
                        'hub_left': table['hub_refs'].get(list(table['hub_refs'].keys())[0]),
                        'hub_right': table['hub_refs'].get(list(table['hub_refs'].keys())[1]) 
                            if len(table['hub_refs']) > 1 else None,
                        'unique': table.get('unique', True),
                        'source': source['name'],
                        'source_table': table['name'],
                        'description': table.get('description', f'Линк {table["link"]}')
                    }
                    
                    if len(table['hub_refs']) > 2:
                        link_info['hubs'] = list(table['hub_refs'].values())
                    
                    self.links.append(link_info)
    
    def generate_link_ddl(self, link_config: Dict) -> str:
        name = link_config['name']
        description = link_config.get('description', f'Линк {name}')
        
        ddl = f"""
CREATE TABLE IF NOT EXISTS dwh_detailed.{name} (
    {name}_id BIGINT PRIMARY KEY,"""
        
        hub_fields = []
        if 'hub_left' in link_config and link_config['hub_left']:
            hub_fields.append(link_config['hub_left'])
        if 'hub_right' in link_config and link_config['hub_right']:
            hub_fields.append(link_config['hub_right'])
        if 'hubs' in link_config:
            hub_fields.extend(link_config['hubs'])
        
        for hub in hub_fields:
            ddl += f"""
    {hub}_id BIGINT NOT NULL,"""
        
        ddl += """
    source_system_id BIGINT NOT NULL,
    created_at TIMESTAMP DEFAULT NOW(),"""
        
        for hub in hub_fields:
            ddl += f"""
    
    CONSTRAINT fk_{name}_{hub} 
        FOREIGN KEY ({hub}_id) 
        REFERENCES dwh_detailed.{hub}({hub}_id),"""
        
        ddl += f""" 
    CONSTRAINT fk_{name}_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)"""
        
        if link_config.get('unique', True):
            unique_fields = ', '.join([f"{hub}_id" for hub in hub_fields])
            ddl += f""",
    
    CONSTRAINT uk_{name} UNIQUE({unique_fields}, source_system_id)"""
        
        ddl += """
);

"""
        
        for hub in hub_fields:
            ddl += f"""
CREATE INDEX IF NOT EXISTS idx_{name}_{hub} 
    ON dwh_detailed.{name}({hub}_id);"""
        
        ddl += f"""
CREATE INDEX IF NOT EXISTS idx_{name}_created 
    ON dwh_detailed.{name}(created_at);
"""
        
        return ddl
    
    def generate_all_links(self) -> str:
        output = ""
        for link in sorted(self.links, key=lambda x: x['name']):
            output += self.generate_link_ddl(link)
            output += "\n"
        
        return output

def main():
    os.makedirs("dwh/generated", exist_ok=True)
    generator = LinkGenerator("dwh/docs/ddl_config.yaml")
    sql = generator.generate_all_links()
    
    output_path = "dwh/generated/003_links.sql"
    with open(output_path, "w", encoding='utf-8') as f:
        f.write(sql)
if __name__ == "__main__":
    main()