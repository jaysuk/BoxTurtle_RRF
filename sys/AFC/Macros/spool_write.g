; ==========================================================================================
; Spool - Write (spool_write.g)
; Serializes the data for an active spool back to its physical .g file on the SD card.
;
; Parameters:
; param.U - Unit number
; param.L - Lane number
; ==========================================================================================

if !exists(param.U) || !exists(param.L)
    M118 S"Error: Missing unit (U) or lane (L) parameter for spool_write.g"
    M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/spool_write.g" S1
    abort

var spool_id = global.spool_active_data[param.U][param.L][0]

; If no spool is loaded (ID is -1), there is nothing to write.
if var.spool_id == -1
    M118 S"Error: No spool loaded on this lane for spool_write.g"
    M291 P{"Aborting macro. Line "^line} R"0:/sys/AFC/Macros/spool_write.g" S1
    abort

; Re-construct the file line by line
; Data schema: {SpoolID, FilamentType, Color, Manufacturer, InitialLength, RemainingLength, DateFirstUsed, DateLastUsed, HexColor, Price, EmptyWeight, Density}

; Use strict 3-quote escaping for strings to ensure valid G-Code is written back out
; e.g. """PLA""" writes as "PLA"
var string_type = """" ^ global.spool_active_data[param.U][param.L][1] ^ """"
var string_color = """" ^ global.spool_active_data[param.U][param.L][2] ^ """"
var string_manuf = """" ^ global.spool_active_data[param.U][param.L][3] ^ """"
var string_datefirst = """" ^ global.spool_active_data[param.U][param.L][6] ^ """"
var string_datelast = """" ^ global.spool_active_data[param.U][param.L][7] ^ """"
var string_hex = """" ^ global.spool_active_data[param.U][param.L][8] ^ """"

var num_initial = global.spool_active_data[param.U][param.L][4]
var num_remain = global.spool_active_data[param.U][param.L][5]
var num_price = global.spool_active_data[param.U][param.L][9]
var num_empty = global.spool_active_data[param.U][param.L][10]
var num_density = global.spool_active_data[param.U][param.L][11]

var json_part1 = "; {""id"": " ^ var.spool_id ^ ", ""type"": " ^ var.string_type ^ ", ""color"": " ^ var.string_color
var json_part2 = ", ""manuf"": " ^ var.string_manuf ^ ", ""initial"": " ^ var.num_initial
var json_part3 = ", ""remaining"": " ^ var.num_remain ^ ", ""first"": " ^ var.string_datefirst ^ ", ""last"": " ^ var.string_datelast ^ ", ""hex"": " ^ var.string_hex 
var json_part4 = ", ""price"": " ^ var.num_price ^ ", ""empty"": " ^ var.num_empty ^ ", ""density"": " ^ var.num_density ^ "}"
var json_payload = var.json_part1 ^ var.json_part2 ^ var.json_part3 ^ var.json_part4
echo >{"0:/spools/" ^ var.spool_id ^ ".g"} var.json_payload

var p_part1 = "{" ^ var.spool_id ^ ", " ^ var.string_type ^ ", " ^ var.string_color ^ ", " ^ var.string_manuf 
var p_part2 = ", " ^ var.num_initial ^ ", " ^ var.num_remain ^ ", " ^ var.string_datefirst ^ ", " ^ var.string_datelast 
var p_part3 = ", " ^ var.string_hex ^ ", " ^ var.num_price ^ ", " ^ var.num_empty ^ ", " ^ var.num_density ^ "}"
var payload = var.p_part1 ^ var.p_part2 ^ var.p_part3

echo >>{"0:/spools/" ^ var.spool_id ^ ".g"} "set global.spool_load_temp = " ^ var.payload

; Update AFC_lanes with the type and color so DWC/other macros see it
set global.AFC_lanes[param.U][param.L][4] = {global.spool_active_data[param.U][param.L][1], global.spool_active_data[param.U][param.L][2]}
