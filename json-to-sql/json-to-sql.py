#!/usr/bin/env python3
"""
Convert JSON data to SQL INSERT statements for promo_asset_icon table.

Usage:
    python json-to-sql.py input/crm_platform_be.promo_asset_icon.json
    python json-to-sql.py input/crm_platform_be.promo_asset_icon.json -o output.sql
"""

import json
import argparse
import sys
from pathlib import Path


def escape_sql_string(value: str) -> str:
    """Escape single quotes in SQL strings."""
    if value is None:
        return "NULL"
    return value.replace("'", "''")


def format_value(value, field_type: str) -> str:
    """Format a value for SQL based on field type."""
    # Handle NULL values (stored as string "NULL" in JSON)
    if value is None or value == "NULL" or value == "null" or value == "":
        return "NULL"
    
    # Numeric fields
    if field_type in ("bigint", "int"):
        return str(value)
    
    # Timestamp fields
    if field_type == "timestamp":
        if value == "NULL" or value is None:
            return "NULL"
        return f"'{escape_sql_string(str(value))}'"
    
    # String fields (varchar, text)
    return f"'{escape_sql_string(str(value))}'"


def convert_record_to_sql(record: dict) -> str:
    """Convert a single JSON record to SQL INSERT statement."""
    
    # Define column types based on schema
    columns = {
        "id": "bigint",
        "name": "varchar",
        "url": "varchar",
        "created_by": "varchar",
        "created_time": "timestamp",
        "updated_by": "varchar",
        "updated_time": "timestamp",
        "deleted_at": "timestamp",
        "merchant_id": "bigint",
        "app_ids": "text",
        "type": "varchar"
    }
    
    column_names = list(columns.keys())
    values = []
    
    for col in column_names:
        raw_value = record.get(col)
        formatted = format_value(raw_value, columns[col])
        values.append(formatted)
    
    columns_str = ", ".join(column_names)
    values_str = ", ".join(values)
    
    return f"INSERT INTO promo_asset_icon_prod_20260112 ({columns_str}) VALUES ({values_str});"


def convert_json_to_sql(json_file: str, output_file: str = None, batch_size: int = 100):
    """Convert JSON file to SQL INSERT statements."""
    
    # Read JSON file
    with open(json_file, 'r', encoding='utf-8') as f:
        data = json.load(f)
    
    if not isinstance(data, list):
        print("Error: JSON file must contain an array of objects", file=sys.stderr)
        sys.exit(1)
    
    print(f"Found {len(data)} records to convert", file=sys.stderr)
    
    # Generate SQL statements
    sql_statements = []
    sql_statements.append("-- Generated SQL INSERT statements for promo_asset_icon")
    sql_statements.append(f"-- Source: {json_file}")
    sql_statements.append(f"-- Total records: {len(data)}")
    sql_statements.append("")
    
    # Option to use batch insert for better performance
    if batch_size > 1 and len(data) > batch_size:
        sql_statements.append("-- Using batch inserts for better performance")
        sql_statements.append("")
        
        columns = ["id", "name", "url", "created_by", "created_time", 
                   "updated_by", "updated_time", "deleted_at", 
                   "merchant_id", "app_ids", "type"]
        column_types = {
            "id": "bigint", "name": "varchar", "url": "varchar",
            "created_by": "varchar", "created_time": "timestamp",
            "updated_by": "varchar", "updated_time": "timestamp",
            "deleted_at": "timestamp", "merchant_id": "bigint",
            "app_ids": "text", "type": "varchar"
        }
        
        for i in range(0, len(data), batch_size):
            batch = data[i:i + batch_size]
            values_list = []
            
            for record in batch:
                values = []
                for col in columns:
                    raw_value = record.get(col)
                    formatted = format_value(raw_value, column_types[col])
                    values.append(formatted)
                values_list.append(f"({', '.join(values)})")
            
            columns_str = ", ".join(columns)
            values_str = ",\n".join(values_list)
            sql_statements.append(f"INSERT INTO promo_asset_icon ({columns_str}) VALUES")
            sql_statements.append(f"{values_str};")
            sql_statements.append("")
    else:
        # Single row inserts
        for record in data:
            sql_statements.append(convert_record_to_sql(record))
    
    # Output
    output_content = "\n".join(sql_statements)
    
    if output_file:
        with open(output_file, 'w', encoding='utf-8') as f:
            f.write(output_content)
        print(f"SQL written to: {output_file}", file=sys.stderr)
    else:
        print(output_content)
    
    return len(data)


def main():
    parser = argparse.ArgumentParser(
        description="Convert JSON data to SQL INSERT statements for promo_asset_icon table"
    )
    parser.add_argument(
        "json_file",
        help="Path to the JSON file containing the data"
    )
    parser.add_argument(
        "-o", "--output",
        help="Output SQL file (default: print to stdout)"
    )
    parser.add_argument(
        "-b", "--batch-size",
        type=int,
        default=100,
        help="Number of records per batch INSERT (default: 100, use 1 for single inserts)"
    )
    
    args = parser.parse_args()
    
    if not Path(args.json_file).exists():
        print(f"Error: File not found: {args.json_file}", file=sys.stderr)
        sys.exit(1)
    
    convert_json_to_sql(args.json_file, args.output, args.batch_size)


if __name__ == "__main__":
    main()
