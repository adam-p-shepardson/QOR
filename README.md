# QOR: Functions to Identify "Who Can Vote" in "What School District"
The QOR package contains functions for implementing the Query, Overlay, Recover (QOR) method, which links analytically useful administrative boundaries with the individual voter files that many U.S. states produce at little to no cost. We introduced QOR during a paper presentation at the 2025 Association for Education Finance and Policy Conference, and further detail the process with applied examples in a forthcoming paper. 

# Citation
Please cite our work as follows:

CURRENT CITATION

# Query, Overlay, Recover
QOR is a set of interwoven geospatial data management strategies which help address longstanding challenges in identifying "Who Votes" in school board elections. The process follows three simple steps:

1. Query

Leverage the U.S. Census Geocoder (or any Geocoding sevice of your choice) to transform addresses into precise longitude/latitude coordinates. The _query()_ function is a wrapper around the excellent _tidygeocoder_ (Cambon et al. 2021) that has been tailored to our specific data. We recommend _tidygeocoder_ for easily geocoding addresses in R, and provide _query()_ as a way to demonstrate how users can adapt _tidygeocoder_ for use with voter files.
   
2. Overlay

Superimpose school district shapefiles onto voter point geometries and exploit spatial object intersections to match voters with districts. The _overlay()_ function takes in point geometries (voter locations) and polygon geometries (school district boundaries) with unique identifer columns, and returns a dataset that matches each point to one polygon. For edge cases where points fall within multiple polygons or no polygons, the function calculates distances to polygon internal points and assigns points to the nearest polygon.

3. Recover

For the small portion of voters who cannot be located through an exact address match, assign the nearest school district to their registration zipcode. The _recover()_ function takes in units (with zipcodes), school district polygon geometries, and zipcode polygon geometries with unique identifer columns. It then calculates distances between the centroids for each zipcode and internal points for each school district, and returns a dataset that matches each voter to their nearest school district based on these new points.

# TL;DR
We provide template code for matching voters to school districts via this repository and welcome the use and modification of our code, with proper citation. Each step corresponds to a function in the QOR package:
- _query()_ for geocoding addresses into point geometries
- _overlay()_ for matching point geometries to polygon geometries (likely has the most general utility)
- _recover()_ for assigning unmatched points to polygons based on zipcode centroids

# Installation
To install the QOR package, use the following code in R:

```R 
 devtools::install_github("adam-p-shepardson/QOR")
```

# Minimal Data Requirements
QOR requires voter postal addresses, school district shapefiles, zipcode shapefiles, and a state boundary shapefile, with any time-varying shapes ideally obtained on a yearly basis. These undemanding data requirements can also accommodate paid voter files (including popular products from vendors L2 and Catalist) provided these products contain registration address information. We have set up several years of the [NCES school district shapefiles](https://www.dropbox.com/scl/fo/cq8l368nr0lfuq663g6id/AJarAbqc0PS9RAD_vbZ9ZpM?rlkey=4gviqpiehyufriffkue8371ga&st=twam8we4&dl=0) and [Census TIGER/LINE zipcode shapefiles](https://www.dropbox.com/scl/fo/nkvfbrzxe4lvlhowmy6j6/ACOSb9wP8kEjkEPIXC4XZSg?rlkey=zfp9wy70vehfil2reu7youbxn&st=dxnfczu0&dl=0) for use with QOR in Dropbox folders tied to this project. Note that it is difficult to download unzipped folders from Dropbox directly in R, and downloading the .zip file versions we have provided is much easier. 

For example, it is possible to copy a viewer link to .zip folders from Dropbox and unzip them in R like so:
```R
# Download
utils::download.file(url = "YOUR URL", destfile = "ZIP FOLDER DESTINATION PATH", mode = "wb", method = "auto")

# Unzip
utils::unzip(zipfile = "FILE/FOLDER PATH FROM 'destfile' ABOVE", exdir = "EXTRACTION PATH")
```

Additional years of the preferred shapefiles can be obtained from the U.S. Census Bureau's [TIGER/Line Shapefiles page](https://www.census.gov/geographies/mapping-files/time-series/geo/tiger-line-file.html) and the NCES Education Demographic and Geographic Estimates (EDGE) [program page](https://nces.ed.gov/programs/edge/Geographic/DistrictBoundaries). Users are advised to exercise caution and to view our functions' source code if substituting their own shapefiles. Users are also advised to understand the limitations of even the NCES shapefiles, which only update boundaries yearly from 2019 onward, and were updated every two years prior to 2019 (though documentation suggests that they are still re-posted every year in a manner that aligns with Census TIGER/LINE database updates). We treat the NCES shapefiles as the best available option for school district boundaries, and have stored copies of the closest shapefiles to each school year, but recognize that they are not perfect.

Although QOR focuses on linking voters to specific school districts, it is also possible to substitute the addresses of some other entity of interest (e.g., specific schools, businesses, etc...) into the code. Similarly, rather than matching such entities to school districts, QOR can facilitate placing research subjects within the bounds of any shapefiles one has on hand (e.g., special administrative districts broadly-speaking). We recognize these potential external applications despite focusing our attention on a persistent voter identification problem in political research about school board elections.

For additional notes on dependencies, computing environments, disclaimers, and external citations, please see the [Extra Notes](https://adam-p-shepardson.github.io/QOR/articles/extra-notes.html) page.
