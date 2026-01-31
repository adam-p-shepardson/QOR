# QOR: Functions to Identify Who Can Vote in What School District

The QOR package contains functions for implementing the Query, Overlay, Recover (QOR) method, which links analytically useful administrative boundaries with the individual voter files that many U.S. states produce at little to no cost. We introduced QOR during a paper presentation at the 2025 Association for Education Finance and Policy Conference, and further detail the process with applied examples in a forthcoming paper. 

# Citation

Please cite our work as follows:

Shepardson, A., Lyon, M., Schueler, B., & Bleiberg, J. (2026). QOR: Functions to Identify 'Who Can Vote' in 'What School District' (Version 0.9.0.0) [Computer software]. https://adam-p-shepardson.github.io/QOR

# Query, Overlay, Recover

QOR is a set of interwoven geospatial data management strategies which help address longstanding challenges in identifying "Who Votes" in school board elections. The process follows three simple steps:

1. Query

Leverage the U.S. Census Geocoder (or any Geocoding sevice of your choice) to transform addresses into precise longitude/latitude coordinates. The `query()` function is a wrapper around the excellent _tidygeocoder_ (Cambon et al., 2021) that has been tailored to our specific data. We recommend _tidygeocoder_ for easily geocoding addresses in R, and provide `query()` as a way to demonstrate how users can adapt _tidygeocoder_ for use with voter files.
   
2. Overlay

Superimpose school district shapefiles onto voter point geometries and exploit spatial object intersections to match voters with districts. The `overlay()` function takes in point geometries (voter locations) and polygon geometries (school district boundaries) with unique identifer columns, and returns a dataset that matches each point to one polygon. For edge cases where points fall within multiple polygons or no polygons, the function calculates distances to polygon internal points and assigns points to the nearest polygon.

3. Recover

For the small portion of voters who cannot be located through an exact address match, assign the nearest school district to their registration zipcode. The `recover()` function takes in units (with zipcodes), school district polygon geometries, and zipcode polygon geometries with unique identifer columns. It then calculates distances between the centroids for each zipcode and internal points for each school district, and returns a dataset that matches each voter to their nearest school district based on these new points.

# TL;DR

We provide template code for matching voters to school districts via this repository and welcome the use and modification of our code, with proper citation. Each step corresponds to a function in the QOR package:

- `query()` for geocoding addresses into point geometries
- `overlay()` for matching point geometries to polygon geometries
- `recover()` for assigning unmatched points to polygons based on zipcode centroids

# Installation

To install the QOR package, use the following code in R:

```R 
 devtools::install_github("adam-p-shepardson/QOR", dependencies=TRUE)
```
Please note that installing the _sf_ (Pebesma & Bivand, 2023) dependency is more difficult on MacOS and Linux than for Windows. Mac and Linux users may need to follow the instructions here before installing QOR: https://github.com/r-spatial/sf 

# Minimal Data Requirements

QOR requires voter postal addresses, school district shapefiles, zipcode shapefiles, and a state boundary shapefile, with any time-varying shapes ideally obtained on a yearly basis. These undemanding data requirements can also accommodate paid voter files (including popular products from vendors L2 and Catalist) provided these products contain registration address information. School district shapefiles from the [NCES Education Demographic and Geographic Estimates (EDGE) program](https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries) and zipcode shapefiles from the [Census TIGER/LINE database](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html) are preferred for use with QOR. Note that it is difficult to download unzipped folders directly in R, and downloading .zip file versions is much easier. 

For example, it is possible to copy a link to .zip folders and unzip them in R like so:

```R
# Download
utils::download.file(url = "YOUR URL", destfile = "ZIP FOLDER DESTINATION PATH", mode = "wb", method = "auto")

# Unzip
utils::unzip(zipfile = "FILE/FOLDER PATH FROM 'destfile' ABOVE", exdir = "EXTRACTION PATH")
```

Users are advised to exercise caution and to view our functions' source code if substituting their own shapefiles. Users are also advised to understand the limitations of even the NCES shapefiles, which only recently began to update boundaries yearly (though documentation suggests that they are still re-posted every year in a manner that aligns with Census TIGER/LINE database updates). We treat the NCES shapefiles as the best available national option for school district boundaries, but recognize that they are not perfect.

Although QOR focuses on linking voters to specific school districts, it is also possible to substitute the addresses of some other entity of interest (e.g., specific schools, businesses, etc...) into the code. Similarly, rather than matching such entities to school districts, QOR can facilitate placing research subjects within the bounds of any shapefiles one has on hand (e.g., special administrative districts broadly-speaking). We recognize these external applications despite focusing our attention on a persistent voter identification problem in political research about school board elections.

# Tutorials

Guidance on setting up raw data for use with QOR is available in the [Data Setup](https://adam-p-shepardson.github.io/QOR/articles/data-setup.html) vignette.

Similaly, we provide example code for using each of the three main functions in the [Getting Started](https://adam-p-shepardson.github.io/QOR/articles/getting-started.html) vignette.

For additional notes, external citations, and disclaimers, please see the [Extra Notes](https://adam-p-shepardson.github.io/QOR/articles/extra-notes.html) page.
