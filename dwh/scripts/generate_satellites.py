import os
import yaml
from typing import List, Dict, Any

class SatelliteGenerator:
    def __init__(self, config_path: str):
        with open(config_path, 'r', encoding='utf-8') as f:
            self.config = yaml.safe_load(f)
        self.satellites: List[Dict] = []
        self._extract_satellites()
    
    def _extract_satellites(self):
        for source in self.config['sources']:
            for table in source['tables']:
                if 'satellite' in table:
                    filtered_attributes = []
                    system_fields = ['effective_from', 'effective_to', 'is_current', 'created_at', 'updated_at', 'created_by', 'updated_by']
                    for attr in table.get('attributes', []):
                        if attr['name'] not in system_fields:
                            filtered_attributes.append(attr)
                    sat_info = {
                        'name': table['satellite'],
                        'hub': table.get('hub') or table.get('hub_ref') or table.get('link'),
                        'attributes': filtered_attributes,
                        'source': source['name'],
                        'source_table': table['name'],
                        'business_key_ref': table.get('business_key_ref'),
                        'type': self._determine_satellite_type(table)
                    }
                    self.satellites.append(sat_info)
    
    def _determine_satellite_type(self, table: Dict) -> str:
        if 'hub' in table or 'hub_ref' in table:
            return 'hub_satellite'
        elif 'link' in table:
            return 'link_satellite'
        else:
            return 'unknown'
    
    def generate_satellite_ddl(self, sat_config: Dict) -> str:
        name = sat_config['name']
        hub = sat_config['hub']
        attributes = sat_config['attributes']
        
        if sat_config['type'] == 'hub_satellite':
            if hub.startswith('hub_'):
                parent_key = f"{hub}_id"
            else:
                parent_key = f"{hub}_id"
            parent_table = hub
        else:
            parent_key = f"{hub}_id" if hub else 'link_id'
            parent_table = hub
        
        ddl = f"""
CREATE TABLE IF NOT EXISTS dwh_detailed.{name} (
    {name}_id BIGSERIAL,
    {parent_key} BIGINT NOT NULL,
    source_system_id BIGINT NOT NULL,
    effective_from TIMESTAMP NOT NULL DEFAULT NOW(),
    effective_to TIMESTAMP,
    is_current BOOLEAN DEFAULT TRUE,"""
        
        for attr in attributes:
            ddl += f"""
    {attr['name']} {attr['type']},"""
        
        ddl += f"""
    loaded_at TIMESTAMP DEFAULT NOW(),
    hash_diff BIGINT,
    
    PRIMARY KEY ({name}_id),
    
    CONSTRAINT fk_{name}_{parent_key.replace('_id', '')} 
        FOREIGN KEY ({parent_key}) 
        REFERENCES dwh_detailed.{parent_table}({parent_key}),
    
    CONSTRAINT fk_{name}_source_system 
        FOREIGN KEY (source_system_id) 
        REFERENCES dwh_detailed.source_system(source_system_id)
);

CREATE INDEX IF NOT EXISTS idx_{name}_parent 
    ON dwh_detailed.{name}({parent_key});
    
CREATE INDEX IF NOT EXISTS idx_{name}_current 
    ON dwh_detailed.{name}(is_current) WHERE is_current = TRUE;
    
CREATE INDEX IF NOT EXISTS idx_{name}_dates 
    ON dwh_detailed.{name}(effective_from, effective_to);
"""
        
        if attributes:
            ddl += f"""
CREATE OR REPLACE FUNCTION dwh_detailed.calc_{name}_hash(
"""
            params = []
            for attr in attributes:
                params.append(f"p_{attr['name']} {attr['type']}")
            
            if params:
                ddl += "\n    " + ",\n    ".join(params)
            
            ddl += """
) RETURNS BIGINT AS $$
BEGIN
    RETURN dwh_detailed.md5_hash(COALESCE("""
            
            attr_names = [f"p_{attr['name']}::TEXT" for attr in attributes]
            if attr_names:
                ddl += " || '|' || ".join(attr_names)
            else:
                ddl += "''"
            
            ddl += """, ''));
END;
$$ LANGUAGE plpgsql IMMUTABLE;
"""
        
        return ddl
    
    def generate_all_satellites(self) -> str:
        output = ""
        for sat in self.satellites:
            output += self.generate_satellite_ddl(sat)
            output += "\n"
        
        return output

def main():
    os.makedirs("dwh/generated", exist_ok=True)
    
    generator = SatelliteGenerator("dwh/docs/ddl_config.yaml")
    sql = generator.generate_all_satellites()
    
    output_path = "dwh/generated/004_satellites.sql"
    with open(output_path, "w", encoding='utf-8') as f:
        f.write(sql)
if __name__ == "__main__":
    main()