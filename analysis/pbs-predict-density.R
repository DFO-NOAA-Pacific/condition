library(sdmTMB)
library(dplyr)
library(ggplot2)
dir.create("data-generated", showWarnings = FALSE)

surveyjoin::cache_data()
surveyjoin::load_sql_data()
utm_bc  <- 3156
species <- c(
  "arrowtooth flounder",
  "dover sole",
  "shortspine thornyhead",
  "pacific ocean perch",
  "pacific spiny dogfish"
)

for (spp in species) {
  output_file <- here::here(
    "data-generated",
    paste0("pbs-density-", gsub(" ", "-", spp), ".rds")
  )
  if (file.exists(output_file)) {
    next
  }

  # data for fitting:
  dat <- surveyjoin::get_data(spp, regions = "pbs") |>
    mutate(year = lubridate::year(lubridate::ymd(date))) |> 
    select(survey_name, year, lon_start, lat_start, depth_m, effort, catch_weight, common_name)
  dat <- add_utm_columns(dat, c("lon_start", "lat_start"), utm_crs = utm_bc) |> 
    filter(!is.na(catch_weight), !is.na(effort))
  table(dat$survey_name, dat$year)

  # prediction grid:
  grid <- surveyjoin::dfo_synoptic_grid |>
    sdmTMB::replicate_df("year", unique(dat$year))
  grid <- add_utm_columns(grid, c("lon", "lat"), utm_crs = utm_bc)

  # now fit:
  mesh <- make_mesh(dat, c("X", "Y"), cutoff = 15)
  fit <- sdmTMB(
    catch_weight ~ 0,
    data = dat,
    family = delta_gengamma(type = "poisson-link"),
    offset = log(dat$effort),
    mesh = mesh,
    time = "year",
    time_varying = ~ 1,
    time_varying_type = "rw",
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
