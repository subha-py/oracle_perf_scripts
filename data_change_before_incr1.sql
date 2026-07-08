SET SERVEROUTPUT ON
SET TIMING ON
SET ECHO ON

DECLARE
  v_payload_seed   VARCHAR2(1000);
  v_rows_per_chunk NUMBER := 2000000;       -- OPTIMIZED: 2M chunks to reduce commits per partition
  v_part_lo        NUMBER := 1;             -- <-- change for slice 2/3/4
  v_part_hi        NUMBER := 5;             -- <-- change for slice 2/3/4
  v_redo_pre       NUMBER;
  v_redo_post      NUMBER;
  -- NEW: Scaled variables for 1TB layout
  v_rows_per_part  NUMBER := 20000000;      -- 20M rows per partition
  v_chunks_per_part NUMBER := 10;           -- OPTIMIZED: 10 chunks (2M rows each) instead of 20
BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
  EXECUTE IMMEDIATE 'ALTER SESSION SET PARALLEL_FORCE_LOCAL = TRUE';

  SELECT m.value INTO v_redo_pre FROM v$mystat m, v$statname n
   WHERE m.statistic#=n.statistic# AND n.name='redo size';

  FOR r IN (SELECT partition_name, partition_position
            FROM   dba_tab_partitions
            WHERE  table_owner='SYS' AND table_name='BIG_PERF_23'
              AND  partition_position BETWEEN v_part_lo AND v_part_hi
            ORDER  BY partition_position)
  LOOP
    v_payload_seed := DBMS_RANDOM.STRING('p', 900);

    EXECUTE IMMEDIATE 'ALTER TABLE SYS.BIG_PERF_23 TRUNCATE PARTITION ' || r.partition_name;
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE,'HH24:MI:SS') || ' TRUNCATED ' || r.partition_name);

    -- OPTIMIZED: 10 chunks (2M rows each) instead of 20 chunks (1M rows) to reduce commits + PARALLEL(16)
    FOR c_idx IN 0..9 LOOP
      EXECUTE IMMEDIATE
        'INSERT /*+ APPEND PARALLEL(16) */ INTO SYS.BIG_PERF_23 PARTITION (' || r.partition_name || ') (id, payload) ' ||
        'SELECT /*+ PARALLEL(16) */ ' ||
        -- MODIFIED: Replaced 10000000 with v_rows_per_part (20000000) for pristine ID alignment
        '(((' || (r.partition_position - 1) || ') * ' || v_rows_per_part || ') + (' || (c_idx * v_rows_per_chunk) || ') + ROWNUM - 1), :seed || TO_CHAR(ROWNUM, ''FM00000000'') ' ||
        'FROM dual CONNECT BY level <= :chunk_size'
        USING v_payload_seed, v_rows_per_chunk;
      COMMIT;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE,'HH24:MI:SS') || ' RELOADED ' || r.partition_name);
  END LOOP;

  SELECT m.value INTO v_redo_post FROM v$mystat m, v$statname n
   WHERE m.statistic#=n.statistic# AND n.name='redo size';

  DBMS_OUTPUT.PUT_LINE('redo_generated_mb=' || ROUND((v_redo_post - v_redo_pre)/1048576, 1));
END;
/

ALTER SYSTEM ARCHIVE LOG CURRENT;