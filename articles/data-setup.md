# Data Setup

## Helpful Packages

Most applications for the QOR method likely require data cleaning and
manipulation of both typical data frames and spatial objects. The list
of R packages below are likely to be helpful in these tasks, and are
dependencies of the QOR package itself:

``` r
library(tidyverse)
library(dplyr)
library(haven)
library(sf)
library(QOR)

# You would need your local path below to run the setup examples:
local_path <- here::here() # replace with your local path to the QOR folder if not running from the root directory of the repo
```

## Downloading Example Files

In the provided example, we download zipped (.zip file) versions of:

- extracts: Anonymized 2022 voter registration extract sample (~0.05%)
  for North Carolina
- zip_codes: National zip code shapefiles from the U.S. Census Bureau
- state_shape: State boundary shapefile from the North Carolina
  Geospatial Data Clearinghouse
- district_shapes: National school district shapefiles from the National
  Center for Education Statistics (NCES)

We unzip these files for direct use in this tutorial. We also set a
generous download timeout given that several files are quite large.

Users should note that a cleaned verison of our small, anonymized random
sample of North Carolina voter registration data is included in the QOR
package for educational purposes. This sample data results from the
address cleaning example further below. For real applications, however,
users will need to obtain their own voter registration data from a
relevant governmental unit (or a paid provider like L2).

``` r
# Increase timeout for large files
options(timeout = 1000)

# Define URLs (example: North Carolina 2022 data)
extracts <- "https://www.dropbox.com/scl/fi/epopkf7wqtgs9ymod0w3h/Example-Extracts.zip?rlkey=mfuzylz2iinljy3f5te86fc1p&st=26tify0g&dl=1"
zip_codes <- "https://www.dropbox.com/scl/fi/sq0mudsvm1g7c9ljbiye1/ZIP_2022.zip?rlkey=v9gqxsx0b1dli7lnoi95qwlyv&st=p7lprz1m&dl=1"
state_shape <- "https://www.dropbox.com/scl/fi/a8bn3ht1d67xd412zixf5/North_Carolina_State_Boundary.zip?rlkey=2j0at3vvts5i62trqvm4itpa5&st=0soqpq4j&dl=1"
district_shapes <- "https://www.dropbox.com/scl/fi/eh557z55pg9051dq4mves/SCHOOL_SY2022.zip?rlkey=ds8a7pocgj7evgsmvhsn9dyow&st=tecyt8yc&dl=1"

# Download shapefiles
download.file(url = zip_codes, destfile = paste0(local_path, "/data-raw/Downloads/zip_codes_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "/data-raw/Downloads/zip_codes_2022.zip"), exdir = paste0(local_path, "/data-raw/Extracted"))
download.file(url = state_shape, destfile = paste0(local_path, "/data-raw/Downloads/state_shape.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "/data-raw/Downloads/state_shape.zip"), exdir = paste0(local_path, "/data-raw/Extracted"))
download.file(url = district_shapes, destfile = paste0(local_path, "/data-raw/Downloads/district_shapes_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "/data-raw/Downloads/district_shapes_2022.zip"), exdir = paste0(local_path, "/data-raw/Extracted")) 
```

## Cleaning Addresses

Before using QOR, it is imperative to ensure that your input data
contain a minimal set of string address components:

- street
- city
- state

You may find that these components must be built from other
sub-components (e.g., street name, street number, apartment number,
etc…). Below, we read-in our small random sample of anonymous voters
before address processing. Note that the “ncid” field is randomized and
does not correspond to actual voter IDs.

