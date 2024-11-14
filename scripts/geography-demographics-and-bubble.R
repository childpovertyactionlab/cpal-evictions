
#### Load needed libraries #####
library(tidyverse)
library(tidycensus)
library(rio)
library(sf)
library(rmapshaper)

libDB <- "E:/CPAL Dropbox/"
#libDB <- "C/Users/erose/CPAL Dropbox/"

#acs19_b <- load_variables(2019, "acs5", cache = TRUE)
#acs19_s <- load_variables(2019, "acs5/subject", cache = TRUE)

#### Import demographic variables from TidyCensus #####
counties <- c("Dallas County", 
              "Collin County", 
              "Denton County", 
              "Tarrant County",
              "Kaufman County",
              "Ellis County",
              "Rockwall County",
              "Johnson County")

ntx_counties <- tigris::counties(state = "TX") %>%
  filter(NAMELSAD %in% counties)

ntep_counties <- ntx_counties %>%
  filter(NAMELSAD %in% c("Dallas County",
                         "Tarrant County",
                         "Collin County",
                         "Denton County"))

##### Import School District Data #####

acs_var <- c(
  tot_pop = "B01003_001", #total population
  pop_u18 = "B17006_001", #population under 18
  med_inc = "B19013_001", #median household income
  med_rent = "B25031_001", #median monthly housing costs
  his_pop = "B03002_012", #hispanic population
  wh_pop = "B03002_003", #white population
  bl_pop = "B03002_004", #black population
  as_pop = "B03002_006", #asian population
  rohh = "B25106_024", #renter-occupied households
  thh = "B25106_001", #total households
  pop_bp = "B17020_002", #population below poverty
  bp_u18 = "B17006_002", #population under 18 below poverty
  med_val = "B25097_001", #median value of owner-occupied housing units
  rcb1 = "B25106_028", #gross rent as a percentage of income 30% or more,
  rcb2 = "B25106_032",
  rcb3 = "B25106_036",
  rcb4 = "B25106_040",
  rcb5 = "B25106_044"
)

#### Tidy Census Tracts #####
census_tract <- get_acs(geography = "tract", 
                           state = "TX",
                           county = counties,
                           variables = acs_var,
                           year = 2022, 
                           survey = "acs5", 
                           output = "wide",
                           geometry = TRUE) %>%
  mutate(AreaTract = as.numeric(st_area(.)),
         rcbE = rcb1E+rcb2E+rcb3E+rcb4E+rcb5E)

eviction_tract <- census_tract %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            rhh = rohhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = (rcb1E+rcb2E+rcb3E+rcb4E+rcb5E)/rohhE,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE) %>%
  ms_simplify(., keep = 0.2) %>%
  filter(str_detect(name, c("Dallas|Collin|Denton|Tarrant")))

plot(eviction_tract["rb"], breaks = "jenks")
#plot(eviction_tract["mpv"])
#plot(eviction_tract["mgr"])
#plot(eviction_tract["pvr"])
#plot(eviction_tract["cpr"])

#### Tidy Census ZCTA #####
zctas <- tigris::zctas(year = 2020) %>%
  rename(GEOID = GEOID20) %>%
  select(GEOID, geometry)

eviction_zcta <- get_acs(geography = "zcta", 
                          #state = "TX",
                          variables = acs_var,
                          year = 2022, 
                          survey = "acs5", 
                          output = "wide") %>%
  left_join(zctas, .) %>%
  .[ntep_counties, ] %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            rhh = rohhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = (rcb1E+rcb2E+rcb3E+rcb4E+rcb5E)/rohhE,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_zcta["rb"])
#plot(eviction_zcta["mpv"])
#plot(eviction_zcta["mgr"])
#plot(eviction_zcta["pvr"])
#plot(eviction_zcta["cpr"])

#### Tidy Census Place #####
eviction_place <- get_acs(geography = "place", 
                          state = "TX",
                          variables = acs_var,
                          year = 2022, 
                          survey = "acs5", 
                          output = "wide",
                          geometry = TRUE) %>%
  .[ntep_counties, ] %>%
  mutate(NAME = str_replace(NAME, " city, Texas", ", Texas"),
         NAME = str_replace(NAME, " town, Texas", " , Texas")) %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            rhh = rohhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = (rcb1E+rcb2E+rcb3E+rcb4E+rcb5E)/rohhE,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_place["rb"])
