#' Recover Failed Point-to-Polygon Matches Using Zipcodes
#'
#' The `recover()` function performs the "Recover" (Step 3) operation from the QOR Method.
#'
#' This function:
#' - Assigns units (e.g., voters) to polygon geometries (e.g., school districts) using zipcodes as a spatial crosswalk.
#' - Requires that all units, polygons, and zipcodes each have a unique identifier column.
#' - If observations are not unique (e.g., panel data), use only one timepoint per function call (e.g., all voters in one year, then all voters from the next year, etc.).
#' - Returns a match that assigns **one** polygon to each unit: the polygon whose internal point is closest to the centroid of that unit's zipcode.
#' - Intended for cases where the "Query" operation fails to convert an address to a point geometry.
#' - To return multiple polygons per unit, you will need to modify the code.
#'
#' @param units Dataframe or tibble containing unit information (must have unique unit_id and a zipcode variable).
#' @param polygons sf object containing polygon geometries (e.g., school districts).
#' @param zipcodes sf object containing zipcode tabulation area geometries (ZCTAs).
#' @param unit_id Name of the column in the units dataframe that contains unique identifiers for each unit (default: "unit_id").
#' @param unit_zip Name of the column in the units dataframe that contains the zipcodes (default: "postalcode").
#' @param polygon_id Name of the column in the polygons sf object that contains unique identifiers for each polygon (default: "polygon_id").
#' @param zip_id Name of the column in the zipcodes sf object that contains unique identifiers for each zipcode (default: "postalcode").
#' @param state_shape sf object containing the shape of the state (used to filter zipcodes to the state).
#' @param used_NCES Boolean indicating whether the user input NCES school district shapefiles or other shapefiles with a state_FIPS code as the polygons (default: TRUE).
#' @param state_FIPS State FIPS code to filter NCES school district shapefiles (default: NULL, which means no filtering by state).
#'
#' @return A tibble with five columns: unit_id, polygon_id, postalcode, distance, and a binary flag for matched_byzip, where each unit_id is matched to one polygon_id.
#'
#' @importFrom dplyr filter mutate tibble rename_with slice_min
#' @importFrom magrittr %>%
#' @importFrom tidyr pivot_longer
#' @importFrom tictoc tic.clearlog tic toc
#' @importFrom sf st_make_valid st_transform st_point_on_surface st_crs st_filter st_centroid st_distance
#' @importFrom tibble rownames_to_column
#' @importFrom stringr str_split_i
#' @export
recover <- function(units = NULL, polygons = NULL, zipcodes = NULL, unit_id = "unit_id", unit_zip = "postalcode", 
    polygon_id = "polygon_id", zip_id = "postalcode", state_shape = NULL, used_NCES = TRUE, state_FIPS = NULL) {
  
    tictoc::tic.clearlog() # clear time log as safety check
    tictoc::tic("Runtime: Recover Full Time") # Start timer for the entire recover process

    # Check that the inputs are valid
    if (is.null(units) || is.null(polygons) || is.null(zipcodes) || is.null(state_shape)) {
        stop("The units dataset, polygons shapefile, zipcodes shapefile, and a state shapefile must all be provided.")
    } else if (!is.data.frame(units)) {
        stop("Units must be a data.frame or tibble object.")
    } else if (!inherits(polygons, "sf") || !inherits(zipcodes, "sf")) {
        stop("Polygons and zipcodes must be sf objects (convert to sf format using functions from sf package).")
    } else if (!unit_id %in% names(units) || !unit_zip %in% names(units)) {
        stop(paste("The unit_id ('", unit_id, "') or unit_zip ('", unit_zip, "') is not found in the units dataset.", sep = ""))
    } else if (!polygon_id %in% names(polygons)) {
        stop(paste("The polygon_id ('", polygon_id, "') is not found in the polygons dataset.", sep = ""))
    } else if (!zip_id %in% names(zipcodes)) {
        stop(paste("The zip_id ('", zip_id, "') is not found in the zipcodes dataset.", sep = ""))
    } else if (!inherits(state_shape, "sf")) {
        stop("State shape must be an sf object (convert to sf format using functions from sf package).")
    } else if (length((unique(units[[unit_id]]))) != length(units[[unit_id]])) {
        stop(paste("The unit_id ('", unit_id, "') does not uniquely identify each row in the units dataset.", sep = ""))
    } else { # Can proceed after equalizing crs
        # Clean up geometries
        polygons <- polygons %>%
        sf::st_make_valid() %>%
        sf::st_transform(., crs = sf::st_crs(zipcodes))  # sets the objects to the same coordinate reference system.
        state_shape <- state_shape %>%
        sf::st_make_valid() %>% 
        sf::st_transform(., crs = sf::st_crs(zipcodes))
        zipcodes <- zipcodes %>%
        sf::st_make_valid() %>%
        sf::st_filter(., state_shape) # filters zipcodes to the state shape

        # Convert custom names to standard names
        colnames(units)[colnames(units) == unit_id] <- "unit_id" 
        colnames(units)[colnames(units) == unit_zip] <- "postalcode"
        colnames(polygons)[colnames(polygons) == polygon_id] <- "polygon_id"
        colnames(zipcodes)[colnames(zipcodes) == zip_id] <- "postalcode"

        # Make postalcode column character if not already
        units$postalcode <- as.character(units$postalcode)

        # If NCES shapefiles, can filter polygons to the state FIPS code
        if (used_NCES == TRUE & is.null(state_FIPS)) {
        warning(paste(
          "Raw NCES school district shapefiles are national and we can use a State FIPS code to filter them (massively reduce compute time).\nWe strongly suggest providing a value for state_FIPS code (e.g., '37' for North Carolina)."
        ))
        } else if (used_NCES == TRUE & !is.null(state_FIPS)) {
            temp <- polygons %>% dplyr::rename_with(tolower) 
            colnames(polygons)[startsWith(names(temp), "state")] <- "state_fips"
            polygons <- polygons %>%
            dplyr::mutate(state_fips = as.character(.data$state_fips)) %>%
            dplyr::filter(., state_fips == as.character(state_FIPS)) # filters polygons to the state FIPS code
            rm(temp)
        }  
    }
  
  # Find zip centroids
  statezips_center <- sf::st_centroid(zipcodes)

  # Find internal points of polygons
  statedistricts_internal <- sf::st_point_on_surface(polygons)
  
  # Find the distances between every zip centroid and every district internal point
  tictoc::tic("Runtime: School District Distances to Zips")
  statedistances <- sf::st_distance(statezips_center, statedistricts_internal)
  
  # Create dataset of distances between centroids and internal points
  colnames(statedistances) <- statedistricts_internal$polygon_id
  rownames(statedistances) <- statezips_center$postalcode
  statedistances <- as.data.frame(statedistances)
  
  # Tidy the distances dataset
  statedistances <- tibble::rownames_to_column(statedistances, "postalcode") %>%
    tidyr::pivot_longer(cols = !postalcode, names_to = "polygon_id", values_to = "distance") 
  statedistances$distance <- as.numeric(statedistances$distance) # remove units so that minimum calculation works. Note: all values still in m (meters)
  
  tictoc::toc(log = TRUE) # store distances time
  
  # Store all units to be recovered
  all_ids <- unique(units$unit_id)
  
  # Instantiate dataset for storing final matches
  unmatchedset <- dplyr::tibble(unit_id = all_ids, postalcode = NA, polygon_id = NA, distance = NA, matched_byzip = 1)
  
  tictoc::tic("Runtime: Recovery Loop")
  id_count <- 0
  missing_count <- 0
  
  ## Assign the recovered units to the closest polygon to zip centroid (based on internal point)
  for(uid in all_ids) {
    id_count <- id_count + 1
    message(paste0("Now attempting to assign a polygon (based on zipcode) to unit ", as.character(id_count), " out of the ", as.character(length(all_ids)), " units who could not be geocoded"))
    
    # Get the unit's postalcode
    temp <- units %>% 
      filter(., unit_id == uid)
    my_zip <- temp$postalcode[1]
    if(nchar(my_zip) > 5) {
      # If zipcode is hyphenated, just use first 5 digits
      my_zip <- stringr::str_split_i(my_zip, pattern = "-", i = 1)
    }
    # Filter statedistances dataset to just that zip; extract closest polygon_id
    data <- statedistances %>% dplyr::filter(., postalcode == my_zip) %>% dplyr::slice_min(distance, n = 1)
    # Follow-through on binding to unmatchedset only if zipcode was actually in statedistances (i.e., in the state based on Census ZCTAs)
    if(length(unique(data$postalcode)) == 1) {
      # Extract information to correct row in unmatchedset
      unmatchedset$polygon_id[unmatchedset$unit_id == uid] <- data$polygon_id
      unmatchedset$distance[unmatchedset$unit_id == uid] <- data$distance
      unmatchedset$postalcode[unmatchedset$unit_id == uid] <- data$postalcode
    } else if(length(unique(data$postalcode)) != 1) {
      unmatchedset <- unmatchedset %>% dplyr::filter(., unit_id != uid) # Remove from unmatchedset if no match possible (zip not in census shapefile for the state)
      missing_count <- missing_count + 1
    }
  }
  
  rm(statedistances, temp, data, all_ids, my_zip, id_count, uid) # free up RAM immediately
  gc() # garbage collection
  tictoc::toc(log = TRUE) # store recovery loop time

  ## Return the unmatchedset with unit_id, polygon_id, distance, flag for matched_byzip, and postalcode
  # Recover user's original unit_id and polygon_id names
  colnames(unmatchedset)[colnames(unmatchedset) == "unit_id"] <- unit_id
  colnames(unmatchedset)[colnames(unmatchedset) == "polygon_id"] <- polygon_id
  # label distance column and flag for matched_byzip
  attr(unmatchedset$distance, "label") <- "Distance (m), zipcode centroid to polygon internal point"
  attr(unmatchedset$matched_byzip, "label") <- "unit_id matched to polygon_id by zipcode (1 = yes)"
  
  # Return the unmatchedset
  tictoc::toc(log = TRUE) # print full time
  message(paste0("Note: Could not recover a match for ", as.character(missing_count), " units because their zipcodes were not found in state's Census zipcodes."))
  return(unmatchedset)

}