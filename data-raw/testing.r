# Metadata ----
# Authors: Adam Shepardson
# Contact: apshepardson@albany.edu
# Date Last Edited: 02/10/2026
# Purpose: Test QOR package functions

# Path
local_path <- "~/GitHub/Academic/QOR/"

# Download necessary files for testing (too big to store on GitHub)
source(paste0(local_path, "data-raw/download_data.r"))

# Re-compile package and load QOR
devtools::document("~/GitHub/Academic/QOR")
devtools::load_all("~/GitHub/Academic/QOR")

# Re-compile github website
pkgdown::build_site("~/GitHub/Academic/QOR")

# Load testing data
test <- haven::read_dta(system.file("example_data", "sample_2022_addresses.dta", package = "QOR"))

# Load shapefiles
state_shape <- sf::read_sf(dsn = paste0(local_path, "data-raw/Extracted/North_Carolina_State_Boundary")) %>%
    dplyr::summarize(geometry = sf::st_union(geometry)) # made up of separate counties by default
zip_shape <- sf::read_sf(dsn = paste0(local_path, "data-raw/Extracted/ZIP_2022"))
district_shape <- sf::read_sf(dsn = paste0(local_path, "data-raw/Extracted/SCHOOL_SY2022"))

# Query test
test_query <- query(
  units = example,
  unit_id = "statevoterid",
  street = "street",
  city = "city",
  state = "state",
  state_shape = state_shape,
  units_per_batch = 4000,
  method = "census",
  sleep_time = 2,
  year = 2022,
  zip_id = "postalcode",
  max_tries = 15
)

matched <- test_query[[1]]
unmatched <- test_query[[2]]

# Overlay test
test_overlay <- overlay(
  points = matched,
  polygons = district_shape,
  point_id = "statevoterid",
  polygon_id = "GEOID",
  used_NCES = TRUE,
  FIPS_code = "37",
  FIPS_col = "STATEFP"
)

# Recover test
test_recover <- recover(
  units = unmatched,
  polygons = district_shape,
  zipcodes = zip_shape,
  unit_id = "statevoterid",
  unit_zip = "postalcode",
  polygon_id = "GEOID",
  zip_id = "ZCTA5CE20",
  state_shape = state_shape,
  used_NCES = TRUE,
  FIPS_code = "37",
  FIPS_col = "STATEFP"
)