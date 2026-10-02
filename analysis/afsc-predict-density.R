library(sdmTMB)
library(dplyr)
library(ggplot2)
dir.create("data-generated", showWarnings = FALSE)

surveyjoin::cache_data()
surveyjoin::load_sql_data()
ak_crs  <- 3338 # Alaska Albers equal area to cover all subregions
species <- c(
  "arrowtooth flounder",
  "dover sole",
  "shortspine thornyhead",
  "pacific ocean perch"
)

for (spp in species) {
  output_file <- here::here(
    "data-generated",
    paste0("afsc-density-", gsub(" ", "-", spp), ".rds")
  )
  if (file.exists(output_file)) {
    next
  }

  # data for fitting:
  dat <- surveyjoin::get_data(spp, regions = "afsc") |>
    mutate(year = lubridate::year(lubridate::ymd(date))) |> 
    select(survey_name, year, lon_start, lat_start, depth_m, effort, catch_weight, common_name)
  dat <- add_utm_columns(dat, c("lon_start", "lat_start"), utm_crs = ak_crs) |> 
    filter(!is.na(catch_weight), !is.na(effort), year %in% 2003:2023)
  table(dat$survey_name, dat$year)

    # species-specific data extent:
    if (spp == "arrowtooth flounder") {
      dat <- filter(dat, survey_name %in% c("eastern Bering Sea", 
                                            "Gulf of Alaska",                                                    
                                            "Aleutian Islands"))
    } else if (spp == "dover sole") {
      dat <- filter(dat, survey_name == "Gulf of Alaska")
    } else if (spp == "shortspine thornyhead") {
      dat <- filter(dat, survey_name %in% c("Gulf of Alaska",                                                    
                                            "Aleutian Islands"))
    } else if (spp == "pacific ocean perch") {
      dat <- filter(dat, survey_name %in% c("Gulf of Alaska",                                                    
                                            "Aleutian Islands"))
    }
  
  # species-specific prediction grid:
  grid <- surveyjoin::afsc_grid
  
  if (spp == "arrowtooth flounder") {
    grid <- filter(grid, survey %in% c("Eastern Bering Sea Crab/Groundfish Bottom Trawl Survey", 
                                          "Gulf of Alaska Bottom Trawl Survey",                                                    
                                          "Aleutian Islands Bottom Trawl Survey"))
  } else if (spp == "dover sole") {
    grid <- filter(grid, survey == "Gulf of Alaska Bottom Trawl Survey")
  } else if (spp == "shortspine thornyhead") {
    grid <- filter(grid, survey %in% c("Gulf of Alaska Bottom Trawl Survey",                                                    
                                          "Aleutian Islands Bottom Trawl Survey"))
  } else if (spp == "pacific ocean perch") {
    grid <- filter(grid, survey %in% c("Gulf of Alaska Bottom Trawl Survey",                                                    
                                          "Aleutian Islands Bottom Trawl Survey"))
  }
  
  grid <- sdmTMB::replicate_df(grid, "year", unique(dat$year))
  grid <- add_utm_columns(grid, c("lon", "lat"), utm_crs = ak_crs)

  # now fit (Q: do we need extent-specific cutoffs by species?):
  mesh <- make_mesh(dat, c("X", "Y"), cutoff = 50) # 190-390 knots across species
  mesh$mesh$n
  
  fit <- sdmTMB(
    catch_weight ~ 0,
    data = dat,
    family = delta_gengamma(type = "poisson-link"),
    offset = log(dat$effort),
    mesh = mesh,
    time = "year",
    time_varying = ~ 1,
    time_varying_type = "rw",
    extra_time = 2020L,
    priors = sdmTMBpriors(sigma_V = gamma_cv(0.3, 0.5)),
    spatiotemporal = "rw",
    spatial = "on",
    silent = FALSE
  )
  stopifnot(sanity(fit)$all_ok)

  # predict:
  pred <- predict(fit, newdata = grid, offset = rep(0, nrow(grid)))
  pred <- mutate(pred, biomass_density = round(exp(est1 + est2), 5L)) # save a bit of space
  pred_simple <- select(pred, year, lon, lat, biomass_density)

  saveRDS(pred_simple, output_file, compress = "xz")
}
