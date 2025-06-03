Sys.setenv(TZ = "America/Chicago")

source('scripts/R/environment.R')
source('scripts/R/configuration.R')

Sys.setenv(R_CONFIG_FILE = 'config.yml')
config <- load_configuration()
print(str_glue('[{env}] Configuration loaded', env = env()))

dpath <- function (path = '') {
  return(str_glue("{root}/{path}", root = config$data$root))
}
print(str_glue('Data root: {root}', root = dpath()))

source('scripts/R/data.R')
