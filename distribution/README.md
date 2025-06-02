# Data Distribution

This directory is intended to contain the scripts, tools, and documentation for
the ways in which data is distributed from this project's acquisition and/or
analysis efforts.

## North Texas Evictions Project website update

`push-web-update.sh` pushes aggregated data to to be ingested by the NTEP website.

## 3rd party research

`push-evictions-reference.sh` pushes "master" eviction files to an AWS S3 bucket
which exposes authenticated access.


# Build

Files within `src/` will be pushed into the root working directory of the image.

`./build-images.sh distribution`

# Usage

Reference any `src/` script as the argument to container execution.

`docker run --rm cpal/ntep/distribution:<version-tag> <src/*.sh>`
