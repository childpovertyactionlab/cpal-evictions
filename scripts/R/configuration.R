load_configuration <- function () {
  tryCatch({
    config <- config::get(use_parent = FALSE)
    if (is.null(config$data$root)) {
      stop("'data.root' not configured")
    }
  }, error = function(e) {
    print(paste('R_CONFIG_FILE=', Sys.getenv('R_CONFIG_FILE', './config.yml')))
    stop('Error: ', e$message)
  })
  return(config)
}
