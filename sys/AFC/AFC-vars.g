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
global AFC_hub_retract_distance=25 ; Changing this value will result in the length of each lane to be
global AFC_speed = {150, 10} ; X/Y travel speed (mm/s), Z travel speed (mm/s)

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

;--=================================================================================-
;------- Cut -----------------------------------------------------------------------
;--=================================================================================-

; This should be the position of the toolhead where the cutter arm just
; lightly touches the depressor pin
global AFC_cut_location = {-1,-1} ; x,y coordinates of depressor pin

; Direction to make the cut move (left, right, front, back)
global AFC_cut_direction = "left" 

; Park
; This distance is used to move toolhead to cut filament
; and to create a small saftely distance that aids in generating momentum
; Position of the toolhead when the cutter is fully compressed.

; Move
; Distance the toolhead needs to travel to compress the cutter arm.
; To calculate this distance start at the pin_loc_xy position and move
; your toolhead till the cutter arm is completely compressed. Take 0.5mm off this distance
; as a buffer. 
; Ex pin_loc_x : 9, 310  fully compressed at 0, 310 set cut_move_dist to 8.5
global AFC_cut_dist = {6.0,8.0} ; park (mm) and move (mm)

; Speed related settings for tip cutting
; Note that if the cut speed is too fast, the steppers can lose steps.
; Therefore, for a cut:
; - We first make a fast move to accumulate some momentum and get the cut
;   blade to the initial contact with the filament
; - We then make a slow move for the actual cut to happen 
global AFC_cut_move = {32,10,150,50,0.85,25,2} ; Fast speed (mm/s), slow speed (mm/s), evacuate speed (mm/s), dwell time (ms), fast move fraction, extruder move speed (ms) and cut count

;If the toolhead returns to initial position after the cut is complete.
global AFC_cut_restore_pos = false ; True = return to initial position, False = don't return

; Distance to retract prior to making the cut, this reduces wasted filament but might cause clog 
; if set too large and/or if there are gaps in the hotend assembly 
; *This must be less than the distance from the nozzle to the cutter
global AFC_cut_retract_length = 30 ; Distance (mm)

; This can help prevent clogging of some toolheads by doing a quick tip from to reduce stringing
global AFC_cut_quick_tip_forming = false ; true or false

; Retract length and speed after the cut so that the cutter can go back 
; into its origin position
global AFC_cut_rip = {1.0,3} ; Distance (mm), speed (mm/s)

; Pushback of the remaining tip from the cold end into the hotend
; *Must be less then retract_length
global AFC_cut_pushback = {25,20} ; Distance (mm) and time to dwell between the pushback

; Safety margin for fast vs slow travel. When traveling to the pin location
; we make a safer but longer move if we are closer to the pin than this
; specified margin. Usually setting these to the size of the toolhead
; (plus a small margin) should be good enough 
global AFC_cut_safe_margin = {30,30} ; X and Y, approx toolhead width +5mm

; Some printers may need a boost of power to complete the cut without skipping steps.
; One option is to increase the current for thost steppers in config.g. Another
; option is to use these variables to set a current that is only used during the
; cut motion. Different combinations of kinematics and cutter configurations engage
; different combinations of steppers for that motion.  Set the needed variables.
; The override is skipped if the current is 0.
; Enable if layer shifts occur when cutting
global AFC_cut_current_stepper = {0,0,0} ; X, Y and Z in mA

;--=================================================================================-
;------- Poop ----------------------------------------------------------------------
;--=================================================================================-

global AFC_purge_location = {-1,-1} ; X, Y location of where to purge
global AFC_purge_speed = 6.5 ; speed (mm/s) of the purge

; Speed, in mm/s to lift z after the purge is completed. Its a faster lift to keep it from 
; sticking to the toolhead
global AFC_purge_fast_z = {200,20} ; speed (mm/s), distance (mm)

; If the toolhead returns to initial position after the poop is complete.
global AFC_purge_restore = false ; True = return to initial position, False = don't return

; The height to raise the nozzle above the tray before purging. This allows any built up 
; pressure to escape before the purge.
global AFC_purge_start = 0.6

