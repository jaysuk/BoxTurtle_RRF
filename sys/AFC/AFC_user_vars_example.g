;--=================================================================================-
;------- General Settings -----------------------------------------------------------
;--=================================================================================-

; AFC CAN Address
; This is the default CAN address of the AFC-Lite board running RRF
set global.AFC_CAN_address = 119

; This sets the S value used in M569
; Snnn Direction of movement of the motor(s) attached to this driver: 0 = backwards, 1 = forwards
; There should be no need to adjust this with a default AFC build
set global.AFC_stepper_direction = {0,0,0,0}

; This sets the microstepping used by each of the lane stepper motors. There should be no need to adjust this with a default AFC build
; This can be set to 1, 2, 4, 8, 16, 32, 64, 128 and 256. If you adjust this setting make sure you adjust the steps per mm to suit
set global.AFC_microsteps = {16,16,16,16}

; This sets the steps per mm of each lane. There should be no need to adjust this with a default AFC build
set global.AFC_steps_per_mm = {682,682,682,682}

; This is the current used by each stepper driver. 
; This is in mA.
; There should be no need to adjust this with a default AFC build
set global.AFC_stepper_current = {1000,1000,1000,1000}

; This is the jerk setting for motor jerk set per lane. 
; These are in mm/s
; There should be no need to adjust this with a default AFC build
set global.AFC_stepper_jerk = {60,60,60,60}                             ; lanes 0 to 3 and then for the extruder

; This is the maximum speed for each lane. 
; These are in mm/s
; There should be no need to adjust this with a default AFC build
set global.AFC_stepper_max_speed = {60,60,60,60}                   ; lanes 0 to 3 and then for the extruder

; This is the maximum acceleration for each lane. 
; These are in mm/s2
; There should be no need to adjust this with a default AFC build
set global.AFC_stepper_acc = {3000,3000,3000,3000}

; This is the load and retract speeds used when using the lanes.
; First value is the load speed
; Second value is the unload speed
; Third value is the load speed of the extruder
; The values are in mm/s
set global.AFC_load_retract_speed = {35,35,5}

; These are the RRF trigger numbers to be used by the loading switches.
; The gcode these are used with is the T value in M581
; These will need adjusting if you have any other triggers setup.
set global.AFC_trigger_numbers = {2,3,4,5}
set global.AFC_buffer_trigger_numbers = {6,7}

; These are the used with the triggers to create the inputs
; The gcode these are used with is the J value in M950
; These will need adjusting if you have any other triggers setup.
set global.AFC_trigger_input_numbers = {0,1,2,3}
set global.AFC_buffer_input_numbers = {4,5}
set global.AFC_hub_input_number = 6
set global.AFC_unload_input_number = 7

; This is how far the filament is retracted after the hub switch is activated when doing the initial measurement.
; Its also used in filament unloading
; Changing this value will require the lane laoding length to be remeasured
set global.AFC_hub_retract_distance = 25

; This is how far the filament is retracted after the turtleneck is activated after a filament load.
; Its also used in filament unloading
; Changing this value will require the lane laoding length to be remeasured
set global.AFC_tn_retract_distance = 15

; This sets the general machine travel speeds for things like parking etc
; X and Y are the first value, Z is the second value.
; Both values are in mm/s
set global.AFC_travel_speed = {150, 5} 

; This sets whether there are any debug messages or not
; The default is false
set global.AFC_debug = false

; This sets which features of the load/unload process you want to enable
; They are in the order of
; brush
var brush = false
; cut
var cut = false
; kick
var kick = false
; park
var park = false
; poop
var poop = false
; purge
var purge = false
; use measure lengths for load/unload
var meas = false
; carry out a startup check
var start = false
; use the DC motor to rewind the filament
var dc = false

; This is the Object Model Number of the axis we use for loading the filament. 
; If you just have X, Y and Z then this should be set to 2. Each additional axis you've added will increment this number
set global.om_axis_number = 3

