#' @include hidden_aliases.R
NULL

.valid_ms_backend_files_from_file <- function(x, y) {
    if (length(x) && !length(y))
        return("'fromFile' can not be empty if 'files' are defined.")
    if (length(y) && !length(x))
        return("'files' can not be empty if 'fromFile' is defined.")
    if (length(x) && !all(y %in% seq_along(x)))
        return("Index in 'fromFile' outside of the number of files")
    else NULL
}

#' @description
#'
#' Check if spectraData has all required columns.
#'
#' @noRd
#'
#' @param x spectraData `DataFrame`
.valid_spectra_data_required_columns <- function(x, columns = c("dataStorage")) {
    if (nrow(x)) {
        missing_cn <- setdiff(columns, colnames(x))
        if (length(missing_cn))
            return(paste0("Required column(s): ",
                          paste(missing_cn, collapse = ", "),
                          " is/are missing"))
    }
    NULL
}

#' Function to check data types of selected columns in the provided `DataFrame`.
#'
#' @param x `DataFrame` to validate.
#'
#' @param datatypes named `character`, names being column names and elements
#'     expected data types.
#'
#' @author Johannes Rainer
#'
#' @noRd
.valid_column_datatype <- function(x, datatypes = .SPECTRA_DATA_COLUMNS) {
    datatypes <- datatypes[names(datatypes) %in% colnames(x)]
    res <- mapply(FUN = .is_class, x[, names(datatypes), drop = FALSE],
                  datatypes)
    if (!all(res))
        paste0("The following columns have a wrong data type: ",
               paste(names(res[!res]), collapse = ", "),
               ". The expected data type(s) is/are: ",
               paste(datatypes[names(res)[!res]], collapse = ", "), ".")
    else NULL
}

.valid_mz_column <- function(x) {
    if (length(x$mz)) {
        if (!all(vapply(x$mz, is.numeric, logical(1))))
            return("mz column should contain a list of numeric")
        if (any(vapply(x$mz, is.unsorted, logical(1))))
            return("mz values have to be sorted increasingly")
    }
    NULL
}

.valid_intensity_column <- function(x) {
    if (length(x$intensity))
        if (!all(vapply(x$intensity, is.numeric, logical(1))))
            return("intensity column should contain a list of numeric")
    NULL
}

.valid_intensity_mz_columns <- function(x) {
    ## Don't want to have that tested on all on-disk objects.
    if (length(x$intensity) && length(x$mz))
        if (any(lengths(x$mz) != lengths(x$intensity)))
            return("Length of mz and intensity values differ for some spectra")
    NULL
}

#' data types of spectraData columns
#'
#' @noRd
.SPECTRA_DATA_COLUMNS <- c(
    msLevel = "integer",
    rtime = "numeric",
    acquisitionNum = "integer",
    scanIndex = "integer",
    mz = "NumericList",
    intensity = "NumericList",
    dataStorage = "character",
    dataOrigin = "character",
    centroided = "logical",
    smoothed = "logical",
    polarity = "integer",
    precScanNum = "integer",
    precursorMz = "numeric",
    precursorIntensity = "numeric",
    precursorCharge = "integer",
    collisionEnergy = "numeric",
    isolationWindowLowerMz = "numeric",
    isolationWindowTargetMz = "numeric",
    isolationWindowUpperMz = "numeric"
)

#' accessor methods for spectraData columns.
#'
#' @noRd
.SPECTRA_DATA_COLUMN_METHODS <- c(
    msLevel = "msLevel",
    rtime = "rtime",
    acquisitionNum = "acquisitionNum",
    scanIndex = "scanIndex",
    mz = "mz",
    intensity = "intensity",
    dataStorage = "dataStorage",
    dataOrigin = "dataOrigin",
    centroided = "centroided",
    smoothed = "smoothed",
    polarity = "polarity",
    precScanNum = "precScanNum",
    precursorMz = "precursorMz",
    precursorIntensity = "precursorIntensity",
    precursorCharge = "precursorCharge",
    collisionEnergy = "collisionEnergy",
    isolationWindowLowerMz = "isolationWindowLowerMz",
    isolationWindowTargetMz = "isolationWindowTargetMz",
    isolationWindowUpperMz = "isolationWindowUpperMz"
)

#' @rdname MsBackend
#'
#' @export MsBackendDataFrame
MsBackendDataFrame <- function() {
    new("MsBackendDataFrame")
}

#' Helper function to extract a certain column from the spectraData data frame.
#' If the data frame has no such column it will use the accessor method to
#' retrieve the corresponding data.
#'
#' @param x object with a `@spectraData` slot containing a `DataFrame`.
#'
#' @param column `character(1)` with the column name.
#'
#' @author Johannes Rainer
#'
#' @noRd
.get_spectra_data_column <- function(x, column) {
    if (missing(column) || length(column) != 1)
        stop("'column' should be a 'character' of length 1.")
    if (any(colnames(x@spectraData) == column))
        x@spectraData[[column]]
    else {
        if (any(names(.SPECTRA_DATA_COLUMN_METHODS) == column))
            do.call(.SPECTRA_DATA_COLUMN_METHODS[column], args = list(x))
        else stop("No column '", column, "' available")
    }
}