#plot(eviction_place["mpv"])
#plot(eviction_place["mgr"])
#plot(eviction_place["pvr"])
#plot(eviction_place["cpr"])

#### Tidy Census County #####
eviction_county <- get_acs(geography = "county", 
                          state = "TX",
                          county = ntep_counties$NAMELSAD,
                          variables = acs_var,
                          year = 2022, 
                          survey = "acs5", 
                          output = "wide",
                          geometry = TRUE) %>%
  transmute(id = GEOID,
            name = NAME,
            pop = tot_popE,
            pvr = pop_bpE/tot_popE,
            cpr = bp_u18E/pop_u18E,
            prh = rohhE/thhE,
            rhh = rohhE,
            mgr = med_rentE,
            mpv = med_valE,
            mhi = med_incE,
            rb = (rcb1E+rcb2E+rcb3E+rcb4E+rcb5E)/rohhE,
            pca = as_popE/tot_popE,
            pcb = bl_popE/tot_popE,
            pcw = wh_popE/tot_popE,
            pch = his_popE/tot_popE,
  ) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_county["rb"])
#plot(eviction_county["mpv"])
#plot(eviction_county["mgr"])
#plot(eviction_county["pvr"])
#plot(eviction_county["cpr"])

#### Tidy Census City Council #####
eviction_council <- st_read(paste0(libDB, "Data Library/City of Dallas/02_Boundaries and Features/Legislative Boundaries/City Council 2023 Boundaries/Council_Simple.shp")) %>%
  mutate(DISTRICT = str_pad(DISTRICT, 2, pad = "0")) %>%
  select(DISTRICT, geometry) %>%
  st_transform(crs = 4269) %>%
  st_intersection(census_tract, .) %>%
  mutate(id = paste0("4819000_", DISTRICT),
         name = paste("Council District", DISTRICT),
         AreaIntersect = as.numeric(st_area(.)),
         PerIntersect = AreaIntersect/AreaTract,
         pop_intersect = round(PerIntersect*tot_popE, digits = 4),
         popbp_intersect = round(PerIntersect*pop_bpE, digits = 4),
         popu18_intersect = round(PerIntersect*pop_u18E, digits = 4),
         bpu18_intersect = round(PerIntersect*bp_u18E, digits = 4),
         rohh_intersect = round(PerIntersect*rohhE, digits = 4),
         thh_intersect = round(PerIntersect*thhE, digits = 4),
         rcb_intersect = round(PerIntersect*rcbE, digits = 4),
         as_intersect = round(PerIntersect*as_popE, digits = 4),
         bl_intersect = round(PerIntersect*bl_popE, digits = 4),
         wh_intersect = round(PerIntersect*wh_popE, digits = 4),
         his_intersect = round(PerIntersect*his_popE, digits = 4)
         ) %>%
    group_by(id, name) %>%
    summarise(pop = sum(pop_intersect),
              pvr = sum(popbp_intersect)/pop,
              cpr = sum(bpu18_intersect)/sum(popu18_intersect),
              prh = sum(rohh_intersect)/sum(thh_intersect),
              rhh = sum(rohh_intersect), 
              mgr = mean(med_rentE, na.rm = TRUE),
              mpv = mean(med_valE, na.rm = TRUE),
              mhi = mean(med_incE, na.rm = TRUE),
              rb = sum(as_intersect)/100,
              pca = sum(as_popE)/pop,
              pcb = sum(bl_intersect)/pop,
              pcw = sum(wh_intersect)/pop,
              pch = sum(his_intersect)/pop) %>%
  select(id, name, pop:pch) %>%
  ms_simplify(., keep = 0.2)

plot(eviction_council["rb"])
#plot(eviction_council["mpv"])
#plot(eviction_council["mgr"])

#### Tidy Census School Boundary #####

