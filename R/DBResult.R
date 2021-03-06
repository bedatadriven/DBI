#' DBIResult class
#'
#' This virtual class describes the result and state of execution of
#' a DBMS statement (any statement, query or non-query).  The result set
#' keeps track of whether the statement produces output how many rows were
#' affected by the operation, how many rows have been fetched (if statement is
#' a query), whether there are more rows to fetch, etc.
#'
#' @section Implementation notes:
#' Individual drivers are free to allow single or multiple
#' active results per connection.
#'
#' The default show method displays a summary of the query using other
#' DBI generics.
#'
#' @name DBIResult-class
#' @docType class
#' @family DBI classes
#' @family DBIResult generics
#' @export
#' @include DBObject.R
setClass("DBIResult", contains = c("DBIObject", "VIRTUAL"))

#' @rdname hidden_aliases
#' @param object Object to display
#' @export
setMethod("show", "DBIResult", function(object) {
  # to protect drivers that fail to implement the required methods (e.g.,
  # RPostgreSQL)
  tryCatch(
    show_result(object),
    error = function(e) NULL)
  invisible(NULL)
})

show_result <- function(object) {
  cat("<", is(object)[1], ">\n", sep = "")
  if(!dbIsValid(object)){
    cat("EXPIRED\n")
  } else {
    cat("  SQL  ", dbGetStatement(object), "\n", sep = "")

    done <- if (dbHasCompleted(object)) "complete" else "incomplete"
    cat("  ROWS Fetched: ", dbGetRowCount(object), " [", done, "]\n", sep = "")
    cat("       Changed: ", dbGetRowsAffected(object), "\n", sep = "")
  }
}

#' Fetch records from a previously executed query
#'
#' Fetch the next `n` elements (rows) from the result set and return them
#' as a data.frame.
#'
#' `fetch` is provided for compatibility with older DBI clients - for all
#' new code you are strongly encouraged to use `dbFetch`. The default
#' method for `dbFetch` calls `fetch` so that it is compatible with
#' existing code. Implementors are free to provide methods for `dbFetch`
#' only.
#'
#' @param res An object inheriting from \code{\linkS4class{DBIResult}}.
#' @param n maximum number of records to retrieve per fetch. Use `n = -1`
#'   to retrieve all pending records.  Some implementations may recognize other
#'   special values.
#' @param ... Other arguments passed on to methods.
#' @return a data.frame with as many rows as records were fetched and as many
#'   columns as fields in the result set.
#' @seealso close the result set with [dbClearResult()] as soon as you
#'   finish retrieving the records you want.
#' @family DBIResult generics
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#'
#' # Fetch all results
#' rs <- dbSendQuery(con, "SELECT * FROM mtcars WHERE cyl = 4")
#' dbFetch(rs)
#' dbClearResult(rs)
#'
#' # Fetch in chunks
#' rs <- dbSendQuery(con, "SELECT * FROM mtcars")
#' while (!dbHasCompleted(rs)) {
#'   chunk <- dbFetch(rs, 10)
#'   print(nrow(chunk))
#' }
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
#' @export
setGeneric("dbFetch",
  def = function(res, n = -1, ...) standardGeneric("dbFetch"),
  valueClass = "data.frame"
)

#' @rdname hidden_aliases
#' @export
setMethod("dbFetch", "DBIResult", function(res, n = -1, ...) {
  fetch(res, n = n, ...)
})

#' @rdname dbFetch
#' @export
setGeneric("fetch",
  def = function(res, n = -1, ...) standardGeneric("fetch"),
  valueClass = "data.frame"
)

#' Clear a result set
#'
#' Frees all resources (local and remote) associated with a result set.  In some
#' cases (e.g., very large result sets) this can be a critical step to avoid
#' exhausting resources (memory, file descriptors, etc.)
#'
#' @param res An object inheriting from \code{\linkS4class{DBIResult}}.
#' @param ... Other arguments passed on to methods.
#' @return a logical indicating whether clearing the
#'   result set was successful or not.
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' rs <- dbSendQuery(con, "SELECT 1")
#' print(dbFetch(rs))
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbClearResult",
  def = function(res, ...) standardGeneric("dbClearResult"),
  valueClass = "logical"
)

#' Information about result types
#'
#' Produces a data.frame that describes the output of a query. The data.frame
#' should have as many rows as there are output fields in the result set, and
#' each column in the data.frame should describe an aspect of the result set
#' field (field name, type, etc.)
#'
#' @inheritParams dbClearResult
#' @return A data.frame with one row per output field in `res`. Methods
#'   MUST include `name`, `field.type` (the SQL type),
#'   and `data.type` (the R data type) columns, and MAY contain other
#'   database specific information like scale and precision or whether the
#'   field can store `NULL`s.
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' rs <- dbSendQuery(con, "SELECT 1 AS a, 2 AS b")
#' dbColumnInfo(rs)
#' dbFetch(rs)
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbColumnInfo",
  def = function(res, ...) standardGeneric("dbColumnInfo"),
  valueClass = "data.frame"
)

#' Get the statement associated with a result set
#'
#' Returns the statement that was passed to [dbSendQuery()].
#'
#' @inheritParams dbClearResult
#' @return a character vector
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#' rs <- dbSendQuery(con, "SELECT * FROM mtcars")
#' dbGetStatement(rs)
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbGetStatement",
  def = function(res, ...) standardGeneric("dbGetStatement"),
  valueClass = "character"
)


