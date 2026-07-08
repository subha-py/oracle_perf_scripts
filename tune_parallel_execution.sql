-- tune_parallel_execution.sql -- Optimize parallel execution for 1TB load on BIGDB1.
-- Run as SYSDBA before upload_1tb.sql for maximum throughput.
--
-- These changes allow more parallel worker threads to run concurrently,
-- leveraging the 24G SGA+PGA allocation more aggressively.

SET SERVEROUTPUT ON
SET ECHO ON

PROMPT === Current parallel execution settings ===
SHOW PARAMETER parallel_max_servers
SHOW PARAMETER parallel_threads_per_cpu
SHOW PARAMETER processes

PROMPT === Tuning for 1TB load ===
-- parallel_threads_per_cpu: Default is 2. Increase to 4 to spawn more workers per CPU.
-- On an instance with 8+ CPUs, this allows up to 32+ parallel worker threads.
ALTER SYSTEM SET parallel_threads_per_cpu = 4 SCOPE=SPFILE;

-- parallel_max_servers: Max pool of parallel workers. Set to 40 (2x the PARALLEL(16) in upload_1tb).
ALTER SYSTEM SET parallel_max_servers = 40 SCOPE=SPFILE;

-- processes: Hard cap on background + foreground processes. Set to 500 to avoid hitting limit.
ALTER SYSTEM SET processes = 500 SCOPE=SPFILE;

PROMPT === Changes require DB restart to apply ===
PROMPT     After running this script:
PROMPT       SHUTDOWN IMMEDIATE;
PROMPT       STARTUP;
PROMPT
PROMPT === Post-restart verification ===
-- SHOW PARAMETER parallel_max_servers
-- SHOW PARAMETER parallel_threads_per_cpu