#eviction_elem <- st_read("C:/Users/erose/CPAL Dropbox/Data Library/Dallas Independent School District/2024_2025 School Year/Elementary_Attendance_Boundaries.geojson") %>%
eviction_elem <- st_read("data/geographies/elem_boundaries.geojson") %>%
  select(id = unique_id,
         name = schoolname, 
         geometry) %>%
  st_transform(crs = 4269) %>%
  st_intersection(census_tract, .) %>%
  mutate(AreaIntersect = as.numeric(st_area(.)),
         PerIntersect = AreaIntersect/AreaTract,
         pop_intersect = round(PerIntersect*tot_popE, digits = 4),
         popbp_intersect = round(PerIntersect*pop_bpE, digits = 4),
         popu18_intersect = round(PerIntersect*pop_u18E, digits = 4),
         bpu18_intersect = round(PerIntersect*bp_u18E, digits = 4),
         rohh_intersect = round(PerIntersect*rohhE, digits = 4),
         thh_intersect = round(PerIntersect*thhE, digits = 4),
         rcb_intersect = round(PerIntersect*rcbE, digits = 4),
         as_intersect = round(PerIntersect*as_popE, digits = 4),
         bl_intersect = round(PerIntersect*bl_popE, digits = 4),
         wh_intersect = round(PerIntersect*wh_popE, digits = 4),
         his_intersect = round(PerIntersect*his_popE, digits = 4)
  ) %>%
  group_by(id, name) %>%
  summarise(pop = sum(pop_intersect),
            pvr = sum(popbp_intersect)/pop,
            cpr = sum(bpu18_intersect)/sum(popu18_intersect),
            prh = sum(rohh_intersect)/sum(thh_intersect),
            rhh = sum(rohh_intersect), 
            mgr = mean(med_rentE, na.rm = TRUE),
            mpv = mean(med_valE, na.rm = TRUE),
            mhi = mean(med_incE, na.rm = TRUE),
            rb = sum(as_intersect)/100,
            pca = sum(as_popE)/pop,
            pcb = sum(bl_intersect)/pop,
            pcw = sum(wh_intersect)/pop,
            pch = sum(his_intersect)/pop) %>%
  select(id, name, pop:pch) %>%
  ms_simplify(., keep = 0.2) %>%
  .[ntep_counties, ]

plot(eviction_elem["pop"])

eviction_midd <- st_read("data/geographies/mid_boundaries.geojson") %>%
  select(id = unique_id,
         name = schoolname, 
         geometry) %>%
  st_transform(crs = 4269) %>%
  st_intersection(census_tract, .) %>%
  mutate(AreaIntersect = as.numeric(st_area(.)),
         PerIntersect = AreaIntersect/AreaTract,
         pop_intersect = round(PerIntersect*tot_popE, digits = 4),
         popbp_intersect = round(PerIntersect*pop_bpE, digits = 4),
         popu18_intersect = round(PerIntersect*pop_u18E, digits = 4),
         bpu18_intersect = round(PerIntersect*bp_u18E, digits = 4),
         rohh_intersect = round(PerIntersect*rohhE, digits = 4),
         thh_intersect = round(PerIntersect*thhE, digits = 4),
         rcb_intersect = round(PerIntersect*rcbE, digits = 4),
         as_intersect = round(PerIntersect*as_popE, digits = 4),
         bl_intersect = round(PerIntersect*bl_popE, digits = 4),
         wh_intersect = round(PerIntersect*wh_popE, digits = 4),
         his_intersect = round(PerIntersect*his_popE, digits = 4)
  ) %>%
  group_by(id, name) %>%
  summarise(pop = sum(pop_intersect),
            pvr = sum(popbp_intersect)/pop,
            cpr = sum(bpu18_intersect)/sum(popu18_intersect),
            prh = sum(rohh_intersect)/sum(thh_intersect),
            rhh = sum(rohh_intersect), 
            mgr = mean(med_rentE, na.rm = TRUE),
            mpv = mean(med_valE, na.rm = TRUE),
            mhi = mean(med_incE, na.rm = TRUE),
            rb = sum(as_intersect)/100,
            pca = sum(as_popE)/pop,
            pcb = sum(bl_intersect)/pop,
            pcw = sum(wh_intersect)/pop,
            pch = sum(his_intersect)/pop) %>%
  select(id, name, pop:pch) %>%
  ms_simplify(., keep = 0.2) %>%
  .[ntep_counties, ]

plot(eviction_midd["pop"])

