#' Geocode Unit (Voter) Addresses to Longitude/Latitude Coordinates
#'
#' The `query()` function performs the "Query" (Step 1) operation from the QOR Method.
#'
#' This function:
#' - Assigns longitude and latitude coordinates to units (e.g., voters) based on their street address, city, and state.
#' - Acts as a wrapper around `tidygeocoder::geocode()`, while also handling additional processing needed for individual voter data and preparing for subsequent QOR Method steps.
#' - **Note:** This function does not perform any matching to polygons or zip codes; it simply geocodes the addresses.
#' - Allows you to choose any geocoding service available in the `tidygeocoder` package (we recommend using the "census" method for best results).
#'
#' @param units Dataframe or tibble containing voter information (must have unique unit_id, street, city, and state columns).
#' @param unit_id Name of the column in the units dataframe that contains the unique identifiers for each unit (default: "unit_id").
#' @param street Name of the column in the units dataframe that contains the street address (default: "street").
#' @param city Name of the column in the units dataframe that contains the city (default: "city").
#' @param state Name of the column in the units dataframe that contains the state (default: "state").
#' @param state_shape sf object containing the shape of the state (used to filter geocoding results to the state, catching errors).
#' @param year Year of the data (default: NULL, which throws an error). Program was designed for years 2007 through 2025. Years <= 2010 will use the 2010 Census database, and years > 2025 will use the current Census database.
#' @param units_per_batch Number of units to geocode in each batch (default: 4000). Internet connectivity and API limits determine possibility of larger (or smaller) batches. The Census theoretically allows batches of up to 10,000 addresses, but we have found that smaller batches are less likely to be rejected by the API.
#' @param method Geocoding method to use (default: "census"). See methods from tidygeocoder::geocode(). We recommend "census" for best cost (free) and batch geocoding. You may need to adjust parts of code that set variable names if using different method, and not all methods may support the batch coding that we use by default.
#' @param sleep_time Time to pause between batches (default: 2 seconds). Try increasing if you are getting rate-limited by the geocoding service or encountering connection issues.
#' @param zip_id RECOMMENDED BUT OPTIONAL name of the column in the units dataframe that contains the postal code (default: "postalcode"). Output will have a postalcode column if provided, but this column will be NA if not provided. "Recover" will NOT be able to match any unmatched units if postalcode not provided here.
#'
#' @return A list with two items: (1) Tibble of matched units with their geocoded coordinates, and (2) Tibble of unmatched units (those that could not be geocoded).
#'
#' @importFrom dplyr mutate filter bind_rows tibble
#' @importFrom magrittr %>%
#' @importFrom tictoc tic.clearlog tic toc
#' @importFrom tidygeocoder geocode
#' @importFrom sf st_as_sf st_crs st_transform st_make_valid st_filter read_sf
#' @export
query <- function(units = NULL, unit_id = "unit_id", street = "street", city = "city", state = "state", state_shape = NULL, 
units_per_batch = 4000, year = NULL, method = "census", sleep_time = 2, zip_id = "postalcode") {

    tictoc::tic.clearlog() # clear time log as safety check
    tictoc::tic("Runtime: Query Full Time") # Start timer for the entire recover process

    # Check that the inputs are valid
    if (is.null(units) || is.null(street) || is.null(city) || is.null(state) || is.null(state_shape) || is.null(unit_id)) {
        stop("The units dataset with column names for street, city, state, and unique unit_id, as well as a state shapefile, must all be provided.")
    } else if (!is.data.frame(units)) {
        stop("Units must be a data.frame or tibble object.")
    } else if (!unit_id %in% names(units) || length((unique(units[[unit_id]]))) != length(units[[unit_id]])) { 
        stop(paste("The unit_id ('", unit_id, "') is either not found in the units dataset or does not uniquely identify each row.", sep = ""))
    } else if (!street %in% names(units) || !city %in% names(units) || !state %in% names(units)) {
        stop(paste("The street ('", street, "'), city ('", city, "'), or state ('", state, "') is not found in the units dataset.", sep = ""))
    } else if (!inherits(state_shape, "sf")) {
        stop("State shape must be an sf object (convert to sf format using functions from sf package).")
    } else if (is.null(year)) {
        stop(paste("No year value provided. Need a year between 2007 and 2023 to select the closest geocoding database to use."))
    } else {
        # Convert custom names to standard names
        colnames(units)[colnames(units) == unit_id] <- "unit_id" 
        colnames(units)[colnames(units) == street] <- "str"
        colnames(units)[colnames(units) == city] <- "cty"
        colnames(units)[colnames(units) == state] <- "ste"
        
        if(!is.null(zip_id) && zip_id %in% names(units)) { 
            colnames(units)[colnames(units) == zip_id] <- "postalcode"
        } else {
            units$postalcode <- NA # create a column for postalcode if not provided
        }

        # turn year into numeric
        yr <- as.numeric(year)

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
    split <- rep(1:unitgroups, ceiling(nrow(units) / unitgroups)) # repeat 1 through # unitgroups the desired # of times
    split <- split[1:nrow(units)] # Since I round the group number, need to chop off some of the extra integers to match length of units
    units <- units %>%
        dplyr::mutate(., s_2_1_1_1_1 = split) # Each obs. is now flagged to be put into a sample group
  
    # create sample groups, store in list
    sample_list <- list()
    for(num in 1:unitgroups) {
        sample <- units %>% dplyr::filter(., .data$s_2_1_1_1_1 == num)
        sample_list[[num]] <- sample
        rm(sample)
    }

    # Set A Nearby Census Vintage (Note: these were the Census geocoder's valid vintage names through 2023 as of August, 2025)
    if(yr <= 2010) {
        vin <- "Census2010_Current"
    } else if(yr == 2011 | yr == 2012 | yr == 2013 | yr == 2014 | yr == 2015 | yr == 2016 | yr == 2017) {
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
    for(num in 1:unitgroups) {
    
        # Print out ticker of where we are
        message(paste0("Now batch-geocoding unit group ", as.character(num), " out of ", as.character(unitgroups)))
    
        if(num == 1) {
            # I decided not to input postalcodes into the Census geocoder, as I know these change over time. The matched_address should ultimately give me the current postalcode based on the vintage (I think)
            coord <- sample_list[[num]] %>%
                tidygeocoder::geocode(street = str, city = cty, state = ste, method = mthd, lat = latitude, long = longitude,
                    full_results = TRUE, verbose = TRUE, mode = "batch", custom_query = list(vintage = vin),
                    timeout = 50)
            Sys.sleep(2)
        } else {
            temp <- sample_list[[num]] %>%
                tidygeocoder::geocode(street = str, city = cty, state = ste, method = mthd, lat = latitude, long = longitude,
                    full_results = TRUE, verbose = TRUE, mode = "batch", custom_query = list(vintage = vin),
                    timeout = 50)
            coord <- dplyr::bind_rows(coord, temp)
            Sys.sleep(2)
            rm(temp)
        }
    } 
  
    ## For any that fail to match, set them aside for now. These will be "Recovered" in the Recover() function.
    failed <- coord %>%
        dplyr::filter(., is.na(coord$latitude) | is.na(coord$longitude))
    sample2 <- units %>%
        dplyr::filter(., .data$unit_id %in% failed$unit_id)
    # Filter out unmatched from coord
    coord <- coord %>% dplyr::filter(., !.data$unit_id %in% failed$unit_id)
  
    ### Solve as many ties and no_matches as possible by single coding (should return just one address if possible to locate any matches; takes a long time)
    ## The package creator says that this is the way to solve ties: https://jessecambon.github.io/tidygeocoder/articles/geocoder_services.html
    ## Create the dataset where I want to store the single geocoding results
    test <- dplyr::tibble()
  
    ## Filter sample2 down to one unit at a time, "trying" the single coding to fish for connection errors and restart if any
    sample2_ids <- sample2$unit_id
    id_count <- 0
  
    for(v in sample2_ids) {
    
        # Print out ticker of where we are
        id_count <- id_count + 1
        message(paste0("Now single-geocoding unit ", as.character(id_count), " out of the ", as.character(length(sample2_ids)), " who failed batch geocoding"))
    
        single_unit <- sample2 %>% dplyr::filter(., .data$unit_id == v) # filter to one unit
        success <- FALSE 
    
        # Detect error and keep trying if there is one (see as a baseline: https://cnuge.github.io/post/trycatch/ and https://stackoverflow.com/questions/68924178/how-to-redo-trycatch-after-error-in-for-loop and https://adv-r.hadley.nz/conditions.html)
        while(!success) {
            # infinite tryCatch loop until there is a success. This should exit to my custom error function "wait" the moment the first block returns an error
            tryCatch(
                {
                temp <- geocode(single_unit, street = str, city = cty, state = ste, method = mthd, lat = latitude, 
                          long = longitude, verbose = TRUE, full_results = TRUE, mode = "single", limit = 1, 
                          custom_query = list(vintage = vin), timeout = 50, min_time = 1)
          
                success <- TRUE # flag successful communication with Census website
          
                # Now I can append temp to test
                test <- dplyr::bind_rows(test, temp)
          
                message("No fatal error ^_^")
          
            }, error = function(wait) {
                Sys.sleep(5) # pause five seconds if there is an error
          
                message("Retrying, I hit an error -_-")
          
                }
            )
        }
    }
  
    # store the obs that are still unmatched
    still_unmatched <- test %>% dplyr::filter(is.na(test$latitude) | is.na(test$longitude))
    # store the obs that are fixed (now have a match)
    fixed <- test %>%
        dplyr::filter(., !.data$unit_id %in% still_unmatched$unit_id)

    # Append fixed to coord
    coord <- dplyr::bind_rows(coord, fixed)
  
    # Turn coord (matched) coordinates into a point geometry
    if (is.null(coord) || nrow(coord) == 0) {
        stop("No units were successfully geocoded. Please check your inputs and internet connection, then try again.")
    }
    coord <- sf::st_as_sf(coord, coords = c("longitude", "latitude"))
    sf::st_crs(coord) <- 4326 # This is the code for long/lat coordinates. See halfway down the page here: https://www.paulamoraga.com/book-spatial/the-sf-package-for-spatial-vector-data.html
  
    # free some space
    rm(test, sample2, failed, split, sample_list, fixed, unitgroups, num, unitnum, temp, id_count, v, sample2_ids)
    gc() # garbage collection
  
    ## Now filter out any points that are outside the state shape (these will be considered unmatched)
    # Clean up state geometry
    state_shape <- state_shape %>%
        sf::st_make_valid() %>%
        sf::st_transform(., crs = sf::st_crs(coord)) # sets the two objects to the same coordinate reference system.

    # Units placed outside state shape will be considered unmatched
    in_state <- sf::st_filter(coord, state_shape) 
    not_instate <- coord %>% dplyr::filter(., !.data$unit_id %in% in_state$unit_id) %>%
        dplyr::mutate(., longitude = NA, latitude = NA) # We will consider these unmatched
    coord <- coord %>% 
        dplyr::filter(., .data$unit_id %in% in_state$unit_id)
    
    if(length(unique(not_instate$unit_id)) > 0) { 
        still_unmatched <- dplyr::bind_rows(still_unmatched, not_instate)
    } else { # Do not need to append if nothing in "not_instate"
        still_unmatched <- still_unmatched
    }

    # Retain only relevant columns
    if(!is.null(zip_id) && zip_id %in% names(units)) { 
        coord <- coord[, c("unit_id", "str", "cty", "ste", "postalcode", "geometry")]
        still_unmatched <- still_unmatched[, c("unit_id", "str", "cty", "ste", "postalcode")]
    } else {
        coord <- coord[, c("unit_id", "str", "cty", "ste", "geometry")]
        still_unmatched <- still_unmatched[, c("unit_id", "str", "cty", "ste")]
    }

    # Recover user-defined column names
    colnames(coord)[colnames(coord) == "unit_id"] <- unit_id
    colnames(coord)[colnames(coord) == "str"] <- street
    colnames(coord)[colnames(coord) == "cty"] <- city
    colnames(coord)[colnames(coord) == "ste"] <- state
    if(!is.null(zip_id) && zip_id %in% names(units)) { 
        colnames(coord)[colnames(coord) == "postalcode"] <- zip_id
        colnames(still_unmatched)[colnames(still_unmatched) == "postalcode"] <- zip_id
    }
    colnames(still_unmatched)[colnames(still_unmatched) == "unit_id"] <- unit_id
    colnames(still_unmatched)[colnames(still_unmatched) == "str"] <- street
    colnames(still_unmatched)[colnames(still_unmatched) == "cty"] <- city
    colnames(still_unmatched)[colnames(still_unmatched) == "ste"] <- state
    
    rm(units, in_state, not_instate, state_shape, mthd, yr) # free up more space
    gc() # garbage collection
    tictoc::toc(log = TRUE) # store full runtime for Query function

    # Return final list object
    return(list(matched = coord, unmatched = still_unmatched))

}