##`'
##`' Data Import
##`'
##`' Importing data is a _lazy_ parse of the data. It adds an extra step so that a user may specify a variety of options
##`' including a header file, separator type, and in the future column type. Additionally, the import phase provides
##`' feedback on whether or not a folder or group of files may be imported together.

#'
#' Import Files into H2O
#'
#' Imports files into an H2O cloud. The default behavior is to pass-through to the parse phase
#' automatically.
#'
#' Other than \code{h2o.uploadFile}, if the given path is relative, then it will be relative to the
#' start location of the H2O instance. Additionally, the file must be on the same machine as the H2O
#' cloud. In the case of \code{h2o.uploadFile}, a relative path will resolve relative to the working
#' directory of the current R session.
#'
#' Import an entire directory of files. If the given path is relative, then it
#' will be relative to the start location of the H2O instance. The default
#' behavior is to pass-through to the parse phase automatically.
#'
#' \code{h2o.importURL} and \code{h2o.importHDFS} are both deprecated functions. Instead, use
#' \code{h2o.importFile}
#'
#' @param path The complete URL or normalized file path of the file to be
#'        imported. Each row of data appears as one line of the file.
#' @param conn an \linkS4class{H2OConnection} class object.
#' @param pattern (Optional) Character string containing a regular expression to match file(s) in
#'        the folder.
#' @param destination_frame (Optional) The unique hex key assigned to the imported file. If
#'        none is given, a key will automatically be generated based on the URL
#'        path.
#' @param parse (Optional) A logical value indicating whether the file should be
#'        parsed after import.
#' @param header (Optional) A logical value indicating whether the first line of
#'        the file contains column headers. If left empty, the parser will try
#'        to automatically detect this.
#' @param sep (Optional) The field separator character. Values on each line of
#'        the file are separated by this character. If \code{sep = ""}, the
#'        parser will automatically detect the separator.
#' @param col.names (Optional) A \linkS4class{H2ORawData} or
#'        \linkS4class{H2OFrame} (\code{version = 2}) object containing a single
#'        delimited line with the column names for the file.
#' @param col.types (Optional) A vector to specify whether columns should be
#'        forced to a certain type upon import parsing.
#' @param na.strings (Optional) H2O will interpret these strings as missing.
#' @param parse_type (Optional) Specify which parser type H2O will use.
#'        Valid types are "ARFF", "XLS", "CSV", "SVMLight"
#' @param progressBar (Optional) When FALSE, tell H2O parse call to block
#'        synchronously instead of polling.  This can be faster for small
#'        datasets but loses the progress bar.
#' @examples
#' localH2O = h2o.init(ip = "localhost", port = 54321, startH2O = TRUE)
#' prosPath = system.file("extdata", "prostate.csv", package = "h2o")
#' prostate.hex = h2o.uploadFile(localH2O, path = prosPath, destination_frame = "prostate.hex")
#' class(prostate.hex)
#' summary(prostate.hex)
#' @name h2o.importFile
#' @export
h2o.importFolder <- function(path, conn = h2o.getConnection(), pattern = "",
                             destination_frame = "", parse = TRUE, header = NA, sep = "",
                             col.names = NULL, na.strings=NULL, parse_type=NULL) {
  if (is(path, "H2OConnection")) {
    temp <- path
    path <- conn
    conn <- temp
  }
  if(!is(conn, "H2OConnection")) stop("`conn` must be of class H2OConnection")
  if(!is.character(path) || is.na(path) || !nzchar(path))
    stop("`path` must be a non-empty character string")
  if(!is.character(pattern) || length(pattern) != 1L || is.na(pattern)) stop("`pattern` must be a character string")
  .key.validate(destination_frame)
  if(!is.logical(parse) || length(parse) != 1L || is.na(parse))
    stop("`parse` must be TRUE or FALSE")

  if(length(path) > 1L) {
    destFrames <- c()
    fails <- c()
    for(path2 in path){
      res <-.h2o.__remoteSend(conn, .h2o.__IMPORT, path=path2)
      destFrames <- c(destFrames, res$destination_frames)
      fails <- c(fails, res$fails)
    }
    res$destination_frames <- destFrames
    res$fails <- fails
  } else {
    res <- .h2o.__remoteSend(conn, .h2o.__IMPORT, path=path)
  }

  if(length(res$fails) > 0L) {
    for(i in seq_len(length(res$fails)))
      cat(res$fails[[i]], "failed to import")
  }
  # Return only the files that successfully imported
  if(length(res$files) > 0L) {
    if(parse) {
      srcKey <- res$destination_frames
      rawData <- .newH2ORawData("H2ORawData", conn=conn, frame_id=srcKey, linkToGC=FALSE)  # do not gc, H2O handles these nfs:// vecs
      ret <- h2o.parseRaw(data=rawData, destination_frame=destination_frame, header=header, sep=sep, col.names=col.names, na.strings=na.strings, parse_type=parse_type)
    } else {
      myData <- lapply(res$destination_frames, function(x) .newH2ORawData("H2ORawData", conn=conn, frame_id=x, linkToGC=FALSE))  # do not gc, H2O handles these nfs:// vecs
      if(length(res$destination_frames) == 1L)
        ret <- myData[[1L]]
      else
        ret <- myData
    }
  } else stop("all files failed to import")
  ret
}


