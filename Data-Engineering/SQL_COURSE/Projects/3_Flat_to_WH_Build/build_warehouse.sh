#!/bin/bash
# =============================================================
# build_warehouse.sh — Shell Orchestrator for the Star-Schema Build
# =============================================================
# Author:  Aman Panchal
# Project: Flat-to-Warehouse Build (Project 3)
#
# Goal:
#   Run each SQL step in order with clear progress reporting and
#   fail-fast error handling. If any step blows up, the script
#   stops immediately so I don't end up with a half-built schema.
#
# Usage:
#   chmod +x build_warehouse.sh
#   ./build_warehouse.sh
#
# What I learned:
#   set -e is the most important line — without it, a failing step
#   would silently continue and the later steps would produce
#   garbage or empty tables. Ask me how I know.
# =============================================================

set -e  # Exit immediately on any non-zero return code

echo "=== Flat-to-Warehouse Build — Starting ==="
echo ""

# Helper: run a single SQL file through DuckDB with status reporting
run_sql_script() {
    local script=$1
    echo "  ▸ Running $script..."
    
    if duckdb -c ".read $script"; then
        echo "  ✅ $script completed successfully"
    else
        echo "  ❌ $script FAILED — aborting pipeline"
        exit 1
    fi
}

# Execute every step in dependency order
run_sql_script "00_load_data.sql"               # Land raw CSV
run_sql_script "01_create_tables.sql"            # Create empty star schema
run_sql_script "02_populate_company_dim.sql"     # Fill company dimension
run_sql_script "03_populate_skills_dim.sql"      # Parse & fill skills dimension
run_sql_script "04_populate_fact_table.sql"      # Load fact table
run_sql_script "05_populate_bridge_table.sql"    # Wire up skills ↔ jobs bridge
run_sql_script "06_verify_schema.sql"            # Verify counts & joins

echo ""
echo "🎉 Warehouse build completed successfully — all 7 steps passed!"
