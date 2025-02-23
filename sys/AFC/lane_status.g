echo >"0:/sys/AFC/AFC-info/lane_status.g" ^ "; lane status"
echo >>"0:/sys/AFC/AFC-info/lane_status.g" {"set global.lane_loaded = " ^ global.lane_loaded}