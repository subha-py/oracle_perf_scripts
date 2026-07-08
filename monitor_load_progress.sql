-- monitor_load_progress.sql -- Monitor BIG_PERF_23 row count every 10 minutes
-- Run as: nohup sqlplus / as sysdba @monitor_load_progress.sql > /tmp/monitor.log 2>&1 &
-- Or: sqlplus / as sysdba @monitor_load_progress.sql

SET SERVEROUTPUT ON
SET ECHO OFF
SET PAGESIZE 0
SET FEEDBACK OFF

DECLARE
  v_row_count NUMBER;
  v_iteration NUMBER := 0;
  v_start_time TIMESTAMP;
BEGIN
  v_start_time := SYSDATE;
  
  LOOP
    v_iteration := v_iteration + 1;
    
    SELECT COUNT(*) INTO v_row_count FROM BIG_PERF_23;
    
    DBMS_OUTPUT.PUT_LINE(
      TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || 
      ' [Iteration ' || v_iteration || '] ' ||
      'Rows: ' || TO_CHAR(v_row_count, '999,999,999,999') ||
      ' | Elapsed: ' || TRUNC((SYSDATE - v_start_time) * 24 * 60) || ' mins'
    );
    
    -- Exit if 1B rows reached (load complete)
    IF v_row_count >= 1000000000 THEN
      DBMS_OUTPUT.PUT_LINE('');
      DBMS_OUTPUT.PUT_LINE('=== LOAD COMPLETE ===');
      DBMS_OUTPUT.PUT_LINE('Total rows: ' || TO_CHAR(v_row_count, '999,999,999,999'));
      DBMS_OUTPUT.PUT_LINE('Total time: ' || TRUNC((SYSDATE - v_start_time) * 24) || ' hours ' || 
                          MOD(TRUNC((SYSDATE - v_start_time) * 24 * 60), 60) || ' mins');
      EXIT;
    END IF;
    
    -- Wait 10 minutes (600 seconds)
    DBMS_LOCK.SLEEP(600);
  END LOOP;
  
END;
/
EXIT;
