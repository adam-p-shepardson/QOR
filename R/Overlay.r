#' Match Point Geometries (e.g., Voter Locations) to Polygon Geometries (e.g., School Districts)
#'
#' The overlay() function performs the "Overlay" (Step 2) operation from the QOR Method. 
#' This function matches point geometries (e.g., voter locations) to polygon geometries (e.g., school districts) using spatial 
#' intersections and distances. It requires that all points and polygons each have a unique identifier column. If observations 
#' are not unique, then the function may not work as intended. E.g., if you have panel data, you should use ONE timepoint per 
#' functional call (e.g., all voters in one year, then all voters in the next year, etc.). Importantly, the function returns 
#' matches that assign ONE polygon to each point, which is the polygon that the point is in, or the closest polygon (based on 
#' internal point) if the point is not in any polygon. Modify the code if you want to return multiple polygons per point.
#'
#' @param points sf object containing point geometries (e.g., voter locations)
#' @param polygons sf object containing polygon geometries (e.g., school districts)
#' @param point_id name of the column in the points sf object that contains the unique identifiers for each point (default: "point_id")
#' @param polygon_id name of the column in the polygons sf object that contains the unique identifiers for each polygon (default: "polygon_id")
#' @return tibble dataset with three columns: point_id, polygon_id, and distance (to internal point), where each point_id is matched to ONE polygon_id.
#' @export
overlay <- function(points = NULL, polygons = NULL, point_id = "point_id", polygon_id = "polygon_id") {
  
  # Check that the inputs are valid
  if (is.null(points) || is.null(polygons)) {
    stop("Both points and polygons must be provided.")
  } else if (!inherits(points, "sf") || !inherits(polygons, "sf")) {
    stop("Both points and polygons must be sf objects (convert to sf format using functions from sf package).")
  } else if (!point_id %in% names(points) || !polygon_id %in% names(polygons)) {
    stop(paste("The point_id ('", point_id, "') or polygon_id ('", polygon_id, "') is not found in the respective datasets.", sep = ""))
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
  }
  
  tictoc::tic.clearlog() # clear time log in case you have a prior run
  tictoc::tic("Overlay Full Time") # Start timer for the entire geomatch process
  tictoc::tic("Point-Polygon Distance Calculation") # Start time for distance calculations
  
  ## For every id, filter down to the polygon that they are in. If they truly straddle the line between two, use the closest one (based on internal point)
  
  # I only need the distances for ids who are in no or multiple polygons
  # Inspired by: https://gis.stackexchange.com/questions/394954/r-using-st-intersects-to-classify-points-inside-outside-and-within-a-buffer
  in_onedistrict <- lengths(sf::st_intersects(points, polygons)) == 1 # point intersects one polygon
  in_nopoly <- lengths(sf::st_intersects(points, polygons)) == 0 # point intersects no polygons
  in_multipledistricts <- lengths(sf::st_intersects(points, polygons)) > 1 # point intersects several polygons
  in_onedistrict <- points$point_id[in_onedistrict]
  in_nodistricts <- points$point_id[in_nodistricts]
  in_multipledistricts <- points$point_id[in_multipledistricts]
  
  calculate_these <- points %>%
    dplyr::filter(., !point_id %in% in_onedistrict)
  
  distances <- sf::st_distance(calculate_these, polygons_internal)
  
  colnames(distances) <- polygons_internal$pid
  rownames(distances) <- calculate_these$point_id
  
  rm(calculate_these)
  
  distances <- as.data.frame(distances) #  now have a non-tidy dataframe where columns are polygon_ids, rownames are point_ids, and cells are the distances between the two
  
  # Change statedistances to tidy format
  distances <- rownames_to_column(distances, "point_id") 
  distances <- distances %>% 
    tidyr::pivot_longer(cols = !point_id, names_to = "polygon_id", values_to = "distance") 
  distances$distance <- as.numeric(distances$distance) # remove units so that minimum calculation works. Note: all values still in m (meters) by default

  # Print the point_ids for any points in multiple or no polygons
  message("These point_ids were in multiple polygons:", in_multipledistricts)
  message("These point_ids were in no polygons:", in_nodistricts)
  
  tictoc::toc(log = TRUE) # print Point-Polygon Distance calculation time
  
  ## For each point_id, extract the polygon that they are in, or the closest one otherwise
  # Store all intersections for use in loop
  intersections <- sf::st_intersects(coord, polygons) 
  
  # Instantiate dataset for storing final matches (already length of all_ids)
  districtset <- dplyr::tibble(point_id = unique(points$point_id), polygon_id = NA, distance = NA)
  
  tictoc::tic("Point-Polygon Matching Loop")
  id_count <- 0
  
  # For loops
    for(vid in in_onedistrict) { # Vast majority of, if not all, cases: Check if in one polygon. Extract that pid.
      # Ticker
      id_count <- id_count + 1
      print(paste0("Now assigning a polygon to point_id # ", as.character(id_count), " out of the ", as.character(length(in_onedistrict)), " point_id's in only one polygon"))
      
      # Find row # in points for point_id, then feed this row # into intersections to get row # of overlapping polygon in polygons, then feed this row # into polygons$pid to get pid, then store in districtset.
      districtset$polygon_id[districtset$point_id == vid] <- polygons$polygon_id[intersections[[which(points$point_id == vid)]]]
    } 
    for(vid in in_multipledistricts) { # If in several districts, only extract closest *of these*
      # Filter statedistances dataset to just a single point_id, and then only the rows containing the polygon_ids point_id is in; extract closest polygon_id
      data <- distances %>% dplyr::filter(., point_id == vid & polygon_id %in% polygons$polygon_id[intersections[[which(coord$point_id == vid)]]]) %>% dplyr::slice_min(distance, n = 1)
      # Store in districtset
      districtset$polygon_id[districtset$point_id == vid] <- data$polygon_id
      districtset$distance[districtset$point_id == vid] <- data$distance
    } 
    for(vid in in_nodistricts) { # If in no districts, extract closest one
      # Filter statedistances dataset to just a single point_id, extract the row with the closest district (based on internal point)
      data <- distances %>% dplyr::filter(., point_id == vid) %>% dplyr::slice_min(distance, n = 1)
      # Store in districtset
      districtset$polygon_id[districtset$point_id == vid] <- data$polygon_id
      districtset$distance[districtset$point_id == vid] <- data$distance
    }
  
  rm(distances, data, intersections, id_count) # free up RAM
  
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
