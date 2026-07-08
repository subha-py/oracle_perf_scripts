-- monitor_load_progress.sql -- Simple row count monitor every 30 minutes
-- Run as: nohup sqlplus / as sysdba @monitor_load_progress.sql > /home/oracle/monitor.log 2>&1 &

SET SERVEROUTPUT ON
SET ECHO OFF
SET PAGESIZE 0
SET FEEDBACK OFF

DECLARE
  v_row_count NUMBER;
  v_iteration NUMBER := 0;
BEGIN
  LOOP
    v_iteration := v_iteration + 1;
    
    SELECT COUNT(*) INTO v_row_count FROM BIG_PERF_23;
    
    DBMS_OUTPUT.PUT_LINE(TO_CHAR(SYSDATE, 'YYYY-MM-DD HH24:MI:SS') || ' - Rows: ' || v_row_count);
    
    -- Exit when 1B rows reached
    IF v_row_count >= 1000000000 THEN
      DBMS_OUTPUT.PUT_LINE('LOAD COMPLETE - Total rows: ' || v_row_count);
      EXIT;
    END IF;
    
    -- Wait 30 minutes
    DBMS_LOCK.SLEEP(1800);
  END LOOP;
END;
/
EXIT;
