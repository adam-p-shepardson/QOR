# Welcome to the QOR
The QOR package contains functions for implementing the Query, Overlay, Recover (QOR) method, which links analytically useful administrative boundaries with the individual voter files that many U.S. states produce at little to no cost. We introduced QOR during a paper presentation at the 2025 Association for Education Finance and Policy Conference, and further detail the process with applied examples in a forthcoming working paper. QOR minimally requires voter postal addresses, school district shapefiles, and zipcode shapefiles, ideally all obtained on a yearly basis. These undemanding data requirements can also accommodate paid voter files (including popular products from vendors L2 and Catalist) provided these products contain registration address information.

Although QOR originally focused on linking voters to specific school districts, it is also possible to substitute the addresses of some other entity of interest (e.g., specific schools, businesses, etc...) into the code. Similarly, rather than matching such entities to school districts, QOR can facilitate placing research subjects within the bounds of any shapefiles one has on hand (e.g., special administrative districts broadly-speaking). We recognize these potential external applications despite focusing our attention on a persistent voter identification problem in school board election research.

CURRENT CITATION: Working Paper will be cited here when finished.

# The QOR Method: Query, Overlay, Recover
Query, Overlay, Recover is a set of interwoven geospatial data management strategies which help address longstanding challenges in identifying "Who Votes" in school board elections. The process follows three simple steps:

1. Query

Leverage the U.S. Census Geocoder (or any Geocoding sevice of your choice) to transform addresses into precise longitude/latitude coordinates. The _query()_ function is a wrapper around the excellent _tidygeocoder_ (Cambon et al. 2021) that has been tailored to our specific data. We recommend _tidygeocoder_ for easily geocoding addresses in R, and provide _query()_ as a way to demonstrate how users can adapt _tidygeocoder_ for use with voter files.
   
2. Overlay

Superimpose school district shapefiles onto voter point geometries and exploit spatial object intersections to match voters with districts. The _overlay()_ function takes in point geometries (voter locations) and polygon geometries (school district boundaries) with unique identifer columns, and returns a dataset that matches each point to one polygon. For edge cases where points fall within multiple polygons or no polygons, the function calculates distances to polygon internal points and assigns points to the nearest polygon.

3. Recover

For the small portion of voters who cannot be located through an exact address match, assign the nearest school district to their registration zipcode. The _recover()_ function takes in units (with zipcodes), school district polygon geometries, and zipcode polygon geometries with unique identifer columns. It then calculates distances between the centroids for each zipcode and internal points for each school district, and returns a dataset that matches each voter to their nearest school district based on these new points.

# TL;DR
The three steps highlighted in broad terms above provide an easy-to-understand logic that readily translates into tangible code. We have provided template code to the public via this repository and welcome the use and modification of our code, with proper citation. Each step corresponds to a function in the QOR package:
- _query()_ for geocoding addresses into point geometries
- _overlay()_ for matching point geometries to polygon geometries
- _recover()_ for assigning unmatched points to polygons based on zipcode centroids

# A Note on Dependencies and Computing Environments
We originally used a conda environment that installed R version 4.2.0 (most recent version compatible with the cloud computing system of the lead author's university) and the required depencies simultaneously, with scripts run on Linux-based machines. Please note that, broadly speaking, many voter files are large and some cases, like multi-year panels, may require significant computing power. Evaluate the size of your data and the computing power available to you before running code. Academic audiences may not be aware that R generally manipulates objects through a copy-on-modify system that requires more memory than is often expected to manipulate large objects (see Ch. 2 of Wickham 2019). If you work with large datasets, you may need to increase the memory available to R. One (rough) rule of thumb is that you should have at least 2x the size of the object in memory to manipulate it.

# Disclaimer
When using data obtained from governments, please consult the laws of the specific government(s) in question to ensure compliance.

# External Citations
Cambon J., Hernangómez D., Belanger C., Possenriede D. (2021).
  tidygeocoder: An R package for geocoding. Journal of Open Source
  Software, 6(65), 3544, https://doi.org/10.21105/joss.03544 (R package
  version 1.0.6)
Wickham, H. (2019). Advanced R, Second Edition. Chapman & Hall/CRC. Accessed at https://adv-r.hadley.nz/
