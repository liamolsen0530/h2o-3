setwd(normalizePath(dirname(R.utils::commandArgs(asValues=TRUE)$"f")))
source('../h2o-runit.R')

test.upload.import <- function(conn) {
    uploaded_frame <- h2o.uploadFile(conn, locate("bigdata/laptop/mnist/train.csv.gz"))
    imported_frame <- h2o.importFile(conn, locate("bigdata/laptop/mnist/train.csv.gz"))

    rows_u <- nrow(uploaded_frame)
    rows_i <- nrow(imported_frame)
    cols_u <- ncol(uploaded_frame)
    cols_i <- ncol(imported_frame)

    print(paste0("rows upload: ", rows_u, ", rows import: ", rows_i))
    print(paste0("cols upload: ", cols_u, ", cols import: ", cols_i))
    expect_equal(rows_u, rows_i, info="Expected same number of rows regardless of method.")
    expect_equal(cols_u, cols_i, info="Expected same number of cols regardless of method.")

    testEnd()
}

doTest("Test upload import", test.upload.import)