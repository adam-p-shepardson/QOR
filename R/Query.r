#' Geocode Unit (Voter) Addresses to Longitude/Latitude Coordinates
#'
#' The `query()` function performs the "Query" (Step 1) operation from the QOR Method.
#'
#' This function:
#' - Assigns longitude and latitude coordinates to units (e.g., voters) based on their street address, city, and state.
#' - Acts as a wrapper around `tidygeocoder::geocode()`, while also handling additional processing needed for individual voter data and preparing for subsequent QOR Method steps.
#' - **Note:** This function does not perform matching to polygons below the state-level or to zip codes; it simply geocodes the addresses.
#' - Focuses on the Census geocoding service accessible through the `tidygeocoder` package (we recommend using the "census" method for best results). You will need to modify the code to use different geocoding services.
#'
#' @param units Dataframe or tibble containing voter information (must have unique unit_id, street, city, and state columns).
#' @param unit_id Name of the column in the units dataframe that contains the unique identifiers for each unit (default: "unit_id"). Preferably as string.
#' @param street Name of the column in the units dataframe that contains the street address (default: "street").
#' @param city Name of the column in the units dataframe that contains the city (default: "city").
#' @param state Name of the column in the units dataframe that contains the state (default: "state").
#' @param state_shape sf object containing the shape of the state (used to filter geocoding results to the state, catching errors).
#' @param year Year of the data (preferably numeric) for use with "census" method. (default: NULL, which throws an error). Program was designed for years 2007 through 2025 using the "census" method. Years <= 2010 will use the 2010 Census database, and years > 2025 will use the current Census database.
#' @param units_per_batch Number of units to geocode in each batch (default: 4000). Internet connectivity and API limits determine possibility of larger (or smaller) batches. The Census theoretically allows batches of up to 10,000 addresses, but we have found that smaller batches are less likely to be rejected by the API.
#' @param method Geocoding method to use (default: "census"). See methods from `tidygeocoder::geocode()`. We recommend "census" for best cost (free) and batch geocoding, and it is the only supported method currently. You may need to adjust parts of code that select outputs if using different method, and not all methods may support the batch coding that we use by default.
#' @param sleep_time Time to pause between batches (default: 2 seconds). Try increasing if you are getting rate-limited by the geocoding service or encountering connection issues.
#' @param unit_zip RECOMMENDED BUT OPTIONAL name of the column in the units dataframe that contains the postal code (default: "postalcode"). Preferably as string. Output will return this column if provided. "Recover" will NOT be able to match any unmatched units if postalcode not provided here.
#' @param max_tries Number of times to attempt geocoding for each unit if a call to API fails (default: 15). Try increasing if you are getting rate-limited by the geocoding service or encountering connection issues. If a unit fails to geocode after this many attempts, it will be stored as unmatched and the function will move on to the next unit.
#'
#' @return A list with two items: (1) Tibble of matched units with their geocoded coordinates, and (2) Tibble of unmatched units (those that could not be geocoded).
#'
#' @importFrom dplyr mutate filter bind_rows tibble across everything
#' @importFrom magrittr %>%
#' @importFrom tictoc tic.clearlog tic toc
#' @importFrom tidygeocoder geocode
#' @importFrom sf st_crs st_transform st_make_valid st_filter st_drop_geometry st_sfc st_multipoint st_cast st_sf
#' @importFrom rlang .data
#' @export
query <- function(units = NULL, unit_id = "unit_id", street = "street", city = "city", state = "state", state_shape = NULL, 
units_per_batch = 4000, year = NULL, method = "census", sleep_time = 2, unit_zip = "postalcode", max_tries = 15) {

    tictoc::tic.clearlog() # clear time log as safety check
    tictoc::tic("Runtime: Query Full Time") # Start timer for the entire query process

    # Check that the inputs are valid
    if (!is.data.frame(units)) {
        stop("Units must be a data.frame or tibble object.")
    } else if (is.null(units) || is.null(street) || is.null(city) || is.null(state) || is.null(state_shape) || is.null(unit_id) || nrow(units) == 0) {
        stop("The units dataset with column names for street, city, state, and unique unit_id, as well as a state shapefile, must all be provided.")
    } else if (!unit_id %in% names(units) || length((unique(units[[unit_id]]))) != length(units[[unit_id]])) { 
        stop(paste("The unit_id ('", unit_id, "') is either not found in the units dataset or does not uniquely identify each row.", sep = ""))
    } else if (!street %in% names(units) || !city %in% names(units) || !state %in% names(units)) {
        stop(paste("The street ('", street, "'), city ('", city, "'), or state ('", state, "') is not found in the units dataset.", sep = ""))
    } else if (!inherits(state_shape, "sf")) {
        stop("State shape must be an sf object (convert to sf format using functions from sf package).")
    } else if (!is.character(units[[street]])|| !is.character(units[[city]]) || !is.character(units[[state]])) {
        stop("street, city, and state fields must all be string variables.")
    } else if (is.null(year) && method == "census") {
        stop(paste("No year value provided. Need a year to select the closest geocoding database to use for 'census' method."))
    } else if (method != "census") {
        stop(paste("CAUTION We have only tested the 'census' method for geocoding, and other methods may not work with the batch geocoding approach we use and the current code. If you are using a different method please modify our source code."))
    } else {
        # Convert custom names to standard names
        colnames(units)[colnames(units) == unit_id] <- "unit_id" 
            if (!is.character(units$unit_id)) {
                units$unit_id <- as.character(units$unit_id)
            }
        colnames(units)[colnames(units) == street] <- "strt"
        colnames(units)[colnames(units) == city] <- "cty"
        colnames(units)[colnames(units) == state] <- "ste"
        
        if(!is.null(unit_zip) && unit_zip %in% names(units)) { 
            colnames(units)[colnames(units) == unit_zip] <- "postalcode"
            if(!is.character(units$postalcode)) {
                units$postalcode <- as.character(units$postalcode)
            }
        } else {
            units$postalcode <- NA # create a column for postalcode if not provided
            warning(paste("No postalcode column provided or found in units dataset. This will limit the ability to recover unmatched units later."))
        }

        # turn year into numeric
        yr <- as.numeric(year)
        if (is.na(yr)) {
            stop(paste("Year must be covertable to numeric."))
        }

        # Take User's method
        mthd <- as.character(method)
    }

    ## Split the units into batches
    # How many units?
    unitnum <- nrow(units)
    # How many possible groups (round *up* to nearest whole) (How many units you can actually put in each group seems to depend on a mixture of your internet connection and the Census API limits)
    unitgroups <- unitnum / units_per_batch
    unitgroups <- ceiling(unitgroups)
    # Mark groups in dataset
    grp_assign <- rep(1:unitgroups, ceiling(nrow(units) / unitgroups)) # repeat 1 through # unitgroups the desired # of times
    grp_assign <- grp_assign[1:nrow(units)] # Since I round the group number, need to chop off some of the extra integers to match length of units
    units <- units %>%
        dplyr::mutate(., s_2_1_1_1_1 = grp_assign) # Each obs. is now flagged to be put into a sample group
  
    # create sample groups, store in list
    sample_list <- list()
    for(num in 1:unitgroups) {
        sample <- units %>% dplyr::filter(., .data$s_2_1_1_1_1 == num)
        sample_list[[num]] <- sample
        rm(sample)
    }

    # Set A Nearby Census Vintage (Note: these were the Census geocoder's valid vintage names through 2025 as of Feb., 2026)
    if(yr <= 2010) {
        vin <- "Census2010_Current"
    } else if(yr == 2011 || yr == 2012 || yr == 2013 || yr == 2014 || yr == 2015 || yr == 2016 || yr == 2017) {
        vin <- "ACS2017_Current"
    } else if(yr == 2018) {
        vin <- "ACS2018_Current"
    } else if(yr == 2019) {
        vin <- "ACS2019_Current"
    } else if(yr == 2020) {
        vin <- "Census2020_Current"
    } else if(yr == 2021) {
        vin <- "ACS2021_Current"
    } else if(yr == 2022) {
        vin <- "ACS2022_Current"
    } else if(yr == 2023) {
        vin <- "ACS2023_Current"
    } else if(yr == 2024) {
        vin <- "ACS2024_Current"
    } else if(yr == 2025) {
        vin <- "ACS2025_Current"
    } else {
        vin <- "Current_Current"
    }

    ## Loop through the samples, referencing the Census TIGER database for address coordinates
    coord <- tibble() # This is a fallback if geocoding for num == 1 fails
    for(num in 1:unitgroups) {
    
        # Print out ticker of where we are
        message(paste0("Now batch-geocoding unit group ", as.character(num), " out of ", as.character(unitgroups)))

        # Detect error and keep trying if there is one
        success <- FALSE 
        attempt <- 0
        while(!success && attempt < max_tries) {
            attempt <- attempt + 1
            # long tryCatch loop until there is a success. Exits to my custom error function "wait" the moment the first block returns an error
            tryCatch(
                {
                    if(num == 1) {
                        # I decided not to input postalcodes into the Census geocoder, as I know these change a lot over time.
                        coord <- sample_list[[num]] %>%
                            tidygeocoder::geocode(street = strt, city = cty, state = ste, method = mthd, lat = latitude, long = longitude,
                            full_results = TRUE, verbose = TRUE, mode = "batch", custom_query = list(vintage = vin),
                            timeout = 50) %>%
                            mutate(across(everything(), as.character))
                        Sys.sleep(sleep_time)
                    } else {
                        temp <- sample_list[[num]] %>%
                            tidygeocoder::geocode(street = strt, city = cty, state = ste, method = mthd, lat = latitude, long = longitude,
                            full_results = TRUE, verbose = TRUE, mode = "batch", custom_query = list(vintage = vin),
                            timeout = 50) %>%
                            mutate(across(everything(), as.character))
                        coord <- dplyr::bind_rows(coord, temp)
                        Sys.sleep(sleep_time)
                        rm(temp)
                    }
          
                    success <- TRUE # flag successful communication with Census website
                    message("No fatal error ^_^")
          
                }, error = function(wait) {
                    Sys.sleep(sleep_time) # pause for the specified time if there is an error
          
                    message("Retrying, I hit an error -_-")
          
                }
            )
        }
        if (!success) {
            # If failure is persistent after max_tries, bump units in batch to single geocoding and move on
            message(paste0("Failed to geocode unit group ", as.character(num), " after ", as.character(max_tries), " attempts. -_-"))
            temp <- sample_list[[num]] %>% dplyr::mutate(latitude = NA, longitude = NA) %>% dplyr::mutate(across(everything(), as.character))
            coord <- dplyr::bind_rows(coord, temp)
            rm(temp)
        }       
    }
    
    ## For any that fail to match, set them aside for now. These will be "Recovered" in the Recover() function.
    failed <- coord %>%
        dplyr::filter(., is.na(.data$latitude) | is.na(.data$longitude))
    sample2 <- units %>%
        dplyr::filter(., .data$unit_id %in% failed$unit_id) # filter down units, not coord, so that sample2 will not have extra cols from prior geocoding attempt
    # Filter out unmatched from coord
    coord <- coord %>% dplyr::filter(., !.data$unit_id %in% failed$unit_id)
  
    ### Solve as many ties and no_matches as possible by single coding (should return just one address if possible to locate any matches; takes a long time)
    ## The package creator says that this is the way to solve ties: https://jessecambon.github.io/tidygeocoder/articles/geocoder_services.html
    ## Create the dataset where I want to store the single geocoding results
    test <- dplyr::tibble()
  
    ## Filter sample2 down to one unit at a time, "trying" the single coding to fish for connection errors and restart if any
    sample2_ids <- sample2$unit_id
    id_count <- 0
  
    if(nrow(sample2) == 0) {
        message("No units failed batch geocoding, so no single-geocoding is needed.")
        still_unmatched <- tibble(unit_id = character(), strt = character(), cty = character(), ste = character(), postalcode = character()) # create an empty tibble for unmatched units if none failed batch geocoding
    } else {
        for(v in sample2_ids) {
    
            # Print out ticker of where user is
            id_count <- id_count + 1
            message(paste0("Now single-geocoding unit ", as.character(id_count), " out of the ", as.character(length(sample2_ids)), " who failed batch geocoding"))
    
            single_unit <- sample2 %>% dplyr::filter(., .data$unit_id == v) # filter to one unit
            success <- FALSE 
            attempt <- 0
            # Detect error and keep trying if there is one (see as a baseline: https://cnuge.github.io/post/trycatch/ and https://stackoverflow.com/questions/68924178/how-to-redo-trycatch-after-error-in-for-loop and https://adv-r.hadley.nz/conditions.html)
            while(!success && attempt < max_tries) {
                attempt <- attempt + 1
                # long tryCatch loop until there is a success. Exits to my custom error function "wait" the moment the first block returns an error
                tryCatch(
                    {
                    temp <- geocode(single_unit, street = strt, city = cty, state = ste, method = mthd, lat = latitude, 
                            long = longitude, verbose = TRUE, full_results = TRUE, mode = "single", limit = 1, 
                            custom_query = list(vintage = vin), timeout = 50, min_time = 1) %>%
                            dplyr::mutate(across(everything(), as.character))
          
                    # Now I can append temp to test
                    test <- dplyr::bind_rows(test, temp)
                    rm(temp, single_unit)

                    success <- TRUE # flag successful communication with Census website
          
                    message("No fatal error ^_^")
          
                }, error = function(wait) {
                    Sys.sleep(sleep_time) # pause for the specified time if there is an error

                    message("Retrying, I hit an error -_-")
          
                    }
                )
            }
            if (!success) {
            # If failure is persistent after max_tries, store unit and move on to next one
            timed_out <- single_unit %>% dplyr::mutate(latitude = NA, longitude = NA) %>% dplyr::mutate(across(everything(), as.character))
            test <- dplyr::bind_rows(test, timed_out)
            rm(timed_out)
            message(paste0("Failed to geocode unit ", as.character(v), " after ", as.character(max_tries), " attempts. -_-"))
            }       
        }
  
        # store the obs that are still unmatched
        still_unmatched <- test %>% dplyr::filter(is.na(.data$latitude) | is.na(.data$longitude))
        # store the obs that are fixed (now have a match)
        fixed <- test %>%
            dplyr::filter(., !.data$unit_id %in% still_unmatched$unit_id)

        # Append fixed to coord
        coord <- dplyr::bind_rows(coord, fixed)

        rm(fixed) 
    }
    
    # Turn coord (matched) coordinates into a point geometry
    if (is.null(coord) || nrow(coord) == 0) {
        stop("No units were successfully geocoded. Please check your inputs and internet connection,  and expected output from geocoder, then try again.")
    }

    # Convert to sf object
    n_before <- nrow(coord)
    coord <- coord %>% dplyr::mutate(longitude = as.numeric(longitude), latitude = as.numeric(latitude)) # need to be numeric
    coerce_failed <- coord %>% dplyr::filter(is.na(.data$longitude) | is.na(.data$latitude))
    if (nrow(coerce_failed) > 0) { # if any geocoding output could not be coverted properly, add to still_unmatched for Recover()
        still_unmatched <- dplyr::bind_rows(still_unmatched, coerce_failed %>% dplyr::select(-longitude, -latitude))
        coord <- coord %>% dplyr::filter(!.data$unit_id %in% coerce_failed$unit_id)
    }
    # Check coercion broadly worked before building geometry (geocoder could return long/lat in an unexpected format if it updates without me knowing)
    if (nrow(coord) == 0 || nrow(coerce_failed) > (n_before * .95)) {
        stop("Very few, if any, units were successfully geocoded. Please check your inputs, internet connection, and expected output from geocoder, then try again.")
    }
    isolate_coords <- as.matrix(coord[, c("longitude", "latitude")])
    storage.mode(isolate_coords) <- "double"
    geo <- sf::st_sfc(sf::st_multipoint(isolate_coords), crs = sf::st_crs(4326)) %>% # This is the crs code for long/lat coordinates. See halfway down the page here: https://www.paulamoraga.com/book-spatial/the-sf-package-for-spatial-vector-data.html
        sf::st_cast("POINT")
    coord <- sf::st_sf(coord, geometry = geo)

    # free some space
    rm(sample2, failed, grp_assign, sample_list, unitgroups, num, unitnum, id_count, sample2_ids, isolate_coords, geo, coerce_failed)
    gc() # garbage collection
  
    ## Now filter out any points that are outside the state shape (these will be considered unmatched)
    # Clean up state geometry
    state_shape <- state_shape %>%
        sf::st_transform(., crs = sf::st_crs(coord)) %>% # sets the two objects to the same coordinate reference system.
        sf::st_make_valid()  

    # Units placed outside state shape will be considered unmatched
    in_state <- sf::st_filter(coord, state_shape) 
    not_instate <- coord %>% dplyr::filter(., !.data$unit_id %in% in_state$unit_id) %>%
        dplyr::mutate(., longitude = NA, latitude = NA) %>% 
        sf::st_drop_geometry() # We will consider these unmatched
    coord <- coord %>% 
        dplyr::filter(., .data$unit_id %in% in_state$unit_id)
    
    if(length(unique(not_instate$unit_id)) > 0) { 
        still_unmatched <- dplyr::bind_rows(still_unmatched, not_instate)
    } 

    # Retain only relevant columns
    if(!is.null(unit_zip) && "postalcode" %in% names(units)) { 
        coord <- coord[, c("unit_id", "strt", "cty", "ste", "postalcode", "geometry")]
        still_unmatched <- still_unmatched[, c("unit_id", "strt", "cty", "ste", "postalcode")]
    } else {
        coord <- coord[, c("unit_id", "strt", "cty", "ste", "geometry")]
        still_unmatched <- still_unmatched[, c("unit_id", "strt", "cty", "ste")]
    }

    # Recover user-defined column names
    colnames(coord)[colnames(coord) == "unit_id"] <- unit_id
    colnames(coord)[colnames(coord) == "strt"] <- street
    colnames(coord)[colnames(coord) == "cty"] <- city
    colnames(coord)[colnames(coord) == "ste"] <- state
    if(!is.null(unit_zip) && "postalcode" %in% names(units)) { 
        colnames(coord)[colnames(coord) == "postalcode"] <- unit_zip
        colnames(still_unmatched)[colnames(still_unmatched) == "postalcode"] <- unit_zip
    }
    colnames(still_unmatched)[colnames(still_unmatched) == "unit_id"] <- unit_id
    colnames(still_unmatched)[colnames(still_unmatched) == "strt"] <- street
    colnames(still_unmatched)[colnames(still_unmatched) == "cty"] <- city
    colnames(still_unmatched)[colnames(still_unmatched) == "ste"] <- state
    
    rm(units, in_state, not_instate, state_shape, mthd, yr) # free up more space
    gc() # garbage collection
    tictoc::toc(log = TRUE) # store full runtime for Query function

    # Return final list object
    return(list(matched = coord, unmatched = still_unmatched))

}