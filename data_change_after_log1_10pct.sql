SET SERVEROUTPUT ON
SET TIMING ON
SET ECHO ON

DECLARE
  v_payload_seed   VARCHAR2(1000);
  v_rows_per_chunk NUMBER := 1000000;       -- 1M rows per INSERT (PGA-safe)
  v_part_lo        NUMBER := 11;            -- <-- slice 3
  v_part_hi        NUMBER := 15;            -- <-- slice 3
  v_redo_pre       NUMBER;
  v_redo_post      NUMBER;
  -- NEW: Scaled variables for 1TB layout
  v_rows_per_part  NUMBER := 20000000;      -- 20M rows per partition
  v_chunks_per_part NUMBER := 20;           -- 20 chunks needed to fill 20M rows
BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';

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

    -- MODIFIED: Looping 20 times (0 to 19) to generate all 20M rows per partition
    FOR c_idx IN 0..(v_chunks_per_part - 1) LOOP
      EXECUTE IMMEDIATE
        'INSERT /*+ APPEND PARALLEL(8) */ INTO SYS.BIG_PERF_23 PARTITION (' || r.partition_name || ') (id, payload) ' ||
        'SELECT /*+ PARALLEL(8) */ ' ||
        -- MODIFIED: Adjusted multiplier to v_rows_per_part (20000000) for pristine range alignment
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