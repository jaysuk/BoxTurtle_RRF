
if !fileexists("0:/sys/AFC/AFC-info/lane_filament.g")
    M98 P"0:/sys/AFC/lane_filament.g"

while iterations < #global.AFC_lane_filament_type
    if global.AFC_lane_filament_type[iterations] != global.AFC_lane_filament_type1[iterations]
        M98 P"0:/sys/AFC/lane_filament.g"
        set global.AFC_lane_filament_type1[iterations] = global.AFC_lane_filament_type[iterations]