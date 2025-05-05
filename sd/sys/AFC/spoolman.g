echo >"0:/sys/AFC/AFC-info/spoolman_status.g" "; spoolman status"
echo >>"0:/sys/AFC/AFC-info/spoolman_status.g" {"set global.spoolman_spool_id = " ^ global.spoolman_spool_id}