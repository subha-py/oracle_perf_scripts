-- redo_large.sql -- generate ~target_gib GiB of redo by looping repeated UPDATEs
-- on a contiguous partition slice. Use this BEFORE Log 2 (or any phase where
-- you want a larger archive log volume than the standard 10% slice produces).

SET SERVEROUTPUT ON SIZE UNLIMITED
SET TIMING ON
SET ECHO ON
SET VERIFY OFF

DECLARE
  v_target_gib     NUMBER := &&1;
  v_target_mb      NUMBER := &&1 * 1024;
  v_part_lo        NUMBER := &&2;
  v_count          NUMBER := &&3;
  v_rows           NUMBER := &&4;
  v_max_iters      NUMBER := &&5;
  -- FIXED: Filled template driver substitution placeholder
  v_full           VARCHAR2(128) := 'SYS.BIG_PERF_23';
  v_owner          VARCHAR2(128);
  v_table          VARCHAR2(128);
  v_dot            NUMBER;
  v_redo_pre       NUMBER;
  v_redo_post      NUMBER;
  v_redo_now_mb    NUMBER := 0;
  v_iter           NUMBER := 0;
  v_parts_matched  NUMBER := 0;
  v_sql            VARCHAR2(2000);
BEGIN
  EXECUTE IMMEDIATE 'ALTER SESSION DISABLE PARALLEL DML';

  -- Split SCHEMA.TABLE; fall back to current schema if not qualified.
  v_dot := INSTR(v_full, '.');
  IF v_dot > 0 THEN
    v_owner := UPPER(SUBSTR(v_full, 1, v_dot - 1));
    v_table := UPPER(SUBSTR(v_full, v_dot + 1));
  ELSE
    SELECT SYS_CONTEXT('USERENV','CURRENT_SCHEMA') INTO v_owner FROM dual;
    v_table := UPPER(v_full);
  END IF;

  DBMS_OUTPUT.PUT_LINE('targeting ' || v_owner || '.' || v_table ||
                       ' partition_positions ' || v_part_lo ||
                       '..' || (v_part_lo + v_count - 1) ||
                       ' rows_per_iter=' || v_rows ||
                       ' target_gib=' || v_target_gib ||
                       ' max_iters=' || v_max_iters);

  SELECT COUNT(*) INTO v_parts_matched
  FROM   dba_tab_partitions
  WHERE  table_owner = v_owner
    AND  table_name  = v_table
    AND  partition_position BETWEEN v_part_lo AND v_part_lo + v_count - 1;

  IF v_parts_matched = 0 THEN
    RAISE_APPLICATION_ERROR(-20001,
      'no partitions matched ' || v_owner || '.' || v_table ||
      ' part_pos ' || v_part_lo || '..' || (v_part_lo + v_count - 1) ||
      ' -- check owner/table name and partition range');
  END IF;
  DBMS_OUTPUT.PUT_LINE('matched ' || v_parts_matched || ' partitions');

  SELECT m.value INTO v_redo_pre
  FROM v$mystat m, v$statname n
  WHERE m.statistic# = n.statistic# AND n.name = 'redo size';

  -- Outer loop: keep firing the inner per-partition UPDATEs until we've
  -- generated --target-gib of redo (or hit the safety cap).
  WHILE v_redo_now_mb < v_target_mb AND v_iter < v_max_iters LOOP
    v_iter := v_iter + 1;

    FOR r IN (SELECT partition_name, partition_position
              FROM   dba_tab_partitions
              WHERE  table_owner = v_owner
                AND  table_name  = v_table
                AND  partition_position BETWEEN v_part_lo AND v_part_lo + v_count - 1
              ORDER  BY partition_position)
    LOOP
      -- FIXED: Replaced payload length template with 900
      v_sql := 'UPDATE /*+ NO_PARALLEL */ ' || v_owner || '.' || v_table ||
               ' PARTITION (' || r.partition_name || ') ' ||
               'SET payload = dbms_random.string(''p'', 900) ' ||
               'WHERE ROWNUM <= ' || v_rows;
      EXECUTE IMMEDIATE v_sql;
      COMMIT;
    END LOOP;

    SELECT m.value INTO v_redo_post
    FROM v$mystat m, v$statname n
    WHERE m.statistic# = n.statistic# AND n.name = 'redo size';

    v_redo_now_mb := ROUND((v_redo_post - v_redo_pre) / 1048576, 1);

    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE,'HH24:MI:SS') ||
                         ' iter=' || v_iter ||
                         ' redo_so_far_mb=' || v_redo_now_mb ||
                         ' (target_mb=' || v_target_mb || ')');
  END LOOP;

  IF v_iter >= v_max_iters AND v_redo_now_mb < v_target_mb THEN
    DBMS_OUTPUT.PUT_LINE('WARN: max_iters reached without hitting target. ' ||
                         'Tune --rows-per-iter higher to get more redo per loop.');
  END IF;

  DBMS_OUTPUT.PUT_LINE('redo_generated_mb=' || v_redo_now_mb ||
                       ' iterations=' || v_iter ||
                       ' partitions_per_iter=' || v_count ||
                       ' rows_per_iter=' || v_rows);
END;
/
EXIT;