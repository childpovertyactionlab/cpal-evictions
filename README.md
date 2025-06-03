## Summary

This project consists of multiple repos:

- [Hyperobjekt/nte-backend](https://github.com/Hyperobjekt/nte-backend): contains backend infrastructure code and lambda functions for the api (and [data flow overview](https://github.com/Hyperobjekt/nte-backend/blob/main/CONTRIBUTING.md#data-flow))
- [childpovertyactionlab/cpal-evictions](https://github.com/childpovertyactionlab/cpal-evictions) (this repo): this repo contains source data for populating the database in the nte-backend
- [Hyperobjekt/north-texas-evictions](https://github.com/Hyperobjekt/north-texas-evictions): contains front end app code

# cpal-evictions
 A repository to store code and data for evictions activity in North Texas that feeds CPAL's North Texas Evictions website.

## filings
Eviction filing data that CPAL receives from County sources or from January Advisors. This data is limited to only the fields needed to build visualizations, and does not include any personal information related to plaintiffs or defendants in these eviction cases.

## demo
Demographic data, at various geographic scales, which is used as part of the choropleth maps on our eviction tool. GeoJSON files for each year and geographic level are provided here.

## bubbles
These GeoJSON files are the point centroids for the geographic scales mapped on our website. These are used, alongside the eviction filing data, to derive proportional symbols layered above the choropleth maps. 


# Build

Files within `scripts/` will be pushed into the root working directory of the image.

`./build-images.sh analysis`

# Usage

Reference any `scripts/` script as the argument to container execution.

`docker run --rm cpal/ntep/analysis:<version-tag> [scripts/*.R]`

Or ignore the script argument to see available scripts, example:

```
$ docker run --rm cpal/ntep/analysis:<version-tag>
Available scripts
-----------------
parsing-legislative-boundaries.R
eviction-records-ntep-join-and-clean.R
eviction-records-daily-googlesheet-processing.R
geography-demographics-and-bubble.R
data-review.R
ARCHIVE-eviction-records-full.R
eviction-records-add-additional-attributes-to-cases.R
merge-district-boundaries.R
```