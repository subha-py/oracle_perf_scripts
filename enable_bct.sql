-- enable_bct.sql -- Enable Block Change Tracking (BCT) for BIGDB1.
-- BCT file is placed under the BIGDB1 oradata directory.
-- Must be run as SYSDBA.

SET SERVEROUTPUT ON
SET ECHO ON

-- Check current BCT status before enabling
SELECT status, filename FROM v$block_change_tracking;

ALTER DATABASE ENABLE BLOCK CHANGE TRACKING
  USING FILE '/u02/app/oracle/oradata/BIGDB1/block_change_tracking.chg';

-- Verify BCT is now enabled
SELECT status, filename FROM v$block_change_tracking;
