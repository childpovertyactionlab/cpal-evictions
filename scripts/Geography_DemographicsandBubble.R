library(tidyverse)
library(tidycensus)
library(rio)
library(sf)
library(rmapshaper)

#acs18_b <- load_variables(2019, "acs5", cache = TRUE)
#acs18_s <- load_variables(2019, "acs5/subject", cache = TRUE)

counties <- c("Dallas County", 
              "Collin County", 
              "Denton County", 
              "Tarrant County")

ntx_counties <- tigris::counties(state = "TX") %>%
  filter(NAMELSAD %in% counties)

#list of the necessary variables to pull
acs_var <- c(
  tot_pop = "B01003_001", #total population
  pop_u18 = "S0101_C01_022", #population under 18
  med_inc = "B19013_001", #median household income
  med_rent = "S0102_C01_106", #median monthly housing costs
  his_pop = "B03002_012", #hispanic population
  wh_pop = "B03002_003", #white population
  bl_pop = "B03002_004", #black population
  as_pop = "B03002_006", #asian population
  rohh = "B25106_024", #renter-occupied households
  thh = "B25106_001", #total households
  pop_bp = "S1701_C02_001", #population below poverty
  bp_u18 = "S1701_C02_002", #population under 18 below poverty
  med_val = "S2506_C01_009", #median value of owner-occupied housing units
  rcb = "S0102_C01_105" #gross rent as a percentage of income 30% or more
)

eviction_tract <- get_acs(geography = "tract", 
                           state = "TX",
                           county = counties,
                           variables = acs_var,
                           year = 2019, 
                           survey = "acs5", 
                           output = "wide",
                           geometry = TRUE) %>%
  transmute(id = GEOID,
         name = NAME,
         pop = tot_popE,
         pvr = pop_bpE/tot_popE,
         cpr = bp_u18E/pop_u18E,
         prh = rohhE/thhE,
         mgr = med_rentE,
         mpv = med_valE,
         mhi = med_incE,
         rb = rcbE/100,
         pca = as_popE/tot_popE,
         pcb = bl_popE/tot_popE,
         pcw = wh_popE/tot_popE,
         pch = his_popE/tot_popE,
         ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_tract["rb"])

eviction_zcta <- get_acs(geography = "zcta", 
                          #state = "TX",
                          variables = acs_var,
                          year = 2019, 
                          survey = "acs5", 
                          output = "wide",
                          geometry = TRUE) %>%
  .[ntx_counties, ] %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = rcbE/100,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_zcta["rb"])

eviction_place <- get_acs(geography = "place", 
                          state = "TX",
                          variables = acs_var,
                          year = 2019, 
                          survey = "acs5", 
                          output = "wide",
                          geometry = TRUE) %>%
  .[ntx_counties, ] %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = rcbE/100,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_place["rb"])

eviction_county <- get_acs(geography = "county", 
                          state = "TX",
                          county = counties,
                          variables = acs_var,
                          year = 2019, 
                          survey = "acs5", 
                          output = "wide",
                          geometry = TRUE) %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = rcbE/100,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_county["rb"])

eviction_council <- st_read("E:/CPAL Dropbox/Data Library/City of Dallas/02_Boundaries and Features/Council_Simple.shp") %>%
  select(DISTRICT, geometry) %>%
  rename(name = DISTRICT) %>%
  mutate(name = paste("Council District", name)) %>%
  st_transform(crs = 4269) %>%
  ms_simplify(., keep = 0.2)


# Export to geojson #####
st_write(eviction_tract, "demo/NTEP_demographics_tract.geojson", delete_dsn = TRUE)
st_write(eviction_zcta, "demo/NTEP_demographics_zip.geojson", delete_dsn = TRUE)
st_write(eviction_place, "demo/NTEP_demographics_place.geojson", delete_dsn = TRUE)
st_write(eviction_county, "demo/NTEP_demographics_county.geojson", delete_dsn = TRUE)
st_write(eviction_council, "demo/NTEP_demographics_council.geojson", delete_dsn = TRUE)

# BUBBLE DATA #####
bubble_county <- eviction_county %>%
  select(id, name, pop) %>%
  st_point_on_surface(.)

bubble_place <- eviction_place %>%
  select(id, name, pop) %>%
  st_point_on_surface(.)

bubble_zcta <- eviction_zcta %>%
  select(id, name, pop) %>%
  st_point_on_surface(.)

bubble_tract <- eviction_tract %>%
  select(id, name, pop) %>%
  st_point_on_surface(.)

bubble_council <- eviction_council %>%
#  select(id, name, pop) %>%
  st_point_on_surface(.)

# Export to geojson #####
st_write(bubble_tract, "bubble/NTEP_bubble_tract.geojson", delete_dsn = TRUE)
st_write(bubble_zcta, "bubble/NTEP_bubble_zip.geojson", delete_dsn = TRUE)
st_write(bubble_place, "bubble/NTEP_bubble_place.geojson", delete_dsn = TRUE)
st_write(bubble_county, "bubble/NTEP_bubble_county.geojson", delete_dsn = TRUE)
st_write(bubble_council, "bubble/NTEP_bubble_council.geojson", delete_dsn = TRUE)
