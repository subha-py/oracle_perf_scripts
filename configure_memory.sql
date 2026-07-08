-- configure_memory.sql -- Tune Oracle memory for BIGDB1 on a 31G RAM host.
--
-- System profile (from free -mh):
--   Total RAM : 31G
--   Available : ~20G
--
-- Strategy: ASMM (SGA_TARGET + PGA_AGGREGATE_TARGET)
--   - AMM (MEMORY_TARGET) is intentionally disabled; it conflicts with HugePages.
--   - SGA_TARGET  = 18G  --> buffer cache, shared pool, redo log buffer, etc.
--   - PGA total   =  6G  --> sort/hash areas for parallel DML & query workers
--   - Total Oracle= 24G  (~77% of RAM, leaves ~7G for OS + other processes)
--
-- NOTE: SGA_MAX_SIZE and SGA_TARGET changes require a DB restart (SCOPE=SPFILE).
--       PGA changes take effect immediately (SCOPE=BOTH).
--
-- Run as SYSDBA:
--   sqlplus / as sysdba @configure_memory.sql

SET SERVEROUTPUT ON
SET ECHO ON

PROMPT === Current memory settings ===
SHOW PARAMETER memory_target
SHOW PARAMETER memory_max_target
SHOW PARAMETER sga_max_size
SHOW PARAMETER sga_target
SHOW PARAMETER pga_aggregate_target
SHOW PARAMETER pga_aggregate_limit

PROMPT === Disabling AMM (MEMORY_TARGET) -- required before raising SGA_MAX_SIZE ===
ALTER SYSTEM SET MEMORY_MAX_TARGET = 0 SCOPE=SPFILE;
ALTER SYSTEM SET MEMORY_TARGET     = 0 SCOPE=SPFILE;

PROMPT === Setting SGA (requires restart) ===
-- SGA_MAX_SIZE must be set first; it is a hard ceiling for SGA_TARGET.
ALTER SYSTEM SET SGA_MAX_SIZE  = 18G SCOPE=SPFILE;
ALTER SYSTEM SET SGA_TARGET    = 18G SCOPE=SPFILE;

PROMPT === Setting PGA (takes effect immediately) ===
-- PGA_AGGREGATE_TARGET: soft advisory target; Oracle tries to stay under it.
-- PGA_AGGREGATE_LIMIT : hard cap (set to 2x target as safety net).
ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 6G  SCOPE=BOTH;
ALTER SYSTEM SET PGA_AGGREGATE_LIMIT  = 12G SCOPE=BOTH;

PROMPT === Restart required for SGA changes to take effect ===
PROMPT     Run the following to apply:
PROMPT       SHUTDOWN IMMEDIATE;
PROMPT       STARTUP;

-- Uncomment the lines below to bounce the DB automatically:
-- SHUTDOWN IMMEDIATE;
-- STARTUP;

PROMPT === Post-restart verification (run after bounce) ===
-- SHOW PARAMETER sga_max_size
-- SHOW PARAMETER sga_target
-- SHOW PARAMETER pga_aggregate_target
-- SELECT name, ROUND(value/1073741824,2) AS gb FROM v$parameter
--  WHERE name IN ('sga_max_size','sga_target','pga_aggregate_target','pga_aggregate_limit');
