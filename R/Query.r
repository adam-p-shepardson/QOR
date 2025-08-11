#' Geocode Unit (Voter) Addresses to Long/Lat Coordinates
#'
#' The query() function performs the "Query" (Step 1) operation from the QOR Method. 
#' This function assigns units (e.g., voters) longitude and latitude coordinates based on 
#' their street address, city, and state. It is, functionally, a wrapper around tidygeocoder::geocode()
#' that also executes other actions needed to process individual voter data and set up the next QOR Method steps.
#' Importantly, it does not perform any matching to polygons or zip codes; it simply geocodes the addresses.
#'
#' @param units dataframe object containing voter information (needs to have unique ID and then street, city, and state columns)
#' @param street name of the column in the units dataframe that contains the street address (default: "street")
#' @param city name of the column in the units dataframe that contains the city (default: "city")
#' @param state name of the column in the units dataframe that contains the state (default: "state")
#' @param state_shape sf object containing the shape of the state (used to filter geocoding results to the state, catching errors)
#' @param year of the data (default: NULL, which means no filtering by year)
#' @param units_per_batch number of units to geocode in each batch (conservative default: 4000). Internet connectivity and API limits determine possibility of larger (or smaller) batches.
#' @return list object with two items: 1. tibble of matched units with their geocoded coordinates, and 2. tibble of unmatched units (those that could not be geocoded).
#' @export
query <- function(units = NULL, street = "street", city = "city", state = "state", state_shape = NULL, units_per_batch = 4000, year = NULL) {

    # Check that the inputs are valid
    if (is.null(units) || is.null(street) || is.null(city) || is.null(state) || is.null(state_shape)) {
        stop("Units, street, city, and state, as well as a state shapefile must all be provided.")
    } else if (!is.data.frame(units)) {
        stop("Units must be a data.frame or tibble object.")
    } else if (!street %in% names(units) || !city %in% names(units) || !state %in% names(units)) {
        stop(paste("The street ('", street, "'), city ('", city, "'), or state ('", state, "') is not found in the units dataset.", sep = ""))
    } else if (!is.null(state_shape) && !inherits(state_shape, "sf")) {
        stop("State shape must be an sf object (convert to sf format using functions from sf package).")
    } else {
        
        # Convert custom names to standard names
        colnames(units)[colnames(units) == street] <- "street"
        colnames(units)[colnames(units) == city] <- "city"
        colnames(units)[colnames(units) == state] <- "state"
    }




    # Clean up geometries
    state_shape <- state_shape %>%
        sf::st_make_valid() %>%
        sf::st_transform(., crs = sf::st_crs(units_coord)) # sets the two objects to the same coordinate reference system.

    # Units placed outside state shape will be considered unmatched


    # Return final list object
    return(list(matched, unmatched))

}