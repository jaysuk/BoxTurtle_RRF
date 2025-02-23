; ########## Settings to Edit #####
global AFC_CAN_address=119
global AFC_stepper_direction={0,0,0,0}
global AFC_microsteps={16,16,16,16}
global AFC_steps_per_mm={682,682,682,682}
global AFC_stepper_current={1000,1000,1000,1000}
global AFC_stepper_jerk={300,300,300,300,300}                             ; lanes 0 to 3 and then for the extruder
global AFC_stepper_max_speed={2000,2000,2000,2000,4800}                   ; lanes 0 to 3 and then for the extruder
global AFC_stepper_acc={600,600,600,600,5000}
global AFC_load_speed=2000
global AFC_retract_speed=2000
global AFC_trigger_numbers={2,3,4,5}
global AFC_buffer_trigger_numbers={6,7}
global AFC_trigger_input_numbers={0,1,2,3}
global AFC_buffer_input_numbers={4,5}
global AFC_hub_input_number=6
global AFC_unload_input_number=7
global AFC_number_of_lanes=4

global om_axis_number=3

global extruder_driver=0.3                                                ; This is the driver number of your main extruder. To be edited
global extruder_microsteps=16                                             ; This is the microstepping of your main extruder. To be edited
global extruder_steps_per_mm=606.56                                       ; This is the steps per mm of your main extruder. To be edited
global extruder_jerk=300                                                  ; This is the jerk/maximum instantaneous speed changes of your main extruder. To be edited
global extruder_max_speed=4800                                            ; This is the maximum speed of your main extruder. To be edited
global extruder_acc=5000                                                  ; This is the acceleration of your main extruder. To be edited
global extruder_current=800                                               ; This is the current of your main extruder. To be edited
global extruder_to_nozzle=77                                              ; This is the extruder to nozzle length

var driver_number={0.0,0.1,0.2,0.3}     ; This is the driver number of each lane on the board. This will not need editing if using an AFC board
var SLP_pins={"SLP1","SLP2","SLP3","SLP4"} ; These are the SLP pins for the motor. This will not need editing if using an AFC board
var DC1_pins={"dc11","dc12","dc13","dc14"} ; These are the DC1 pins for the motor. This will not need editing if using an AFC board
var DC2_pins={"dc21","dc22","dc23","dc24"} ; These are the DC2 pins for the motor. This will not need editing if using an AFC board
var prep_switch={"SW2","SW3","SW4","SW5"} ; These are the prep switch pins. This will not need editing if using an AFC board
var load_switch={"SW7","SW8","SW9","SW10"} ; These are the load switch pins. This will not need editing if using an AFC board
var turtleneck_switches={"SW11","SW12"} ; These are the turtle neck pins. This will not need editing if using an AFC board
var hub_switch="SW1" ; This is the hub switch. This will not need editing if using an AFC board

; ########## DO NOT EDIT PAST HERE!!! ################

global AFC_driver_number={{global.AFC_CAN_address+var.driver_number[0]+0.0001},{global.AFC_CAN_address+var.driver_number[1]+0.0001},{global.AFC_CAN_address+var.driver_number[2]+0.0001},{global.AFC_CAN_address+var.driver_number[3]+0.0001}}
global AFC_SLP_pins={{global.AFC_CAN_address^"."^var.SLP_pins[0]},{global.AFC_CAN_address^"."^var.SLP_pins[1]},{global.AFC_CAN_address^"."^var.SLP_pins[2]},{global.AFC_CAN_address^"."^var.SLP_pins[3]}}         ; These are the SLP pins used by the DC motors
global AFC_DC1_pins={{global.AFC_CAN_address^"."^var.DC1_pins[0]},{global.AFC_CAN_address^"."^var.DC1_pins[1]},{global.AFC_CAN_address^"."^var.DC1_pins[2]},{global.AFC_CAN_address^"."^var.DC1_pins[3]}}         ; These are the DC1 pins used by the DC motors
global AFC_DC2_pins={{global.AFC_CAN_address^"."^var.DC2_pins[0]},{global.AFC_CAN_address^"."^var.DC2_pins[1]},{global.AFC_CAN_address^"."^var.DC2_pins[2]},{global.AFC_CAN_address^"."^var.DC2_pins[3]}}         ; These are the DC2 pins used by the DC motors
global AFC_prep_switch={{"^!"^global.AFC_CAN_address^"."^var.prep_switch[0]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[1]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[2]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[3]}} ; These are the prep switches of each lane
global AFC_load_switch={{global.AFC_CAN_address^"."^var.load_switch[0]},{global.AFC_CAN_address^"."^var.load_switch[1]},{global.AFC_CAN_address^"."^var.load_switch[2]},{global.AFC_CAN_address^"."^var.load_switch[3]}}        ; These are the load switches of each lane
global TN_switches={{global.AFC_CAN_address^"."^var.turtleneck_switches[0]},{global.AFC_CAN_address^"."^var.turtleneck_switches[1]}}                                ; These are in the order of Advance and Trailing
global AFC_hub_switch={"^"^global.AFC_CAN_address^"."^var.hub_switch}

global AFC_tmp_file = "0:/sys/AFC/AFC-info/tmp.g"

; ########## Lane Info ############
global AFC_lane_loaded={false,false,false,false}
global AFC_lane_first_length={0,0,0,0}
global AFC_lane_total_length={0,0,0,0}
global AFC_lane_continuous={false,false,false,false}

; ########## Additional Info ##########
global additional_length=0
global AFC_LED_array={0,0,0,0}

global AFC_time=0

global AFC_debug=true