; These are the measurements of your extruder setup. 
; Overall length from input to nozzle, input to cutter, cutter to nozzle. All values are in mm
set global.main_extruder_measurements = {125,40,80} ; These are the measurements of your extruder setup. Overall length from input to nozzle, input to cutter, cutter to nozzle

; This is the driver number of each lane on the board. This will not need editing if using an AFC board
var driver_number = {0.0,0.1,0.2,0.3} 

; These are the SLP pins for the motor. This will not need editing if using an AFC board
var SLP_pins = {"SLP1","SLP2","SLP3","SLP4"} 

; These are the DC1 pins for the motor. This will not need editing if using an AFC board
var DC1_pins = {"dc11","dc12","dc13","dc14"} 

; These are the DC2 pins for the motor. This will not need editing if using an AFC board
var DC2_pins = {"dc21","dc22","dc23","dc24"} 

; These are the prep switch pins. This will not need editing if using an AFC board
var prep_switch = {"SW2","SW3","SW4","SW5"} 

; These are the load switch pins. This will not need editing if using an AFC board
var load_switch = {"SW7","SW8","SW9","SW10"} 

; These are the turtle neck pins. This will not need editing if using an AFC board
var turtleneck_switches = {"SW11","SW12"} 

; This is the hub switch. This will not need editing if using an AFC board
var hub_switch = "SW1" 

; This is the neopixel pin. This will not need editing if using an AFC board
var neopixel_pin = "neopixel1"

; These are the neopixel settings
; LED number (M950 E code)
; LED Type (M950 T code)
; Number of LEDs (M950 U code)
set global.AFC_neopixel_settings = {0,2,4}

; This is the OM number of the main extruder
; Default is 0
set global.main_extruder_om = 0

; This is the output numbers for the DC motors
; Used by M950. Change if you already have outputs setup
set global.AFC_dcm_out_no = {0,1,2}

;--=================================================================================-
;------- Cut -----------------------------------------------------------------------
;--=================================================================================-

; This should be the position of the toolhead where the cutter arm just
; lightly touches the depressor pin
; The first value is the x coordinate and the second value is the y coordinate
set global.AFC_cut_location = {-1,-1} 

; Direction to make the cut move (left, right, front, back).
; Make sure the word you change to is all lowercase
set global.AFC_cut_direction = "left" 

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
set global.AFC_cut_dist = {6.0,8.0} ; park (mm) and move (mm)

; Speed related settings for tip cutting
; Note that if the cut speed is too fast, the steppers can lose steps.
; Therefore, for a cut:
; - We first make a fast move to accumulate some momentum and get the cut
;   blade to the initial contact with the filament
; - We then make a slow move for the actual cut to happen 
set global.AFC_cut_move = {32,10,150,50,0.85,25,2} ; Fast speed (mm/s), slow speed (mm/s), evacuate speed (mm/s), dwell time (ms), fast move fraction, extruder move speed (ms) and cut count

;If the toolhead returns to initial position after the cut is complete.
;set global.AFC_cut_restore_pos = false ; True = return to initial position, False = don't return

; Distance to retract prior to making the cut, this reduces wasted filament but might cause clog 
; if set too large and/or if there are gaps in the hotend assembly 
; *This must be less than the distance from the nozzle to the cutter
set global.AFC_cut_retract_length = 30 ; Distance (mm)

; This can help prevent clogging of some toolheads by doing a quick tip from to reduce stringing
set global.AFC_cut_quick_tip_forming = false ; true or false

; Retract length and speed after the cut so that the cutter can go back 
; into its origin position
set global.AFC_cut_rip = {1.0,3} ; Distance (mm), speed (mm/s)

; Pushback of the remaining tip from the cold end into the hotend
; *Must be less then retract_length
set global.AFC_cut_pushback = {25,20} ; Distance (mm) and time to dwell between the pushback

; Safety margin for fast vs slow travel. When traveling to the pin location
; we make a safer but longer move if we are closer to the pin than this
; specified margin. Usually setting these to the size of the toolhead
; (plus a small margin) should be good enough 
set global.AFC_cut_safe_margin = {30,30} ; X and Y, approx toolhead width +5mm