#' Completion status
#'
#' This method returns if the operation has completed.
#' A `SELECT` query is completed if all rows have been fetched.
#' A data manipulation statement is completed if it has been executed.
#'
#' @inheritParams dbClearResult
#' @return a logical vector of length 1
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#' rs <- dbSendQuery(con, "SELECT * FROM mtcars")
#'
#' dbHasCompleted(rs)
#' ret1 <- dbFetch(rs, 10)
#' dbHasCompleted(rs)
#' ret2 <- dbFetch(rs)
#' dbHasCompleted(rs)
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbHasCompleted",
  def = function(res, ...) standardGeneric("dbHasCompleted"),
  valueClass = "logical"
)


#' The number of rows affected
#'
#' This function returns the number of rows that were added, deleted, or updated
#' by a data manipulation statement. For a selection query, this function
#' returns 0.
#'
#' @inheritParams dbClearResult
#' @return a numeric vector of length 1
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#' rs <- dbSendStatement(con, "DELETE FROM mtcars")
#' dbGetRowsAffected(rs)
#' nrow(mtcars)
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbGetRowsAffected",
  def = function(res, ...) standardGeneric("dbGetRowsAffected"),
  valueClass = "numeric"
)


#' The number of rows fetched so far
#'
#' This value is increased by calls to [dbFetch()]. For a data
#' modifying query, the return value is 0.
#'
#' @inheritParams dbClearResult
#' @return a numeric vector of length 1
#' @family DBIResult generics
#' @export
#' @examples
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "mtcars", mtcars)
#' rs <- dbSendQuery(con, "SELECT * FROM mtcars")
#'
#' dbGetRowCount(rs)
#' ret1 <- dbFetch(rs, 10)
#' dbGetRowCount(rs)
#' ret2 <- dbFetch(rs)
#' dbGetRowCount(rs)
#' nrow(ret1) + nrow(ret2)
#'
#' dbClearResult(rs)
#' dbDisconnect(con)
setGeneric("dbGetRowCount",
  def = function(res, ...) standardGeneric("dbGetRowCount"),
  valueClass = "numeric"
)


#' @name dbGetInfo
#' @section Implementation notes:
#' The default implementation for `DBIResult objects`
#' constructs such a list from the return values of the corresponding methods,
#' [dbGetStatement()], [dbGetRowCount()],
#' [dbGetRowsAffected()], and [dbHasCompleted()].
NULL
#' @rdname hidden_aliases
setMethod("dbGetInfo", "DBIResult", function(dbObj, ...) {
  list(
    statement = dbGetStatement(dbObj),
    row.count = dbGetRowCount(dbObj),
    rows.affected = dbGetRowsAffected(dbObj),
    has.completed = dbHasCompleted(dbObj)
  )
})


#' Bind values to a parameterised/prepared statement
#'
#' For parametrised or prepared statements,
#' the [dbSendQuery()] function can be called with queries
#' that contain placeholders for values. The [dbBind()] function
#' (documented here) binds these placeholders
#' to actual values, and is intended to be called on the result of
#' [dbSendQuery()] before calling [dbFetch()].
#'
#' Parametrised or prepared statements are executed as follows:
#'
#' 1. Call [DBI::dbSendQuery()] or [DBI::dbSendStatement()] with a query or statement
#'    that contains placeholders,
#'    store the returned \code{\linkS4class{DBIResult}} object in a variable.
#'    Mixing placeholders (in particular, named and unnamed ones) is not
#'    recommended.
#'    It is good practice to register a call to [DBI::dbClearResult()] via
#'    [on.exit()] right after calling `dbSendQuery()`, see the last
#'    enumeration item.
#' 1. Construct a list with parameters
#'    that specify actual values for the placeholders.
#'    The list must be named or unnamed,
#'    depending on the kind of placeholders used.
#'    Named values are matched to named parameters, unnamed values
#'    are matched by position.
#'    All elements in this list must have the same lengths and contain values
#'    supported by the backend; a [data.frame()] is internally stored as such
#'    a list.
#'    The parameter list is passed a call to [dbBind()] on the `DBIResult`
#'    object.
#' 1. Retrieve the data or the number of affected rows from the  `DBIResult` object.
#'     - For queries issued by `dbSendQuery()`,
#'       call [DBI::dbFetch()].
#'     - For statements issued by `dbSendStatements()`,
#'       call [DBI::dbGetRowsAffected()].
#'       (Execution begins immediately after the `dbBind()` call,
#'       the statement is processed entirely before the function returns.
#'       Calls to `dbFetch()` are ignored.)
#' 1. Repeat 2. and 3. as necessary.
#' 1. Close the result set via [DBI::dbClearResult()].
#'
#' @inheritParams dbClearResult
#' @param params A list of bindings
#' @family DBIResult generics
#' @export
#' @examples
#' \dontrun{
#' con <- dbConnect(RSQLite::SQLite(), ":memory:")
#'
#' dbWriteTable(con, "iris", iris)
#' iris_result <- dbSendQuery(con, "SELECT * FROM iris WHERE [Petal.Width] > ?")
#' dbBind(iris_result, list(2.3))
#' dbFetch(iris_result)
#' dbBind(iris_result, list(3))
#' dbFetch(iris_result)
#'
#' dbClearResult(iris_result)
#' dbDisconnect(con)
#' }
setGeneric("dbBind", function(res, params, ...) {
  standardGeneric("dbBind")
})