``` r
# Download anonymized voter registration extracts (Taken Jan. 1, 2022)
download.file(url = extracts, destfile = paste0(local_path, "/data-raw/Downloads/Extracts_2022.zip"), mode = "wb", method = "auto")
unzip(zipfile = paste0(local_path, "/data-raw/Downloads/Extracts_2022.zip"), exdir = paste0(local_path, "/data-raw/Extracted"))
sample_2022 <- haven::read_dta(paste0(local_path, "/data-raw/Extracted/Example Extracts/VR_Snapshot_2022_ALL_Anonymized.dta"))

# View a few raw observations
print(head(sample_2022, n = 10))
#> # A tibble: 10 × 12
#>       ncid house_num half_code street_dir street_name street_type_cd
#>      <dbl>     <dbl> <chr>     <chr>      <chr>       <chr>         
#>  1 4425080      1717 ""        ""         GARNER      RD            
#>  2 2548754      1200 ""        "S"        HOLLYBROOK  RD            
#>  3 4575744       126 ""        ""         BREADNUT    DR            
#>  4 5823161     15424 ""        ""         GUTHRIE     DR            
#>  5 6254308       550 ""        ""         CLARK       RD            
#>  6 3426091       512 ""        ""         FINDHORN    LN            
#>  7 5357071       707 ""        ""         PLUMMER     DR            
#>  8 1978651      1212 ""        ""         FILMORE     ST            
#>  9 4491130       748 ""        ""         CAR FARM    RD            
#> 10 2993188       104 ""        ""         NEEDLE PARK DR            
#> # ℹ 6 more variables: street_sufx_cd <chr>, unit_designator <chr>,
#> #   unit_num <chr>, res_city_desc <chr>, state_cd <chr>, zip_code <chr>
```

Then, we can prepare addresses for geocoding. Our example was written in
Stata and saved as a .dta file, though address cleaning can occur in any
programming language.

**Example workflow:**

- Load raw address data
- Rename address component variables to a standard format across data
  years
- Convert all address components and/or their subcomponents to strings
  (e.g., string variables for street, city, postalcode, and state)
- *Likely Needed:* Construct the *full* street address from
  subcomponents to the extent possible given data availability
- Remove leading/trailing whitespace in all variables
- Make sure to retain or generate a unique state voter (or other unit)
  id along with separate variables for street, city, postalcode, and
  state

``` r
## Read in cleaned sample
# We call an external Stata .do file (available on GitHub) for simplicity:
library(RStata)
options("RStata.StataPath" = "/usr/local/stata19/stata-se") # Path to your Stata executable. Use console version instead of GUI (stata-se instead of xstata-se)
suppressWarnings(stata(src = paste0(local_path, "/data-raw/NCAddresses.do"), stata.version = 19.5, stata.echo = TRUE, 
              arguments = shQuote(local_path)))

# Note: The above line requires the RStata package (install.packages("RStata")) and a local installation of Stata
# If using GUI version (xstata-se), GTK warnings may appear but can be ignored if output is correct
```

## Next Steps

Different raw data structures will require unique approaches to produce
a format compatible with QOR functions. However, With cleaned addresses,
you are now ready to geocode your data and apply the QOR method. Your
addresses should look similar to the following example input dataframe
when correctly prepared for
[`query()`](https://adam-p-shepardson.github.io/QOR/reference/query.md).

``` r
# Read the cleaned example addresses
example <- haven::read_dta(system.file("example_data", "sample_2022_addresses.dta", package = "QOR"))

# View a few cleaned addresses
print(head(example, n = 10))
#> # A tibble: 10 × 5
#>    statevoterid street                city         state postalcode
#>    <chr>        <chr>                 <chr>        <chr> <chr>     
#>  1 4425080      1717   GARNER RD      GREENVILLE   NC    27834     
#>  2 2548754      1200  S HOLLYBROOK RD WENDELL      NC    27591     
#>  3 4575744      126   BREADNUT DR     SMITHFIELD   NC    27577     
#>  4 5823161      15424   GUTHRIE DR    HUNTERSVILLE NC    28078     
#>  5 6254308      550   CLARK RD        VANCEBORO    NC    28586     
#>  6 3426091      512   FINDHORN LN     WAKE FOREST  NC    27587     
#>  7 5357071      707   PLUMMER DR      GREENSBORO   NC    27410     
#>  8 1978651      1212   FILMORE ST     RALEIGH      NC    27605     
#>  9 4491130      748   CAR FARM RD     LINCOLNTON   NC    28092     
#> 10 2993188      104   NEEDLE PARK DR  CARY         NC    27513
```

Please see the [Getting
Started](https://adam-p-shepardson.github.io/QOR/articles/getting-started.html)
vignette and the function documentation for additional guidance.
