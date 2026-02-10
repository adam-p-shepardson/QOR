# Extra Notes

## Computing Environments

The data employed in our paper used a conda environment that installed R
version 4.2.0 (the most recent R version compatible with the cloud
computing system of the lead author’s university) and the required
dependencies simultaneously. Scripts to match voters to school districts
were originally run on Linux-based machines. Please note that, broadly
speaking, many voter files are large and some use cases may require
significant computing power.

Evaluate the size of your data and the computing power available to you
before running code. Academic audiences may not be aware that R
generally manipulates objects through a copy-on-modify system that
requires more memory than is often expected to manipulate large objects
(see Ch. 2 of Wickham, 2019). If you work with large datasets, you may
need to increase the memory available to R. One (rough) rule of thumb is
that you should have at least 2x the size of the object in memory to
manipulate it.

We have, additionally, verified that the QOR package and its functions
work with a newer R version (4.3.3) on Linux; we anticipate that
creators of the relevant dependencies will continue to support new R
releases in the future, as these are well-known packages.

## Disclaimer

When using data obtained from any level of government, please consult
the laws of the specific government(s) in question to ensure compliance.
It is important to understand that U.S. states differ widely in their
laws regarding the use of voter registration data. Users are solely
responsible for ensuring that their use of the data complies with all
applicable laws and regulations. The authors of this package do not
assume any liability for users’ treatment of any data or their use of
the package itself.

## Reference List

Text throughout this website cites the following external references:

Cambon J., Hernangómez D., Belanger C., & Possenriede D. (2021).
tidygeocoder: An R package for geocoding. *Journal of Open Source
Software, 6*(65), 3544, <https://doi.org/10.21105/joss.03544> (R package
version 1.0.6)

Pebesma, E., & Bivand, R. (2023). *Spatial Data Science: With
applications in R*. Chapman and Hall/CRC. <doi:10.1201/9780429459016>,
<https://r-spatial.org/book/>.

Wickham, H. (2019). *Advanced R, Second Edition*. Chapman & Hall/CRC.
Accessed at <https://adv-r.hadley.nz/>
