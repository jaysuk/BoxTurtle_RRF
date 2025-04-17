# BoxTurtle_RRF

This repository add RRF support for the BoxTurtle Automated Filament Control

## Features currently implemented

So far this has the following features implemented:

* Brush - tested
* Cut - tested
* Kick - untested
* Poop - untested
* Purge - tests
* filament runout - untested

It is highly recommended to run this with a cutter on your printer as there is currently no tip forming enabled.  
This also only works with one AFC. Connecting multiple AFC's is currently not supported.

### Brushing Notes

It is assumed that the macros will have full control of deploying and retracting the brush (if its servo based).  
If you already have the brush setup, create two macros in the AFC folder called "brush_deploy.g" and "brush_retract.g" and include in them the commands required to deploy and retract your brush.

## How to use

Ensure the AFC is flashed with the correct version of RRF and connect it to your printer.
Copy all the files to your sys and macros folders.  
Add the following to the very end of your config.g.

```text
G4 S2

M98 P"0:/sys/AFC/AFC.g"
```

Make sure you remove `T0` or similar from your config.g
Rename the file "AFC_user_vars_example.g" in the AFC folder to "AFC_user_vars.g" and edit each of the variables to suit your machine.  
Remember to enable the features you want to use.  
Reboot your printer.  
Run the macro "Create System Files" and select all.
Load some filemant to each lane.
Run the macro "Lane - Measure First" for each lane.
Run the macro "Measure Main Length" choosing one of the lanes to use. It doesn't matter which.

I have also included a print_start.g file and a stop.g file. These should be suitable for using with your machine.  

## Slicer Setup

Orcaslicer is the recommended slicer to use.

Setup your slicer as per the instructions [here](https://github.com/ArmoredTurtle/BoxTurtle/blob/main/Initial_Startup.md#configuring-your-slicer).  

Add the following to the machine start gcode

```text
M104 S0 ; Stops OrcaSlicer from sending temperature waits separately
M140 S0 ; Stops OrcaSlicer from sending temperature waits separately
M98 P"start_print.g" A{first_layer_bed_temperature[0]} B"{filament_type[0]}" C{first_layer_temperature[0]} D{nozzle_diameter[0]} E{first_layer_print_min[0]} F{first_layer_print_max[0]} H{first_layer_print_min[1]} J{first_layer_print_max[1]} K{initial_tool}
```

To the change filament g-code add the following

```text
M98 P"0:/sys/AFC/set_temp_global.g" A[next_extruder] B[new_filament_temp]
T[next_extruder]
```

## BtnCmd

I have also included a basic BtnCmd setup for the AFC that I will be improving when I get time.
