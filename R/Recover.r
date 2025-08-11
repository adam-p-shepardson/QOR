#' Recover Failed Point (e.g., Voter) to Polygon (e.g., School District) Matches using Zipcodes
#'
#' The recover() function performs the "Recover" (Step 3) operation from the QOR Method. 
#' This function assigns units (e.g., voters) to polygon geometries (e.g., school districts) using zipcodes as spatial cross-walks.
#' It requires that all units, polygons, and zipcodes each have a unique identifier column. If observations are not unique, 
#' then this function may not work as intended. E.g., if you have panel data, you should use ONE timepoint per functional call (all voters 
#' in one year, then all voters in the next year, etc.). Importantly, the function returns matches that assign ONE polygon to each unit, 
#' which is the polygon whose internal point is closest to the center of that unit's zipcode. The "Recover" operation is intended to be used 
#' for cases where the "Query" operation fails to convert an address to a point geometry. Modify the code if you want to return 
#' multiple polygons for each unit.
#'
#' @param units dataframe object containing voter information (needs to have unique ID and then a zipcode variable)
#' @param polygons sf object containing polygon geometries (e.g., school districts).
#' @param zipcodes sf object containing zipcode tabulation area geometries (ZCTAs)
#' @param unit_id name of the column in the units dataframe that contains the unique identifiers for each unit (default: "unit_id")
#' @param unit_zip name of the column in the units dataframe that contains the zipcodes (default: "postalcode")
#' @param polygon_id name of the column in the polygons sf object that contains the unique identifiers for each polygon (default: "polygon_id")
#' @param zip_id name of the column in the zipcodes sf object that contains the unique identifiers for each zipcode (default: "postalcode")
#' @param state_shape sf object containing the shape of the state (used to filter zipcodes to the state)
#' @param used_NCES boolean indicating whether the user inputed NCES school district shapefiles or other shapefiles with a state_FIPS code as the polygons (default: TRUE)
#' @param state_FIPS state FIPS code to filter NCES school district shapefiles (default: NULL, which means no filtering by state)
#' @return tibble dataset with five columns: unit_id, polygon_id, postalcode, distance, and a binary flag for matched_byzip, where each unit_id is matched to ONE polygon_id.
#' @export
recover <- function(units = NULL, polygons = NULL, zipcodes = NULL, unit_id = "unit_id", unit_zip = "postalcode", polygon_id = "polygon_id", zip_id = "postalcode", state_shape = NULL, used_NCES = TRUE, state_FIPS = NULL) {
  
  # Check that the inputs are valid
    if (is.null(units) || is.null(polygons) || is.null(zipcodes) || is.null(state_shape)) {
        stop("Units, polygons, zipcodes, and a state shapefile must all be provided.")
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
    } else if (!is.null(state_shape) && !inherits(state_shape, "sf")) {
        stop("State shape must be an sf object (convert to sf format using functions from sf package).")
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
        st_filter(., state_shape) # filters zipcodes to the state shape

        # Convert custom names to standard names
        colnames(units)[colnames(units) == unit_id] <- "unit_id" 
        colnames(units)[colnames(units) == unit_zip] <- "postalcode"
        colnames(polygons)[colnames(polygons) == polygon_id] <- "polygon_id"
        colnames(zipcodes)[colnames(zipcodes) == zip_id] <- "postalcode"

        # If NCES shapefiles, can filter polygons to the state FIPS code
        if (used_NCES == TRUE & is.null(state_FIPS)) {
        warning(paste("Raw NCES school district shapefiles are national and we can use a State FIPS code to filter them. We suggest providing a value for state_FIPS code (e.g., '37' for North Carolina)."))
        } else if (used_NCES == TRUE & !is.null(state_FIPS)) {
            temp <- polygons %>% dplyr::rename_with(tolower) 
            colnames(polygons)[startsWith(names(temp), "state")] <- "state_fips"
            polygons <- polygons %>%
            dplyr::mutate(state_fips = as.character(.data$state_fips)) %>%
            dplyr::filter(., state_fips == as.character(state_FIPS)) # filters polygons to the state FIPS code
            rm(temp)
        }  
    }
  
  tictoc::tic.clearlog() # clear time log as safety check
  tictoc::tic("Recover Full Time") # Start timer for the entire recover process
  



}