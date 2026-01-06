# Metadata ----
# Authors: Adam Shepardson
# Contact: apshepardson@albany.edu
# Date Last Edited: 1/06/2026
# Purpose: Download files and Create Small Sample of Voter Addresses for Package Testing
# Note: In our case, NC and WA both did not change their # of public school districts within the panel years, and even border adjustments during each panel's years were minimal according to NCES records. 
# For other states and/or time ranges, more caution about which years are used for the school district shapes is likely warranted

# Load relevant packages -----
library(tidyverse) # best practices for handling data in R
library(dplyr) # best practices for handling data in R
library(haven) # read and write .dta files
library(utils) # for download.file() and unzip()
library(RStata) # for running Stata from R

## Grab a small random sample of 2022 voter registration data for North Carolina
# URLs for relevant year 2022 data files (These are .zip files that need to be unzipped)
extracts <- "https://www.dropbox.com/scl/fi/ayb9s98b5tzr3hfo28baj/Example-Extracts.zip?rlkey=bq5pvd4i8y1mxvnmxnapo27bb&st=q4hg1lmv&dl=1"
zip_codes <- "https://www.dropbox.com/scl/fi/sq0mudsvm1g7c9ljbiye1/ZIP_2022.zip?rlkey=v9gqxsx0b1dli7lnoi95qwlyv&st=p7lprz1m&dl=1"
state_shape <- "https://www.dropbox.com/scl/fi/a8bn3ht1d67xd412zixf5/North_Carolina_State_Boundary.zip?rlkey=2j0at3vvts5i62trqvm4itpa5&st=0soqpq4j&dl=1"
district_shapes <- "https://www.dropbox.com/scl/fi/eh557z55pg9051dq4mves/SCHOOL_SY2022.zip?rlkey=ds8a7pocgj7evgsmvhsn9dyow&st=tecyt8yc&dl=1"
options(timeout = 1000) # timeout for download.file() is, bizzarely, a global option

# Download voter registration extracts (Taken Jan. 1, 2022)
download.file(url = extracts, destfile = paste0(local_path, "data-raw/Downloads/Extracts_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "data-raw/Downloads/Extracts_2022.zip"), exdir = paste0(local_path, "data-raw/Extracted"))

# Download necessary shapefiles for 2022 example
download.file(url = zip_codes, destfile = paste0(local_path, "data-raw/Downloads/zip_codes_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "data-raw/Downloads/zip_codes_2022.zip"), exdir = paste0(local_path, "data-raw/Extracted"))
download.file(url = state_shape, destfile = paste0(local_path, "data-raw/Downloads/state_shape.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "data-raw/Downloads/state_shape.zip"), exdir = paste0(local_path, "data-raw/Extracted"))
download.file(url = district_shapes, destfile = paste0(local_path, "data-raw/Downloads/district_shapes_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "data-raw/Downloads/district_shapes_2022.zip"), exdir = paste0(local_path, "data-raw/Extracted")) 

# Take a small random sample covering 0.5% of the 2022 registered voters from North Carolina
set.seed(5)
sample <- read_dta(paste0(local_path, "data-raw/Extracted/Example Extracts/VR_Snapshot_2022_ACTIVE.dta")) %>%
    bind_rows(., read_dta(paste0(local_path, "data-raw/Extracted/Example Extracts/VR_Snapshot_2022_INACTIVETEMP.dta"))) %>%
    slice_sample(prop = .005)
write_dta(sample, paste0(local_path, "data-raw/Extracted/sample_2022.dta"))

# Now run QOR/data-raw/NCAddresses.do to make the sample ready for geocoding
options("RStata.StataPath" = "/usr/local/stata19/stata-se") # Use console version instead of GUI (stata-se instead of xstata-se)
suppressWarnings(stata(src = paste0(local_path, "data-raw/NCAddresses.do"), stata.version = 19.5))
# Note: The above line requires the RStata package (install.packages("RStata")) and a local installation of Stata
# If using GUI version (xstata-se), GTK warnings may appear but can be ignored if output is correct