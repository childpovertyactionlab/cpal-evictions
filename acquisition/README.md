# Data Acquisition

This directory is intended to contain the scripts, tools, and documentation for
any data that needs to be acquired for the data analysis components.

## DCAD Evictions SFTP

Eviction data is published in a daily and weekly format, on a daily and weekly
basis by the Dallas County Appraisal Distict. This information has been made
available via an SFTP server. `sync-dcad-evictions.sh` is intended to connect
to this server and synchronize a local directory with the files relevant
to this project (there is a filter embeded in the script as to what is
considered for synchronization).


# Build

Files within `src/` will be pushed into the root working directory of the image.

`./build-images.sh acquisition`

# Usage

Reference any `src/` script as the argument to container execution.

`docker run --rm cpal/ntep/acquisition:<version-tag> <src/*.sh>`
