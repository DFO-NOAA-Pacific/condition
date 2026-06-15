import copernicusmarine
import xarray as xr
import os

START_DATE = "2003-01-01T00:00:00"
END_DATE = "2023-12-31T23:59:59"

regions = {
    "nwfsc": {"min_lon": -126.25, "max_lon": -117.1, "min_lat": 31.5, "max_lat": 48.5, "min_depth": 47.37, "max_depth": 1452.25},
    "pbs":  {"min_lon": -134.1,  "max_lon": -124.3, "min_lat": 48.1, "max_lat": 54.8, "min_depth":11.4, "max_depth": 1452.25},
    "afsc": {"min_lon": -179.99,   "max_lon": -131,  "min_lat": 51, "max_lat": 65.35, "min_depth":7.93, "max_depth": 1245.29},
}

# Download data
for region_name, bounds in regions.items():
    print(f"Downloading {region_name}...")
    
    copernicusmarine.subset(
        dataset_id="cmems_mod_glo_phy_my_0.083deg_P1M-m",
        variables=["so", "thetao"],
        minimum_longitude=bounds["min_lon"],
        maximum_longitude=bounds["max_lon"],
        minimum_latitude=bounds["min_lat"],
        maximum_latitude=bounds["max_lat"],
        start_datetime=START_DATE,
        end_datetime=END_DATE,
        minimum_depth=bounds["min_depth"],
        maximum_depth=bounds["max_depth"],
        output_filename=f"product1_{region_name}.nc",
        overwrite=True
    )

    copernicusmarine.subset(
        dataset_id="cmems_mod_glo_bgc_my_0.25deg_P1M-m",
        variables=["o2", "phyc", "nppv"],
        minimum_longitude=bounds["min_lon"],
        maximum_longitude=bounds["max_lon"],
        minimum_latitude=bounds["min_lat"],
        maximum_latitude=bounds["max_lat"],
        start_datetime=START_DATE,
        end_datetime=END_DATE,
        minimum_depth= bounds["min_depth"],
        maximum_depth= bounds["max_depth"],
        output_filename=f"product2_{region_name}.nc",
        overwrite=True
    )

    # Open netcdfs into memory
    d1 = xr.open_dataset(f"./product1_{region_name}.nc")
    d2 = xr.open_dataset(f"./product2_{region_name}.nc")
    
    # Interpolate (0.25 --> 0.083), merge, save
    d2_aligned = d2.interp_like(d1, method="linear")
    combined = xr.merge([d1, d2_aligned])
    combined.to_netcdf(f"./glorys_{region_name}.nc")

    # Housekeeping
    d1.close()
    d2.close()
    os.remove(f"./product1_{region_name}.nc")
    os.remove(f"./product2_{region_name}.nc")
    print(f"Done {region_name}")

print("All regions complete.")