#' @export
h2o.importFile <- function(path, conn = h2o.getConnection(), destination_frame = "", parse = TRUE, header=NA, sep = "", col.names=NULL, na.strings=NULL) {
  h2o.importFolder(path, conn, pattern = "", destination_frame, parse, header, sep, col.names, na.strings=na.strings, parse_type=NULL)
}


#' @rdname h2o.importFile
#' @export
h2o.importURL <- function(path, conn = h2o.getConnection(), destination_frame = "", parse = TRUE, header = NA, sep = "", col.names = NULL, na.strings=NULL, parse_type=NULL) {
  .Deprecated("h2o.importFolder")
  h2o.importFile(path, conn, destination_frame, parse, header, sep, col.names, na.strings=na.strings)
}


#' @rdname h2o.importFile
#' @export
h2o.importHDFS <- function(path, conn = h2o.getConnection(), pattern = "", destination_frame = "", parse = TRUE, header = NA, sep = "", col.names = NULL, na.strings=NULL, parse_type=NULL) {
  .Deprecated("h2o.importFolder")
  h2o.importFolder(path, conn, pattern, destination_frame, parse, header, sep, col.names, na.strings=na.strings)
}


#' @rdname h2o.importFile
#' @export
h2o.uploadFile <- function(path, conn = h2o.getConnection(), destination_frame = "",
                           parse = TRUE, header = NA, sep = "", col.names = NULL,
                           col.types = NULL, na.strings = NULL, progressBar = FALSE, parse_type = NULL) {
  if (is(path, "H2OConnection")) {
    temp <- path
    path <- conn
    conn <- temp
  }
  if(!is(conn, "H2OConnection")) stop("`conn` must be of class H2OConnection")
  if(!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path))
    stop("`path` must be a non-empty character string")
  .key.validate(destination_frame)
  if(!is.logical(parse) || length(parse) != 1L || is.na(parse))
    stop("`parse` must be TRUE or FALSE")
  if(!is.logical(progressBar) || length(progressBar) != 1L || is.na(progressBar))
    stop("`progressBar` must be TRUE or FALSE")

  path <- normalizePath(path, winslash = "/")
  srcKey <- .key.make(conn, path)
  urlSuffix <- sprintf("PostFile?destination_frame=%s",  curlEscape(srcKey))
  fileUploadInfo <- fileUpload(path)
  .h2o.doSafePOST(conn = conn, h2oRestApiVersion = .h2o.__REST_API_VERSION, urlSuffix = urlSuffix,
                  fileUploadInfo = fileUploadInfo)

  rawData <- .newH2ORawData("H2ORawData", conn=conn, frame_id=srcKey, linkToGC=FALSE)
  if (parse) {
    h2o.parseRaw(data=rawData, destination_frame=destination_frame, header=header, sep=sep, col.names=col.names, col.types=col.types, na.strings=na.strings, blocking=!progressBar, parse_type = parse_type)
  } else {
    rawData
  }
}

#'
#' Load H2O Model from HDFS or Local Disk
#'
#' Load a saved H2O model from disk.
#'
#' @param path The path of the H2O Model to be imported. For example, if the `dir` argument in h2o.saveModel was set to
#'        "/Users/UserName/Desktop" then the `path` argument in h2o.loadModel should be set to something like
#'        "/Users/UserName/Desktop/K-meansModel__a7cebf318ca5827185e209edf47c4052"
#' @param conn an \linkS4class{H2OConnection} object containing the IP address
#'        and port of the server running H2O.
#' @return Returns a \linkS4class{H2OModel} object of the class corresponding to the type of model
#'         built.
#' @seealso \code{\link{h2o.saveModel}, \linkS4class{H2OModel}}
#' @examples
#' \dontrun{
#' # library(h2o)
#' # localH2O = h2o.init()
#' # prosPath = system.file("extdata", "prostate.csv", package = "h2o")
#' # prostate.hex = h2o.importFile(localH2O, path = prosPath, destination_frame = "prostate.hex")
#' # prostate.glm = h2o.glm(y = "CAPSULE", x = c("AGE","RACE","PSA","DCAPS"),
#' #   training_frame = prostate.hex, family = "binomial", alpha = 0.5)
#' # glmmodel.path = h2o.saveModel(prostate.glm, dir = "/Users/UserName/Desktop")
#' # glmmodel.load = h2o.loadModel(localH2O, glmmodel.path)
#' }
#' @export
h2o.loadModel <- function(path, conn = h2o.getConnection()) {
  if (is(path, "H2OConnection")) {
    temp <- path
    path <- conn
    conn <- temp
  }
  if(!is(conn, 'H2OConnection')) stop('`conn` must be of class H2OConnection')
  if(!is.character(path) || length(path) != 1L || is.na(path) || !nzchar(path))
    stop("`path` must be a non-empty character string")

  res <- .h2o.__remoteSend(conn, .h2o.__LOAD_MODEL, h2oRestApiVersion = 99, dir = path, method = "POST")$models[[1L]]
  res
  h2o.getModel(res$model_id$name, conn)
}
