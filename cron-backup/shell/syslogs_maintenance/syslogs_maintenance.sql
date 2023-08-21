--- 削除対象日を指定する
\echo :target_datetime

BEGIN;

CREATE TEMP TABLE temp_export AS
SELECT *
FROM "SysLogs"
WHERE "CreatedTime" < :'target_datetime';

\COPY temp_export TO PROGRAM 'nice -n 19 7z a -si -mx=9 -mhe=on /tmp/__old_syslog_records.7z' WITH CSV DELIMITER E'\t' FORCE QUOTE * NULL AS '' HEADER;

DELETE FROM "SysLogs"
WHERE "CreatedTime" < :'target_datetime';

DROP TABLE temp_export;

-- ROLLBACK;
COMMIT;