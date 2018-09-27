# Initialization
## set default options
options(stringsAsFactors = FALSE)

## set slash symbol for printing
slash_symbol <- "/"
if (.Platform$OS.type == "windows")
  slash_symbol <- "\\"

## check that API settings configured for GitHub
if (identical(Sys.getenv("GITHUB_TOKEN"), "") &
    !identical(Sys.getenv("GITHUB_PAT"), ""))
  Sys.setenv("GITHUB_TOKEN" = Sys.getenv("GITHUB_PAT"))

if (identical(Sys.getenv("GITHUB_TOKEN"), "")) {
  stop(paste0("'", Sys.getenv("HOME"), slash_symbol, ".Renviron' does not ",
              "contain the credentials fir GitHub (i.e. GITHUB_TOKEN ",
              "variable)"))
}

# Main processing
## push zip files
piggyback::pb_upload("maps.zip",
                     repo =  "bird-team/sampling-grid-maps",
                     name = "maps.zip",
                     overwrite = TRUE,
                     tag = "v0.0.1")
