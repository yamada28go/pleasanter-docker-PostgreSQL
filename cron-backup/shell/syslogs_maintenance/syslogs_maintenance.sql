-- \set target_datetime '2023-08-01 00:00:00'
\echo :target_datetime

BEGIN;

CREATE TEMP TABLE temp_export AS
SELECT *
FROM "SysLogs"
WHERE "CreatedTime" < :'target_datetime';

\COPY temp_export TO '/tmp/old_records.csv' WITH CSV DELIMITER E'\t' FORCE QUOTE * NULL AS '' HEADER;

DELETE FROM "SysLogs"
WHERE "CreatedTime" < :'target_datetime';

DROP TABLE temp_export;

ROLLBACK;
