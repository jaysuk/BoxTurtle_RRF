; Array to store CAN addresses for up to 8 BoxTurtles. 
; 0 = Not Installed. 
; Example: Unit 1 is at CAN 119.
global AFC_unit_CAN_ids = {119,120,121}

; Array defining the number of lanes available on each specific BoxTurtle unit.
global AFC_unit_total_lanes = {4,4,2}