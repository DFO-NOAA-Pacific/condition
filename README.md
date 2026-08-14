# condition
This project investigates body condition in select groundfish of the northeast Pacific ocean (arrowtooth flounder, dover sole, Pacific Ocean perch, Pacific spiny dogfish, shortspine thornyhead).
These are species that have wide latitudinal ranges, and so we have combined regional data from numerous fisheries-independent bottom trawl surveys to better understand variation in condition.

# Repository anatomy
The data-raw folder contains files for getting data, running analyses, and visualizing results. 
Plots are saved in condition/figures.

### Reproducibility:
1. Get trawl data. Run trawls/get_trawls.qmd.
2. Get GLORYS environmental data in data-raw/glorys. Run login.py and download_data.py to produce netcdf files. They are large. 
3. Get biological data and combine with environmental data + trawls for each region. Run get_env_afsc/pbs/nwfsc.qmd. This takes awhile.
4. Join regional data sets with join_regions.qmd. This produces the main data set fish_all.rds. 
5. Run and compare body condition models in modeling.qmd. Models may be saved in data-raw/models.
6. Generate indices in get_indices.qmd. This uses data from the data-raw/biomass_predictions subfolder. Plots are saved in condition/figures.
7. Make further data visualizations in make_figures.qmd. Plots are saved in condition/figures.