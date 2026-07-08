SET SERVEROUTPUT ON
SET TIMING ON

DECLARE
    v_ts_name VARCHAR2(30);
BEGIN
    FOR i IN 1..50 LOOP
        v_ts_name := 'BCT_TS_' || LPAD(i, 2, '0');

        -- MODIFIED: Size increased to 25G to fully safely accommodate ~20.5GB partition data + 64M uniform extents overhead
        -- MODIFIED: Kept AUTOEXTEND OFF to prevent dynamic allocation pauses during the high-speed load benchmark
        EXECUTE IMMEDIATE 'CREATE TABLESPACE ' || v_ts_name ||
            ' DATAFILE ''/u02/app/oracle/oradata/BIGDB1/datafile/' || v_ts_name || '.dbf'' SIZE 25G ' ||
            ' AUTOEXTEND OFF ' ||
            ' EXTENT MANAGEMENT LOCAL UNIFORM SIZE 64M';

        DBMS_OUTPUT.PUT_LINE('Created: ' || v_ts_name || ' on filesystem [/u02/app/oracle/oradata/BIGDB1/datafile] [25GB]');
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('--- Total Allocation: 1.25 TB across 50 Tablespaces on BIGDB1 (Prereq for 1TB Load) ---');
END;
/