#eviction_high <- st_read("C:/Users/erose/CPAL Dropbox/Data Library/Dallas Independent School District/2024_2025 School Year/High_Attendance_Boundaries.geojson") %>%
eviction_high <- st_read("data/geographies/high_boundaries.geojson") %>%
 select(id = unique_id,
         name = schoolname, 
         geometry) %>%
  st_transform(crs = 4269) %>%
  st_intersection(census_tract, .) %>%
  mutate(AreaIntersect = as.numeric(st_area(.)),
         PerIntersect = AreaIntersect/AreaTract,
         pop_intersect = round(PerIntersect*tot_popE, digits = 4),
         popbp_intersect = round(PerIntersect*pop_bpE, digits = 4),
         popu18_intersect = round(PerIntersect*pop_u18E, digits = 4),
         bpu18_intersect = round(PerIntersect*bp_u18E, digits = 4),
         rohh_intersect = round(PerIntersect*rohhE, digits = 4),
         thh_intersect = round(PerIntersect*thhE, digits = 4),
         rcb_intersect = round(PerIntersect*rcbE, digits = 4),
         as_intersect = round(PerIntersect*as_popE, digits = 4),
         bl_intersect = round(PerIntersect*bl_popE, digits = 4),
         wh_intersect = round(PerIntersect*wh_popE, digits = 4),
         his_intersect = round(PerIntersect*his_popE, digits = 4)
  ) %>%
  group_by(id, name) %>%
  summarise(pop = sum(pop_intersect),
            pvr = sum(popbp_intersect)/pop,
            cpr = sum(bpu18_intersect)/sum(popu18_intersect),
            prh = sum(rohh_intersect)/sum(thh_intersect),
            rhh = sum(rohh_intersect), 
            mgr = mean(med_rentE, na.rm = TRUE),
            mpv = mean(med_valE, na.rm = TRUE),
            mhi = mean(med_incE, na.rm = TRUE),
            rb = sum(as_intersect)/100,
            pca = sum(as_popE)/pop,
            pcb = sum(bl_intersect)/pop,
            pcw = sum(wh_intersect)/pop,
            pch = sum(his_intersect)/pop) %>%
  select(id, name, pop:pch) %>%
  ms_simplify(., keep = 0.2) %>%
  .[ntep_counties, ]

plot(eviction_high["pop"])

#### Tidy Census JP Court Boundaries #####
sf_use_s2(FALSE)
dallas_jp <- st_read(paste0(libDB, "Analytics/Projects + Requests/JP Court Boundaries/Data/North Texas JP Court Boundaries.gpkg"), layer = "Dallas County JP Boundaries Rounded") %>%
  select(Name, geom) %>%
  rename(name = Name) %>%
  mutate(name = str_extract(name, "[0-9.]+"), 
         id = paste0("48113-", name),
         name = paste("Dallas County Precinct", name)) %>%
  st_transform(crs = 4269) %>%
  st_zm(.)

tarrant_jp <- st_read(paste0(libDB, "Analytics/Projects + Requests/JP Court Boundaries/Data/North Texas JP Court Boundaries.gpkg"), layer = "Tarrant County JP Boundaries Rounded") %>%
  select(JP, geom) %>%
  rename(name = JP) %>%
  mutate(id = paste0("48439-", name),
         name = paste("Tarrant County Precinct", name)) %>%
  st_transform(crs = 4269) %>%
  st_zm(.)

collin_jp <- st_read(paste0(libDB, "Analytics/Projects + Requests/JP Court Boundaries/Data/North Texas JP Court Boundaries.gpkg"), layer = "Collin County JP Boundaries Rounded") %>%
select(JPC, geom) %>%
  rename(name = JPC) %>%
  mutate(id = paste0("48085-", name),
         name = paste("Collin County Precinct", name)) %>%
  st_transform(crs = 4269) %>%
  st_zm(.)

denton_jp <- st_read(paste0(libDB, "Analytics/Projects + Requests/JP Court Boundaries/Data/North Texas JP Court Boundaries.gpkg"), layer = "Denton County JP Boundaries Rounded") %>%
  select(JP_C, geom) %>%
  rename(name = JP_C) %>%
  mutate(id = paste0("48121-", name),
         name = paste("Denton County Precinct", name)) %>%
  st_transform(crs = 4269) %>%
  st_zm(.)

