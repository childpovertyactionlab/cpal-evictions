env <- function () { return(Sys.getenv('ENV', 'development')) }
env_prod <- function() { return(env() == 'production') }
env_dev <- function() { return(env() == 'development') }
