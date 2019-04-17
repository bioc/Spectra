test_that("initializeBackend,MsBackendMzR works", {
    fl <- dir(system.file("sciex", package = "msdata"), full.names = TRUE)
    expect_error(backendInitialize(MsBackendMzR()), "Parameter 'files'")
    expect_error(backendInitialize(MsBackendMzR(), files = c(fl, fl)),
                 "Duplicated")
    be <- backendInitialize(MsBackendMzR(), files = fl)
    expect_true(is(be, "MsBackendMzR"))
    expect_equal(be@files, fl)
    expect_equal(be@modCount, c(0L, 0L))
    expect_equal(nrow(be@spectraData), 1862)
    expect_equal(be@spectraData$scanIndex, c(1:931, 1:931))
    expect_equal(be@spectraData$fromFile, rep(1:2, each = 931))
    expect_true(isReadOnly(be))
})