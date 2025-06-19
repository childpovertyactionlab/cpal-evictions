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

# Deployment

## Environment

Specify `ENV=production` to place scripts in a production posture. What this means is script
specific, but typically it will involve disabling debug flags and more succinct logging.

## Google Workspace Access

Provide Google workspace service account credentials to the container:
```
--mount type=bind,src=path/to/token.json,dst=/var/run/secrets/google \
	-e 'GOOGLE_APPLICATION_CREDENTIALS=/var/run/secrets/google'
```

The script accesses Google sheets specified by `config.sheets.*`. The service account will need Editor
access to each sheet. Additionally, sheets can contain tabs, and if there are any "protected" tabs,
the service account will need explicit access to those.

## Configuration

A configuration file must be provided to the container as path `/app/config.yml`.

## Data Directories

Make sure to mount the DCAD Evictions source path, and the output data directories as are
configured in the `config.yml` file; `dcad.dest` and `data.root`, respectively.

## Execution Example

Here is a complete example of executing a script that needs a Google Service account, access to DCAD data (read-only), and the primary data directory:

```
docker run --rm \
  --mount type=bind,src=/host/config,dst=/app/config.yml \
  --mount type=bind,src=/host/token,dst=/var/run/secrets/google \
  -e 'GOOGLE_APPLICATION_CREDENTIALS=/var/run/secrets/google' \
  --mount type=bind,src=/host/evictions,dst=/data \
  --mount type=bind,src=/host/dcad-data,dst=/dcad-data,ro \
  -e ENV=production \
  someregistry/ntep/analysis:sometag \
  eviction-records-daily-googlesheet-processing.R
```

Not all scripts require the same elements, and it is best practice to execute the containers with the
minimum inputs and access.


# TODO

- Update `Jenkinsfile-build` to only build/publish new images when there is a change to the subsystem.
- `tigris` downloads files and will cache them inside the container, but that won't work because the container won't persist that cache. Need to configure a cache dir manually (https://www.rdocumentation.org/packages/tigris/versions/2.2.1/topics/tigris_cache_dir) and bind to something useful (volume?).
- Define `Jenkinsfile` for executing each subsystem.
