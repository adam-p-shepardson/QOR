clear all

// Set up path
global path "~/GitHub/Academic/QOR" // replace with your local path to the QOR repository

cd "$path/"

local y = 2022

**Extract all NC addresses from the registered voters in 2022
use "data-raw/Extracted/sample_`y'.dta", clear

* Make changes to facilitate geocoding
// Rename to a logical geocoding format
rename ncid statevoterid
rename house_num regstnum
rename half_code regstfrac
rename street_dir regstpredirection
rename street_name regstname
rename street_type_cd regsttype 
rename street_sufx_cd regstpostdirection
rename unit_designator regunittype
rename unit_num regunitnum
rename res_city_desc regcity
rename state_cd regstate
rename zip_code regzipcode
// Ensure that all are strings
tostring(statevoterid), replace
tostring(regstnum), replace
tostring(regstfrac), replace
tostring(regstpredirection), replace
tostring(regstname), replace
tostring(regsttype), replace
tostring(regstpostdirection), replace
tostring(regunittype), replace
tostring(regunitnum), replace
tostring(regcity), replace
tostring(regstate), replace
tostring(regzipcode), replace
// Make sure that blank street component values are properly recorded as missing
replace regstnum = "" if regstnum == " "
replace regstfrac = "" if regstfrac == " "
replace regstname = "" if regstname == " "
replace regsttype = "" if regsttype == " "
replace regunittype = "" if regunittype == " "
replace regstpredirection = "" if regstpredirection == " "
replace regstpostdirection = "" if regstpostdirection == " "
replace regunitnum = "" if regunitnum == " "
// Remove all leading and trailing blanks
replace statevoterid = strtrim(statevoterid)
replace regstnum = strtrim(regstnum)
replace regstfrac = strtrim(regstfrac)
replace regstname = strtrim(regstname)
replace regsttype = strtrim(regsttype)
replace regunittype = strtrim(regunittype)
replace regstpredirection = strtrim(regstpredirection)
replace regstpostdirection = strtrim(regstpostdirection)
replace regunitnum = strtrim(regunitnum)
replace regcity = strtrim(regcity)
replace regstate = strtrim(regstate)
replace regzipcode = strtrim(regzipcode)
// Generate full_address from component strings
gen full_address = ""
replace full_address = regstnum + " " + regstfrac + " " + regstpredirection + " " + regstname + " " + regsttype + " " + regstpostdirection + " " + regunittype + " " + regunitnum + ", " + regcity + ", " + regstate + " " + regzipcode 
//gen full_address = ""
//replace full_address = regstnum + " " + regstfrac + " " + regstpredirection + " " + regstname + " " + regsttype + " " + regstpostdirection + ", " + regcity + ", " + regstate
replace full_address = strtrim(full_address)
// Generate simple components for address variables
gen street = ""
replace street = regstnum + " " + regstfrac + " " + regstpredirection + " " + regstname + " " + regsttype + " " + regstpostdirection + " " + regunittype + " " + regunitnum 
//gen street = ""
//replace street = regstnum + " " + regstfrac + " " + regstpredirection + " " + regstname + " " + regsttype + " " + regstpostdirection 
replace street = strtrim(street)
gen city = regcity
gen state = regstate
gen postalcode = regzipcode
// keep only the variables that I want
keep statevoterid full_address street city state postalcode

// Write cleaned address dataset
save "inst/example_data/sample_`y'_addresses.dta", replace
