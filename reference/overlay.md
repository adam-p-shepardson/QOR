# Match Point Geometries to Polygon Geometries (e.g., Voter Locations to School Districts)

The `overlay()` function performs the "Overlay" (Step 2) operation from
the QOR Method.

## Usage

``` r
overlay(
  points = NULL,
  polygons = NULL,
  point_id = "point_id",
  polygon_id = "polygon_id",
  used_NCES = FALSE,
  FIPS_code = NULL,
  FIPS_col = NULL
)
```

## Arguments

- points:

  sf object containing point geometries for units (e.g., voter
  locations).

- polygons:

  sf object containing polygon geometries (e.g., school districts).

- point_id:

  Name of the column in the points sf object that contains unique
  identifiers for each point (default: "point_id"). Preferably as
  string.

- polygon_id:

  Name of the column in the polygons sf object that contains unique
  identifiers for each polygon (default: "polygon_id"). Preferably as
  string.

- used_NCES:

  Boolean indicating whether the user input NCES school district
  shapefiles or other shapefiles with a state FIPS_code as the polygons
  (default: FALSE).

- FIPS_code:

  State FIPS code to filter NCES or other school district shapefiles
  (default: NULL, which means no filtering by state).

- FIPS_col:

  Column name in your dataset containing FIPS_code. Preferably should be
  a character/string variable (default: NULL, which means no filtering
  by state).

## Value

A tibble with three columns: point_id (string), polygon_id (string), and
distance (based on units CRS; only for points not in just one polygon).
Each point_id is matched to one polygon_id.

## Details

This function:

- Matches point geometries (e.g., voter locations) to polygon geometries
  (e.g., school districts) using spatial intersections and distances.

- Requires that all points and polygons each have a unique identifier
  column.

- If observations are not unique (e.g., panel data), use only one
  timepoint per function call (e.g., all voters in one year, then all
  voters in the next year, etc...).

- Returns a match that assigns **one** polygon to each point: the
  polygon the point is in, or the closest polygon (based on internal
  point) if the point is not in any polygon.

- To return multiple polygons per point, you will need to modify the
  code.
