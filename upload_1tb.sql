-- upload_1tb.sql -- bulk-load the perf table to 1TB volume.
-- Table: BIGTABLE (or BIG_PERF_23 based on your current setup)
-- Configuration: 20M rows per partition (approx 20-21GB per partition)
-- TOTAL TARGET: ~1.05 TB across 50 Partitions

SET SERVEROUTPUT ON
SET TIMING ON
SET ECHO ON

DECLARE
  v_payload_seed VARCHAR2(1000);
  -- ULTRA-OPTIMIZED: 5 chunks per partition (4M rows each) for maximum throughput
  v_chunks_per_part NUMBER := 5; 
  -- 20M rows divided into 4M row execution chunks (ultra-fast, minimal commits)
  v_rows_per_chunk  NUMBER := 20000000 / 5; 
  v_sql              VARCHAR2(2000);
  v_part_lo         NUMBER := &1;
  v_part_hi         NUMBER := &2;
  -- UPDATE THIS string if your table name is BIGTABLE or BIG_PERF_23
  v_table            VARCHAR2(30) := 'BIG_PERF_23'; 
  v_payload_len     NUMBER := 900;
  v_rows_per_part   NUMBER := 20000000; -- Scaled to 20M for 1TB footprint
BEGIN
  -- Optimal for standalone/RAC optimization: keeps parallel slaves bound locally
  EXECUTE IMMEDIATE 'ALTER SESSION ENABLE PARALLEL DML';
  EXECUTE IMMEDIATE 'ALTER SESSION SET PARALLEL_FORCE_LOCAL = TRUE';

  FOR r in (SELECT partition_name, partition_position
            FROM   user_tab_partitions
            WHERE  table_name = v_table
              AND  partition_position BETWEEN v_part_lo AND v_part_hi
            ORDER  BY partition_position)
  LOOP
    v_payload_seed := dbms_random.string('p', v_payload_len);

    FOR c_idx IN 0..(v_chunks_per_part - 1) LOOP
      -- Direct-path insertion layout streaming data straight to datafiles
      -- ULTRA-OPTIMIZED: PARALLEL(24) for 8 CPUs with 12GB free RAM headroom
      v_sql := 'INSERT /*+ APPEND PARALLEL(24) */ INTO ' || v_table || ' PARTITION (' || r.partition_name || ') (id, payload) ' ||
               'SELECT /*+ PARALLEL(24) */ ' ||
               '(((' || (r.partition_position - 1) || ') * ' || v_rows_per_part || ') + (' || (c_idx * v_rows_per_chunk) || ') + rownum - 1), ' ||
               ':seed || TO_CHAR(rownum, ''FM00000000'') ' ||
               'FROM dual CONNECT BY level <= :chunk_size';

      EXECUTE IMMEDIATE v_sql USING v_payload_seed, v_rows_per_chunk;
      
      -- Flushes blocks and keeps the UNDO space crystal clear
      COMMIT;
    END LOOP;

    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE,'HH24:MI:SS') || ' loaded ' || r.partition_name ||
                         ' (pos=' || r.partition_position || ')');
  END LOOP;
END;
/
EXIT;