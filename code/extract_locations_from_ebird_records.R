#' Extract sampling location data from eBird record data
#'
#' This function extracts eBird sampling locality data from eBird record data.
#'
#' @param x \code{data.frame} containing eBird records.
#'
#' @param id_column_name \code{character} name of the column in the
#'   argument to \code{x} containing the unique identifier of the locality.
#'
#' @param name_column_name \code{character} name of the column in the
#'   argument to \code{x} containing the name of the locality.
#'
#' @param type_column_name \code{character} name of the column in the
#'   argument to \code{x} containing the type of the locality.
#'
#' @param longitude_column_name \code{character} name of the column in the
#'   argument to \code{x} containing the longitude data for each record.
#'
#' @param latitude_column_name \code{character} name of the column in the
#'   argument to \code{x} containing the latitude data for each record.
#'
#'
#' @return \code{\link[sf]{sf}} object.
extract_locations_from_ebird_records <- function(x, id_column_name,
                                                 name_column_name,
                                                 type_column_name,
                                                 longitude_column_name,
                                                 latitude_column_name) {
  # rename columns
  data.table::setnames(x, c(id_column_name, name_column_name, type_column_name,
    longitude_column_name, latitude_column_name),
    c("id", "name", "type", "longitude", "latitude"))

  # process data
  x <- x %>%
       dplyr::select(id, name, type, longitude, latitude) %>%
       dplyr::filter(!duplicated(id)) %>%
       dplyr::filter(!is.na(longitude), !is.na(latitude), !is.na(type),
                     !is.na(id), !is.na(name)) %>%
       dplyr::filter(nchar(name) > 0)

  # add in column with formatted text
  # this is provided in case this needs to change in the future
  x$text <- x$name

  # convert data.frame to sf
  x <- sf::st_as_sf(x, coords = c("longitude", "latitude"), crs = 4326,
                   agr = "constant")

  # return object
  x
}