eviction_jpcourt <- rbind(dallas_jp, tarrant_jp) %>%
  rbind(., denton_jp) %>%
  rbind(., collin_jp) %>%
  st_intersection(census_tract, .) %>%
  mutate(AreaIntersect = as.numeric(st_area(.)),
         PerIntersect = AreaIntersect/AreaTract,
         pop_intersect = round(PerIntersect*tot_popE, digits = 4),
         popbp_intersect = round(PerIntersect*pop_bpE, digits = 4),
         popu18_intersect = round(PerIntersect*pop_u18E, digits = 4),
         bpu18_intersect = round(PerIntersect*bp_u18E, digits = 4),
         rohh_intersect = round(PerIntersect*rohhE, digits = 4),
         thh_intersect = round(PerIntersect*thhE, digits = 4),
         rcb_intersect = round(PerIntersect*rcbE, digits = 4),
         as_intersect = round(PerIntersect*as_popE, digits = 4),
         bl_intersect = round(PerIntersect*bl_popE, digits = 4),
         wh_intersect = round(PerIntersect*wh_popE, digits = 4),
         his_intersect = round(PerIntersect*his_popE, digits = 4)
  ) %>%
  group_by(id, name) %>%
  summarise(pop = sum(pop_intersect),
            pvr = sum(popbp_intersect)/pop,
            cpr = sum(bpu18_intersect)/sum(popu18_intersect),
            prh = sum(rohh_intersect)/sum(thh_intersect),
            rhh = sum(rohh_intersect), 
            mgr = mean(med_rentE, na.rm = TRUE),
            mpv = mean(med_valE, na.rm = TRUE),
            mhi = mean(med_incE, na.rm = TRUE),
            rb = sum(as_intersect)/100,
            pca = sum(as_popE)/pop,
            pcb = sum(bl_intersect)/pop,
            pcw = sum(wh_intersect)/pop,
            pch = sum(his_intersect)/pop) %>%
  select(id, name, pop:pch) 

plot(eviction_jpcourt["pop"])

#### Export demographic data as geojson #####
st_write(eviction_elem, "demo/NTEP_demographics_elemschool.geojson", delete_dsn = TRUE)
st_write(eviction_midd, "demo/NTEP_demographics_midschool.geojson", delete_dsn = TRUE)
st_write(eviction_high, "demo/NTEP_demographics_highschool.geojson", delete_dsn = TRUE)

st_write(eviction_jpcourt, "demo/NTEP_demographics_jpcourt.geojson", delete_dsn = TRUE)
st_write(eviction_tract, "demo/NTEP_demographics_tract.geojson", delete_dsn = TRUE)
st_write(eviction_zcta, "demo/NTEP_demographics_zip.geojson", delete_dsn = TRUE)
st_write(eviction_place, "demo/NTEP_demographics_place.geojson", delete_dsn = TRUE)
st_write(eviction_county, "demo/NTEP_demographics_county.geojson", delete_dsn = TRUE)
st_write(eviction_council, "demo/NTEP_demographics_council.geojson", delete_dsn = TRUE)

#### Generate points with population data #####
bubble_elem <- eviction_elem %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_midd <- eviction_midd %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_high <- eviction_high %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_county <- eviction_county %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_place <- eviction_place %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_zcta <- eviction_zcta %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_tract <- eviction_tract %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_council <- eviction_council %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)

bubble_jpcourt <- eviction_jpcourt %>%
  select(id, name, pop, rhh) %>%
  st_point_on_surface(.)
  
#### Export population points to geojson #####
st_write(bubble_elem, "bubble/NTEP_bubble_elemschool.geojson", delete_dsn = TRUE)
st_write(bubble_midd, "bubble/NTEP_bubble_middschool.geojson", delete_dsn = TRUE)
st_write(bubble_high, "bubble/NTEP_bubble_highschool.geojson", delete_dsn = TRUE)
st_write(bubble_tract, "bubble/NTEP_bubble_tract.geojson", delete_dsn = TRUE)
st_write(bubble_zcta, "bubble/NTEP_bubble_zip.geojson", delete_dsn = TRUE)
st_write(bubble_place, "bubble/NTEP_bubble_place.geojson", delete_dsn = TRUE)
st_write(bubble_county, "bubble/NTEP_bubble_county.geojson", delete_dsn = TRUE)
st_write(bubble_council, "bubble/NTEP_bubble_council.geojson", delete_dsn = TRUE)
st_write(bubble_jpcourt, "bubble/NTEP_bubble_jpcourt.geojson", delete_dsn = TRUE)

unique(bubble_jpcourt$id)
