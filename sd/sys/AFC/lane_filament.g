var s = "{"
while iterations < #global.AFC_lane_filament_type
  set var.s = var.s ^ """" ^ global.AFC_lane_filament_type[iterations] ^ """"
  if iterations+1 < #global.AFC_lane_filament_type
    set var.s = var.s ^ ","
set var.s = var.s ^ "}"

echo >"0:/sys/AFC/AFC-info/lane_filament.g" " ; lane filament"                                          ; Writes the lane status to a file
echo >>"0:/sys/AFC/AFC-info/lane_filament.g" "set global.AFC_lane_filament_type = " ^ var.s