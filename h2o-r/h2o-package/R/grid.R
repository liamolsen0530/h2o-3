#' Launch grid search with given parameters.
#' @examples
#' library(h2o) 
#' localH2O <- h2o.init()
#' iris.hex <- as.h2o(iris)
#' grid <- h2o.grid("gbm", x=c(1:4), y = 5, training_frame=hex, hyper_params=list("_ntrees"=c(1,10,30)))
#' @export
h2o.grid <- function(algorithm,
                     ...,
                     hyper_params = list(),
                     conn = h2o.getConnection())
{
  # Extract parameters
  dots <- list(...)
  params <- .h2o.prepareModelParameters(algo = algorithm, params = dots)
  # FIXME: rename x to ignore, y to response

  # Validation of model parameters
  .key.validate(params$key_value)
  # Get model builder parameters for this model
  allParams <- .h2o.getModelParameters(algo = algorithm)
  # Verify the parameters
  params <- lapply(params, function(x) { if(is.integer(x)) x <- as.numeric(x); x })
  params <- .h2o.checkModelParameters(algo = algorithm, allParams = allParams, params = params)
  # TODO: Validate hyper parameters

  # Append grid parameters
  params$grid_parameters <- toJSON(hyper_params)
  # Trigger grid search job
  res <- .h2o.__remoteSend(conn, .h2o.__GRID(algorithm), h2oRestApiVersion = 99, .params = params, method = "POST")
  job_key <- res$job$key$name
  # Wait for grid job to finish
  .h2o.__waitOnJob(conn, job_key)
}