; Some printers may need a boost of power to complete the cut without skipping steps.
; One option is to increase the current for thost steppers in config.g. Another
; option is to use these variables to set a current that is only used during the
; cut motion. Different combinations of kinematics and cutter configurations engage
; different combinations of steppers for that motion.  Set the needed variables.
; The override is skipped if the current is 0.
; Enable if layer shifts occur when cutting
set global.AFC_cut_current_stepper = {0,0,0} ; X, Y and Z in mA

;--=================================================================================-
;------- Poop ----------------------------------------------------------------------
;--=================================================================================-

; Sets the poop location in X and Y
set global.AFC_purge_location = {-1,-1} ; X, Y location of where to purge

; Sets the extrusion speed for the purge
set global.AFC_purge_speed = 6.5 ; speed (mm/s) of the purge

; Speed, in mm/s to lift z after the purge is completed. Its a faster lift to keep it from 
; sticking to the toolhead
set global.AFC_purge_fast_z = {200,20} ; speed (mm/s), distance (mm)

; If the toolhead returns to initial position after the poop is complete.
set global.AFC_purge_restore = false ; True = return to initial position, False = don't return

; The height to raise the nozzle above the tray before purging. This allows any built up 
; pressure to escape before the purge.
set global.AFC_purge_start = 0.6

; Set the part cooling fan speed. Disabling can help prevent the nozzle from cooling down 
; and stimulate flow, Enabling it can prevent blobs from sticking together.
set global.AFC_part_cooling_fan = {true,1.0,2} ; Run at full speed, speed to run fan when enabled, time to pause after purge to allow fan to cool the poop (s)

; ==================== PURGE LENGTH TUNING
; Default purge length to fall back on when neither the tool map purge_volumes or 
; parameter PURGE_LENGTH is set.
set global.AFC_purge_length = {72.111,60.999} ; Default purge length (mm), absolute minimum purge length (mm)

; The slicer values often are a bit too wasteful. Tune it here to get optimal values. 0.6
; is a good starting point.
;set global.AFC_purge_length_modifier = 1

; Length of filament to add after the purge volume. Purge volumes don't always take 
; cutters into account and therefor a swap from red to white might be long enough, but 
; from white to red can be far too short. When should you alter this value:
;   INCREASE: When the dark to light swaps are good, but light to dark aren't.
;   DECREASE: When the light to dark swaps are good, but dark to light aren't. Don't 
;     forget to increase the purge_length_modifier
;set global.AFC_purge_length_addition = 0

;--=================================================================================-
;------- Kick ----------------------------------------------------------------------
;--=================================================================================-

; Location to move before kick - X, Y and Z
; Height to drop to for kick move
; Speed of kick movement
; Accel of kick moves. This will overwrite the global accel for this macro. Set to 0 to use global accel
; Direction to make the kick move (left, right, front, back)
; How far to move to kick poop off
; Height of z after kick move
set global.AFC_kick = {-1,-1,10,1.5,150,0,"right",45,10}

;--=================================================================================-
;------- Brush ---------------------------------------------------------------------
;--=================================================================================-

; Position of the center of the brush (Set z to -1 if you dont want a z move) - X, Y and Z
; Speed of cleaning moves when brushing
; Total width in mm of the brush in the X direction
; Total depth in mm of the brush in the Y direction
; True - Brush along Y axis first then X. False - Only brush along x
; Number of passes to make on the brush.
; Whether the brush is on a servo
; Servo pin number
; Deployed angle
; Retracted angle
; Servo number (for M950)
set global.AFC_brush = {-1,-1,-1,150,30,10,true,4,false,"0.PE6",110,20,10}

;--=================================================================================-
;------- Park ----------------------------------------------------------------------
;--=================================================================================-

set global.AFC_park = {-1,-1,0} ; Park location in X, Y and Z

;--=================================================================================-
;------- Tip Forming ---------------------------------------------------------------
;--=================================================================================-

; This is the initial press of the filament into the tip before any cooling moves.
set global.AFC_tip_ramming_volume = 0

