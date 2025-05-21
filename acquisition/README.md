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

# TODO

- Define a Dockerfile to package the synchronization scripts.