; Set the part cooling fan speed. Disabling can help prevent the nozzle from cooling down 
; and stimulate flow, Enabling it can prevent blobs from sticking together.
global AFC_part_cooling_fan = {true,1.0,2} ; Run at full speed, speed to run fan when enabled, time to pause after purge to allow fan to cool the poop (s)

; ==================== PURGE LENGTH TUNING
; Default purge length to fall back on when neither the tool map purge_volumes or 
; parameter PURGE_LENGTH is set.
global AFC_purge_length = {72.111,60.999} ; Default purge length (mm), absolute minimum purge length (mm)

; The slicer values often are a bit too wasteful. Tune it here to get optimal values. 0.6
; is a good starting point.
;global AFC_purge_length_modifier = 1

; Length of filament to add after the purge volume. Purge volumes don't always take 
; cutters into account and therefor a swap from red to white might be long enough, but 
; from white to red can be far too short. When should you alter this value:
;   INCREASE: When the dark to light swaps are good, but light to dark aren't.
;   DECREASE: When the light to dark swaps are good, but dark to light aren't. Don't 
;     forget to increase the purge_length_modifier
;global AFC_purge_length_addition = 0

;--=================================================================================-
;------- Kick ----------------------------------------------------------------------
;--=================================================================================-

global AFC_kick = {-1,-1,10,1.5,150,0,"right",45,10}
; Location to move before kick - X, Y and Z
; Height to drop to for kick move
; Speed of kick movement
; Accel of kick moves. This will overwrite the global accel for this macro. Set to 0 to use global accel
; Direction to make the kick move (left, right, front, back)
; How far to move to kick poop off
; Height of z after kick move

;--=================================================================================-
;------- Brush ---------------------------------------------------------------------
;--=================================================================================-

global AFC_brush = {-1,-1,-1,150,30,10,true,4}
; Position of the center of the brush (Set z to -1 if you dont want a z move) - X, Y and Z
; Speed of cleaning moves when brushing
; Total width in mm of the brush in the X direction
; Total depth in mm of the brush in the Y direction
; True - Brush along Y axis first then X. False - Only brush along x
; Number of passes to make on the brush.

;--=================================================================================-
;------- Park ----------------------------------------------------------------------
;--=================================================================================-

global AFC_park = {-1,-1,0} ; Park location in X, Y and Z

;--=================================================================================-
;------- Tip Forming ---------------------------------------------------------------
;--=================================================================================-

; This is the initial press of the filament into the tip before any cooling moves.
global AFC_tip_ramming_volume = 0

; Set this if you would like a temperature reduction during the tip formation.
; If using skinny_dip, this change will happen before.
global AFC_tip_toolchange_temp = 0

; This step is split into two different movements. First, a fast move to separate the filament
; from the hot zone. Next, a slower movement over the remaining distance of the cooling tube.
global AFC_tip_unloading_speed = {40,15} ; fast speed (mm/s), cooling tube move (mm/s)

; This stage moves the filament back and forth in the cooling tube section of the hotend.
; It helps keep the tip shape uniform with the filament path to prevent clogs.
global AFC_tip_cooling = {35,10,10,50,4} 
; Start of the cooling tube in mm.
; Length of the move in mm.
; Initial movement speed to start solidifying the tip in mm/s.
; Fast movement speed in mm/s.
; Number of back and forth moves in the cooling tube.

; This is a final move to burn off any hairs possibly on the end of stringy materials like PLA.
; If you use this, it should be the last thing you tune after achieving a solid tip shape.
global AFC_tip_use_skinnydip = false ; Enable skinny dip moves (for burning off filament hairs).
global AFC_tip_skinnydip = {30,30,70,0,0}
; Distance to reinsert the filament, starting at the end of the cooling tube in mm.
; Insertion speed for burning off filament hairs in mm/s.
; Extraction speed (set to around 2x the insertion speed) in mm/s.
; Pause time in the melt zone in seconds.
; Pause time in the cooling zone after the dip in seconds.

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
global AFC_lane_filament_type = {"None","None","None","None"}
global AFC_lane_filament_type1 = {"None","None","None","None"}

; ########## Additional Info ##########
global additional_length=0
global AFC_LED_array={0,0,0,0}

global AFC_time=0

global AFC_debug=true