; Set this if you would like a temperature reduction during the tip formation.
; If using skinny_dip, this change will happen before.
set global.AFC_tip_toolchange_temp = 0

; This step is split into two different movements. First, a fast move to separate the filament
; from the hot zone. Next, a slower movement over the remaining distance of the cooling tube.
set global.AFC_tip_unloading_speed = {40,15} ; fast speed (mm/s), cooling tube move (mm/s)

; This stage moves the filament back and forth in the cooling tube section of the hotend.
; It helps keep the tip shape uniform with the filament path to prevent clogs.
set global.AFC_tip_cooling = {35,10,10,50,4} 
; Start of the cooling tube in mm.
; Length of the move in mm.
; Initial movement speed to start solidifying the tip in mm/s.
; Fast movement speed in mm/s.
; Number of back and forth moves in the cooling tube.

; This is a final move to burn off any hairs possibly on the end of stringy materials like PLA.
; If you use this, it should be the last thing you tune after achieving a solid tip shape.
set global.AFC_tip_use_skinnydip = false ; Enable skinny dip moves (for burning off filament hairs).
set global.AFC_tip_skinnydip = {30,30,70,0,0}
; Distance to reinsert the filament, starting at the end of the cooling tube in mm.
; Insertion speed for burning off filament hairs in mm/s.
; Extraction speed (set to around 2x the insertion speed) in mm/s.
; Pause time in the melt zone in seconds.
; Pause time in the cooling zone after the dip in seconds.

; ########## DO NOT EDIT PAST HERE!!! ################

set global.AFC_driver_number = {{global.AFC_CAN_address+var.driver_number[0]+0.0001},{global.AFC_CAN_address+var.driver_number[1]+0.0001},{global.AFC_CAN_address+var.driver_number[2]+0.0001},{global.AFC_CAN_address+var.driver_number[3]+0.0001}}
set global.AFC_SLP_pins = {{global.AFC_CAN_address^"."^var.SLP_pins[0]},{global.AFC_CAN_address^"."^var.SLP_pins[1]},{global.AFC_CAN_address^"."^var.SLP_pins[2]},{global.AFC_CAN_address^"."^var.SLP_pins[3]}}         ; These are the SLP pins used by the DC motors
set global.AFC_DC1_pins = {{global.AFC_CAN_address^"."^var.DC1_pins[0]},{global.AFC_CAN_address^"."^var.DC1_pins[1]},{global.AFC_CAN_address^"."^var.DC1_pins[2]},{global.AFC_CAN_address^"."^var.DC1_pins[3]}}         ; These are the DC1 pins used by the DC motors
set global.AFC_DC2_pins = {{global.AFC_CAN_address^"."^var.DC2_pins[0]},{global.AFC_CAN_address^"."^var.DC2_pins[1]},{global.AFC_CAN_address^"."^var.DC2_pins[2]},{global.AFC_CAN_address^"."^var.DC2_pins[3]}}         ; These are the DC2 pins used by the DC motors
set global.AFC_prep_switch = {{"^!"^global.AFC_CAN_address^"."^var.prep_switch[0]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[1]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[2]},{"^!"^global.AFC_CAN_address^"."^var.prep_switch[3]}} ; These are the prep switches of each lane
set global.AFC_load_switch = {{global.AFC_CAN_address^"."^var.load_switch[0]},{global.AFC_CAN_address^"."^var.load_switch[1]},{global.AFC_CAN_address^"."^var.load_switch[2]},{global.AFC_CAN_address^"."^var.load_switch[3]}}        ; These are the load switches of each lane
set global.TN_switches = {{global.AFC_CAN_address^"."^var.turtleneck_switches[0]},{global.AFC_CAN_address^"."^var.turtleneck_switches[1]}}                                ; These are in the order of Advance and Trailing
set global.AFC_hub_switch = {"^"^global.AFC_CAN_address^"."^var.hub_switch}
set global.AFC_neopixel_pin = {global.AFC_CAN_address^"."^var.neopixel_pin}

set global.AFC_features={var.brush,var.cut,var.kick,var.park,var.poop,var.purge,var.meas,var.start,var.dc}