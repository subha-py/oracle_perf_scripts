-- truncate_all_partitions.sql -- Truncate all partitions of BIG_PERF_23
-- Run as SYSDBA

SET SERVEROUTPUT ON
SET ECHO ON

DECLARE
BEGIN
  FOR i IN 1..50 LOOP
    EXECUTE IMMEDIATE 'ALTER TABLE BIG_PERF_23 TRUNCATE PARTITION p' || i;
    DBMS_OUTPUT.PUT_LINE('Truncated partition p' || i);
  END LOOP;
  
  DBMS_OUTPUT.PUT_LINE('All 50 partitions truncated successfully.');
END;
/
EXIT;
