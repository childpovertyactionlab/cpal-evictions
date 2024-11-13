library(tidyverse)
library(rio)
library(sf)

evictions <- rio::import("filing data/NTEP_eviction_cases.csv")

demo_tract <- st_read("demo/NTEP_demographics_tract.geojson")

demo_elem <- st_read("demo/NTEP_demographics_elemschool.geojson")
demo_midd <- st_read("demo/NTEP_demographics_midschool.geojson")
demo_high <- st_read("demo/NTEP_demographics_highschool.geojson")

bubb_elem <- st_read("bubble/NTEP_bubble_elemschool.geojson")

unique(evictions$elem_id)
unique(demo_elem$id)
unique(bubb_elem$id)






tot_elem <- evictions %>%
  group_by(elem_id) %>%
  summarize(count = n())

tot_midd <- evictions %>%
  group_by(midd_id) %>%
  summarize(count = n())

tot_high <- evictions %>%
  group_by(high_id) %>%
  summarize(count = n())

test <- evictions %>%
  filter(elem_id == "9-ntx-032") %>%
  st_as_sf(coords = c("lon", "lat"), crs = 4269)

plot(test["zip_id"])