#' Utility function to convert columns in the `x` `DataFrame` that have only
#' a single element to `Rle`. Also columns specified with parameter `columns`
#' will be converted (if present).
#'
#' @param x `DataFrame`
#'
#' @param columns `character` of column names that should be converted to `Rle`
#'
#' @return `DataFrame`
#'
#' @author Johannes Rainer
#'
#' @importClassesFrom S4Vectors Rle
#'
#' @importFrom S4Vectors Rle
#'
#' @noRd
.as_rle_spectra_data <- function(x, columns = c("dataStorage", "dataOrigin")) {
    if (nrow(x) <= 1)
        return(x)
    for (col in colnames(x)) {
        x[[col]] <- .as_rle(x[[col]])
    }
    columns <- intersect(columns, colnames(x))
    for (col in columns) {
        if (!is(x[[col]], "Rle"))
            x[[col]] <- Rle(x[[col]])
    }
    x
}


#' *Uncompress* a `DataFrame` by converting all of its columns that contain
#' an `Rle` with `as.vector`.
#'
#' @param x `DataFrame`
#'
#' @return `DataFrame` with all `Rle` columns converted to vectors.
#'
#' @author Johannes Rainer
#'
#' @noRd
.as_vector_spectra_data <- function(x) {
    cols <- colnames(x)[vapply(x, is, logical(1), "Rle")]
    for (col in cols) {
        x[[col]] <- as.vector(x[[col]])
    }
    x
}

#' Helper function to return a column from the (spectra data) `DataFrame`. If
#' the column `column` is an `Rle` `as.vector` is called on it. If column is
#' the name of a mandatory variable but it is not available it is created on
#' the fly.
#'
#' @param x `DataFrame`
#'
#' @param column `character(1)` with the name of the column to return.
#'
#' @importMethodsFrom S4Vectors [[
#'
#' @author Johannes Rainer
#'
#' @noRd
.get_rle_column <- function(x, column) {
    if (any(colnames(x) == column)) {
        if (is(x[[column]], "Rle"))
            as.vector(x[[column]])
        else x[[column]]
    } else if (any(names(.SPECTRA_DATA_COLUMNS) == column)) {
        nr_x <- nrow(x)
        if (nr_x)
            as(rep(NA, nr_x), .SPECTRA_DATA_COLUMNS[column])
        else
            do.call(.SPECTRA_DATA_COLUMNS[column], args = list())
    } else stop("column '", column, "' not available")
}

#' @description
#'
#' Helper to be used in the filter functions to select the file/origin in
#' which the filtering should be performed.
#'
#' @param object `MsBackend`
#'
#' @param dataStorage `character` or `integer` with either the names of the
#'     `dataStorage` or their index (in `unique(object$dataStorage)`) in which
#'     the filtering should be performed.
#'
#' @param dataOrigin same as `dataStorage`, but for the `dataOrigin` spectra
#'     variable.
#'
#' @return `logical` of length equal to the number of spectra in `object`.
#'
#' @noRd
.sel_file <- function(object, dataStorage = integer(), dataOrigin = integer()) {
    if (length(dataStorage)) {
        lvls <- unique(object@spectraData$dataStorage)
        if (!(is.numeric(dataStorage) || is.character(dataStorage)))
            stop("'dataStorage' has to be either an integer with the index of",
                 " the data storage, or its name")
        if (is.numeric(dataStorage)) {
            if (dataStorage < 1 || dataStorage > length(lvls))
                stop("'dataStorage' should be an integer between 1 and ",
                     length(lvls))
            dataStorage <- lvls[dataStorage]
        }
        dataStorage(object) %in% dataStorage
    } else if (length(dataOrigin)) {
        lvls <- unique(object@spectraData$dataOrigin)
        if (!(is.numeric(dataOrigin) || is.character(dataOrigin)))
            stop("'dataOrigin' has to be either an integer with the index of",
                 " the data origin, or its name")
        if (is.numeric(dataOrigin)) {
            if (dataOrigin < 1 || dataOrigin > length(lvls))
                stop("'dataOrigin' should be an integer between 1 and ",
                     length(lvls))
            dataOrigin <- lvls[dataOrigin]
        }
        dataOrigin(object) %in% dataOrigin
    } else rep(TRUE, length(object))
}

#' Helper function to combine backends that base on [MsBackendDataFrame()].
#'
#' @param objects `list` of `MsBackend` objects.
#'
#' @return [MsBackend()] object with combined content.
#'
#' @author Johannes Rainer
#'
#' @noRd
.combine_backend_data_frame <- function(objects) {
    if (length(objects) == 1)
        return(objects[[1]])
    if (!all(vapply(objects, class, character(1)) == class(objects[[1]])))
        stop("Can only merge backends of the same type: ", class(objects[[1]]))
    res <- new(class(objects[[1]]))
    suppressWarnings(
        res@spectraData <- .as_rle_spectra_data(do.call(
            .rbind_fill, lapply(objects, function(z) z@spectraData)))
    )
    if (any(colnames(res@spectraData) == "mz"))
        res@spectraData$mz[is.na(res@spectraData$mz)] <- list(numeric())
    if (any(colnames(res@spectraData) == "intensity"))
        res@spectraData$intensity[is.na(res@spectraData$intensity)] <-
            list(numeric())
    res
}