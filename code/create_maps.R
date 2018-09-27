# Initialization
## set default options
options(stringsAsFactors = FALSE, download.file.method = "curl")

## load functions
source("code/extract_locations_from_ebird_records.R")

## verify that Google API key is present
### set slash symbol for printing
slash_symbol <- "/"
if (.Platform$OS.type == "windows")
  slash_symbol <- "\\"

## #check that API settings configured for Google
if (identical(Sys.getenv("GOOGLE_TOKEN"), "")) {
  stop(paste0("'", Sys.getenv("HOME"), slash_symbol, ".Renviron' does not ",
              "contain the credentials for Google (i.e. GOOGLE_TOKEN ",
              "variable)"))
}

## create temporary directories
tmp1 <- file.path(tempdir(), basename(tempfile(fileext = "")))
tmp2 <- file.path(tempdir(), basename(tempfile(fileext = "")))

## set variables
grid_path <- dir("data/grid", "^.*\\.shp$", full.names = TRUE)[1]
unzip(dir("data/land", "^.*\\.zip$", full.names = TRUE),
          exdir = tmp1)
land_path <- dir(tmp1, "^.*\\.shp$", full.names = TRUE)[1]
unzip(dir("data/records", "^.*\\.zip$", full.names = TRUE), exdir = tmp2)
record_path <- dir(tmp2, "^.*\\.txt$", full.names = TRUE)

## load packages
library(dplyr)
library(sf)

# Preliminary processing
## load parameters
parameters <- yaml::read_yaml("data/parameters/parameters.yml")

## load data
grid_data <- sf::read_sf(grid_path)
land_data <- sf::st_transform(sf::read_sf(land_path), sf::st_crs(grid_data))
record_data <- data.table::fread(record_path, data.table = FALSE)

## format record data to extract locations
locations_data <- do.call(extract_locations_from_ebird_records,
                          append(list(x = record_data),
                                 parameters$records)) %>%
                  sf::st_transform(sf::st_crs(grid_data))
rm(record_data)

## find resolution of grid (assumes square grid cells)
grid_resolution <- sqrt(as.numeric(sf::st_area(grid_data[1, ])))

## format land data
bbox_data <- sf::st_as_sfc(sf::st_bbox(sf::st_buffer(grid_data, 200000)))
land_data <- land_data[as.matrix(sf::st_intersects(land_data,
                                                   bbox_data))[, 1], ]

## format land data
land_data <- land_data %>%
             lwgeom::st_make_valid() %>%
             lwgeom::st_snap_to_grid(1) %>%
             sf::st_simplify(100) %>%
             {suppressWarnings(sf::st_collection_extract(.,
                                                         type = "POLYGON"))} %>%
             lwgeom::st_make_valid() %>%
             {suppressWarnings(sf::st_intersection(., bbox_data))} %>%
             {suppressWarnings(sf::st_collection_extract(.,
                                                         type = "POLYGON"))} %>%
             lwgeom::st_make_valid() %>%
             sf::st_union()
land_data <- sf::st_sf(name = "Land", geometry = land_data)

## subset grid cells to include only those on land
grid_data <- grid_data %>%
             filter(c(as.matrix(sf::st_intersects(grid_data, land_data))))

## create wgs1984 version of the data
grid_wgs1984_data <- sf::st_transform(grid_data, 4326)
locations_wgs1984_data <- sf::st_transform(locations_data, 4326)

## create centroids for the grid data
grid_centroid_data <- sf::st_centroid(grid_data)
grid_wgs1984_centroid_data <- sf::st_transform(grid_centroid_data, 4326)

# Main processing
## setup cluster
is_parallel <- isTRUE(parameters$threads > 1)
if (is_parallel) {
  cl <- parallel::makeCluster(parameters$threads, type = "PSOCK")
  parallel::clusterEvalQ(cl, {library(dplyr); library(sf)})
  parallel::clusterExport(cl, envir = environment(),
                           c("grid_data", "parameters", "grid_wgs1984_data"))
  doParallel::registerDoParallel(cl)
}

## create maps
result <- plyr::llply(seq_len(nrow(grid_data)), .parallel = is_parallel,
                      function(i) {
  ### find extent of grid_cell
  curr_extent <- raster::extent(as(grid_wgs1984_data[i, ], "Spatial"))
  curr_xlim <- c(curr_extent@xmin, curr_extent@xmax)
  curr_xlim <- curr_xlim + (c(-1, 1) * 0.1 * abs(diff(curr_xlim)))
  curr_ylim <- c(curr_extent@ymin, curr_extent@ymax)
  curr_ylim <- curr_ylim + (c(-1, 1) * 0.1 * abs(diff(curr_ylim)))
  ### calculate centroid of grid cell
  curr_centroid <- c(as(grid_centroid_data[i, ], "Spatial")@coords)
  curr_wgs1984_centroid <- c(as(grid_wgs1984_centroid_data[i, ],
                                "Spatial")@coords)
  ### find neighboring grid cells
  curr_distances <- as.numeric(c(sf::st_distance(grid_centroid_data[i, ],
                                                 grid_centroid_data)))
  neighboring_indices <- which(curr_distances < (grid_resolution * 1.1))
  ### prepare polygons for plotting
  pl <- grid_wgs1984_data[c(neighboring_indices), ] %>%
        as("Spatial") %>%
        {suppressMessages(ggplot2::fortify(.))} %>%
        dplyr::rename(x = long, y = lat)
  ### prepare text for plotting
  l <- locations_wgs1984_data %>%
       filter(rowSums(as.matrix(sf::st_intersects(
         locations_data, grid_data[neighboring_indices, ]))) > 0) %>%
       as("Spatial") %>%
       as.data.frame() %>%
       dplyr::rename(x = coords.x1, y = coords.x2)
  ### download background of grid cell
  bg <- ggmap::get_googlemap(center = curr_wgs1984_centroid,
                             zoom = parameters$maps$google_zoom_level,
                             maptype = parameters$maps$google_map_type,
                             scale = 2,
                             messaging = FALSE,
                             urlonly = FALSE,
                             force = TRUE,
                             filename = tempfile(fileext = ".png"),
                             language = "en-EN",
                             color = "color",
                             size = c(640, 640),
                             key = Sys.getenv("GOOGLE_TOKEN"))
  ### create map
  p <- ggmap::ggmap(bg, extent = "normal", maprange = FALSE) +
       ggplot2::geom_polygon(ggplot2::aes(x = x, y = y, group = id),
                             data = pl, color = "red", fill = NA) +
       ggrepel::geom_text_repel(ggplot2::aes(x = x, y = y, label = text),
                                data = l, color = "white",
                                 seed = 500, force = 100) +
       ggplot2::coord_cartesian(xlim = curr_xlim, ylim = curr_ylim) +
       ggmap::theme_nothing()
  #### save map
  ggplot2::ggsave(paste0("exports/grid-", grid_data$id[i], ".png"), p,
                  width = parameters$maps$width,
                  height = parameters$maps$height,
                  units = "in")
  #### return success
  TRUE
})
