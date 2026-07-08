-- create_table.sql -- (re)create the perf workload table.
-- Using Table: BIG_PERF_23
-- Partitions: 50
-- Rows Per Partition: 20,000,000 (Scaled for 1TB Load)

SET SERVEROUTPUT ON
SET ECHO ON

DECLARE
  v_sql CLOB;
  v_table_name VARCHAR2(30) := 'BIG_PERF_23';
  v_num_partitions NUMBER := 50;
  -- MODIFIED: Upgraded to 20M rows per partition to allow the 1TB threshold
  v_rows_per_partition NUMBER := 20000000; 
  v_ts_prefix VARCHAR2(10) := 'BCT_TS_';
BEGIN
  -- Cleanup previous run
  BEGIN
    EXECUTE IMMEDIATE 'DROP TABLE ' || v_table_name || ' PURGE';
  EXCEPTION WHEN OTHERS THEN NULL;
  END;

  v_sql := 'CREATE TABLE ' || v_table_name || ' (
    id NUMBER,
    payload VARCHAR2(1000),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
)
LOGGING
PARTITION BY RANGE (id) (';

  -- Loop to create first 49 partitions with wide boundaries
  FOR i IN 1..49 LOOP
    v_sql := v_sql || '
    PARTITION p' || i || ' VALUES LESS THAN (' || (i * v_rows_per_partition) || ') TABLESPACE ' || v_ts_prefix || LPAD(i, 2, '0') || ',';
  END LOOP;

  -- Adding the final MAXVALUE partition (p50)
  v_sql := v_sql || '
    PARTITION p50 VALUES LESS THAN (MAXVALUE) TABLESPACE ' || v_ts_prefix || '50
)';

  EXECUTE IMMEDIATE v_sql;
  DBMS_OUTPUT.PUT_LINE('Table ' || v_table_name || ' created with 50 partitions mapped to ' || v_ts_prefix || '01-50 with 20M row ranges.');
END;
/
EXIT;