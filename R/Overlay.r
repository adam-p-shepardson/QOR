#' Match Point Geometries to Polygon Geometries (e.g., Voter Locations to School Districts)
#'
#' The `overlay()` function performs the "Overlay" (Step 2) operation from the QOR Method.
#'
#' This function:
#' - Matches point geometries (e.g., voter locations) to polygon geometries (e.g., school districts) using spatial intersections and distances.
#' - Requires that all points and polygons each have a unique identifier column.
#' - If observations are not unique (e.g., panel data), use only one timepoint per function call (e.g., all voters in one year, then all voters in the next year, etc.).
#' - Returns a match that assigns **one** polygon to each point: the polygon the point is in, or the closest polygon (based on internal point) if the point is not in any polygon.
#' - To return multiple polygons per point, you will need to modify the code.
#'
#' @param points sf object containing point geometries for units (e.g., voter locations).
#' @param polygons sf object containing polygon geometries (e.g., school districts).
#' @param point_id Name of the column in the points sf object that contains unique identifiers for each point (default: "point_id").
#' @param polygon_id Name of the column in the polygons sf object that contains unique identifiers for each polygon (default: "polygon_id").
#' @param used_NCES Boolean indicating whether the user input NCES school district shapefiles or other shapefiles with a state_FIPS code as the polygons (default: TRUE).
#' @param state_FIPS State FIPS code to filter NCES school district shapefiles (default: NULL, which means no filtering by state).
#'
#' @return A tibble with three columns: point_id, polygon_id, and distance (to internal point), where each point_id is matched to one polygon_id.
#'
#' @importFrom dplyr filter mutate tibble rename_with slice_min
#' @importFrom tidyr pivot_longer
#' @importFrom tictoc tic.clearlog tic toc
#' @importFrom sf st_make_valid st_transform st_point_on_surface st_crs st_intersects st_distance
#' @importFrom tibble rownames_to_column
#' @export
overlay <- function(points = NULL, polygons = NULL, point_id = "point_id", polygon_id = "polygon_id", used_NCES = TRUE, 
  state_FIPS = NULL) {
  
  tictoc::tic.clearlog() # clear time log in case you have a prior run
  tictoc::tic("Runtime: Overlay Full Time") # Start full timer for function

  # Check that the inputs are valid
  if (is.null(points) || is.null(polygons)) {
    stop("Both points and polygons must be provided.")
  } else if (!inherits(points, "sf") || !inherits(polygons, "sf")) {
    stop("Both points and polygons must be sf objects (convert to sf format using functions from sf package).")
  } else if (!point_id %in% names(points) || !polygon_id %in% names(polygons)) {
    stop(paste("The point_id ('", point_id, "') or polygon_id ('", polygon_id, "') is not found in the respective datasets.", sep = ""))
  } else if (length((unique(points[[point_id]]))) != length(points[[point_id]])) {
    stop(paste("The point_id ('", point_id, "') does not uniquely identify each row in the points dataset.", sep = ""))
  } else { # Can proceed after equalizing crs
    # Clean up geometries
    points <- points %>%
      sf::st_make_valid()
    polygons <- polygons %>%
        sf::st_make_valid() %>%
        sf::st_transform(., crs = sf::st_crs(points)) # sets the two objects to the same coordinate reference system.
    polygons_internal <- sf::st_point_on_surface(polygons) # creates a point on the internal surface of each polygon, which is used to calculate distances to ids

    # Convert custom names to standard names
    colnames(points)[colnames(points) == point_id] <- "point_id" 
    colnames(polygons)[colnames(polygons) == polygon_id] <- "polygon_id"

    # If NCES shapefiles, can filter polygons to the state FIPS code
    if (used_NCES == TRUE & is.null(state_FIPS)) {
      warning(paste(
          "Raw NCES school district shapefiles are national and we can use a State FIPS code to filter them (massively reduce compute time).\nWe strongly suggest providing a value for state_FIPS (e.g., '37' for North Carolina)."
        ))
    } else if (used_NCES == TRUE & !is.null(state_FIPS)) {
      temp <- polygons %>% dplyr::rename_with(tolower) 
      colnames(polygons)[startsWith(names(temp), "state")] <- "state_fips"
      polygons <- polygons %>%
      dplyr::mutate(state_fips = as.character(.data$state_fips)) %>%
      dplyr::filter(., .data$state_fips == as.character(state_FIPS)) # filters polygons to the state FIPS code
      rm(temp)
    }
  }
  
  tictoc::tic("Runtime: Point-Polygon Distance Calculation") # Start time for distance calculations
  
  ## For every id, filter down to the polygon that they are in. If they truly straddle the line between two, use the closest one (based on internal point)
  
  # I only need the distances for ids who are in no or multiple polygons
  # Inspired by: https://gis.stackexchange.com/questions/394954/r-using-st-intersects-to-classify-points-inside-outside-and-within-a-buffer
  in_onedistrict <- lengths(sf::st_intersects(points, polygons)) == 1 # point intersects one polygon
  in_nodistricts <- lengths(sf::st_intersects(points, polygons)) == 0 # point intersects no polygons
  in_multipledistricts <- lengths(sf::st_intersects(points, polygons)) > 1 # point intersects several polygons
  in_onedistrict <- points$point_id[in_onedistrict]
  in_nodistricts <- points$point_id[in_nodistricts]
  in_multipledistricts <- points$point_id[in_multipledistricts]
  
  calculate_these <- points %>%
    dplyr::filter(., !.data$point_id %in% in_onedistrict)
  
  distances <- sf::st_distance(calculate_these, polygons_internal)
  
  colnames(distances) <- polygons_internal$polygon_id
  rownames(distances) <- calculate_these$point_id
  
  rm(calculate_these)
  
  distances <- as.data.frame(distances) #  now have a non-tidy dataframe where columns are polygon_ids, rownames are point_ids, and cells are the distances between the two
  
  # Change statedistances to tidy format
  distances <- rownames_to_column(distances, "point_id") 
  distances <- distances %>% 
    tidyr::pivot_longer(cols = !.data$point_id, names_to = "polygon_id", values_to = "distance") 
  distances$distance <- as.numeric(distances$distance) # remove units so that minimum calculation works. Note: all values still in m (meters) by default

  # Print the point_ids for any points in multiple or no polygons
  message(paste0("These point_ids were in multiple polygons:", as.character(in_multipledistricts)))
  message(paste0("These point_ids were in no polygons:", as.character(in_nodistricts)))
  
  tictoc::toc(log = TRUE) # print Point-Polygon Distance calculation time
  
  ## For each point_id, extract the polygon that they are in, or the closest one otherwise
  # Store all intersections for use in loop
  intersections <- sf::st_intersects(points, polygons) 
  
  # Instantiate dataset for storing final matches (already length of all point_ids)
  districtset <- dplyr::tibble(point_id = unique(points$point_id), polygon_id = NA, distance = NA)
  
  tictoc::tic("Runtime: Point-Polygon Matching Loop")
  id_count <- 0
  
  # For loops
    for(vid in in_onedistrict) { # Vast majority of, if not all, cases: Check if in one polygon. Extract that pid.
      # Ticker
      id_count <- id_count + 1
      message(paste0("Now assigning a polygon to point_id # ", as.character(id_count), " out of the ", as.character(length(in_onedistrict)), " point_id's in only one polygon"))
      
      # Find row # in points for point_id, then feed this row # into intersections to get row # of overlapping polygon in polygons, then feed this row # into polygons$pid to get pid, then store in districtset.
      districtset$polygon_id[districtset$point_id == vid] <- polygons$polygon_id[intersections[[which(points$point_id == vid)]]]
    } 
    for(vid in in_multipledistricts) { # If in several districts, only extract closest *of these*
      # Filter statedistances dataset to just a single point_id, and then only the rows containing the polygon_ids point_id is in; extract closest polygon_id
      data <- distances %>% dplyr::filter(., .data$point_id == vid & .data$polygon_id %in% polygons$polygon_id[intersections[[which(points$point_id == vid)]]]) %>% dplyr::slice_min(distance, n = 1)
      # Store in districtset
      districtset$polygon_id[districtset$point_id == vid] <- data$polygon_id
      districtset$distance[districtset$point_id == vid] <- data$distance
    } 
    for(vid in in_nodistricts) { # If in no districts, extract closest one
      # Filter statedistances dataset to just a single point_id, extract the row with the closest district (based on internal point)
      data <- distances %>% dplyr::filter(., .data$point_id == vid) %>% dplyr::slice_min(distance, n = 1)
      # Store in districtset
      districtset$polygon_id[districtset$point_id == vid] <- data$polygon_id
      districtset$distance[districtset$point_id == vid] <- data$distance
    }
  
  if(exists("data")) {
    rm(data) 
  }
  rm(distances, intersections, id_count) # free up RAM
  
  gc() # garbage collection
  
  tictoc::toc(log = TRUE) # print loop time

  ## Return the districtset with point_id, polygon_id, and distance
  # Recover user's original point_id and polygon_id names
  colnames(districtset)[colnames(districtset) == "point_id"] <- point_id
  colnames(districtset)[colnames(districtset) == "polygon_id"] <- polygon_id
  # label distance column
  attr(districtset$distance, "label") <- "Distance (m), point_id to polygon internal point (only exists if point_id not in just one polygon)"
  
  # Return the districtset
  tictoc::toc(log = TRUE) # print full time
  return(districtset)

}
