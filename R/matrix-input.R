#' An editable matrix input for Shiny
#'
#' Create a grid of text inputs that reports its value to Shiny as a matrix. The
#' client binding is dependency-free vanilla JavaScript; its assets are attached
#' automatically wherever `matrixInput()` is used, so no `addResourcePath()`
#' setup is required.
#'
#' The widget renders an optional static row of column headers plus one editable
#' cell per matrix entry. Adding or removing rows and columns is expected to be
#' driven from the server via [updateMatrixInput()]; the client does not resize
#' the matrix itself.
#'
#' @param inputId The input slot that will be used to access the value.
#' @param label Display label for the control, or `NULL` for no label.
#' @param value The initial value, a [matrix]. Row and column names, if present,
#'   are used as the row/column headers.
#' @param inputClass Extra CSS class(es) to add to the input container.
#' @param rows,cols A list of options for the rows/columns. Recognized fields:
#'   `names` (whether to show headers; columns only by default) and
#'   `editableNames`, `extend` (accepted for compatibility but not acted on by
#'   this lightweight client).
#' @param class The storage mode of the matrix, `'character'` or `'numeric'`.
#'   Numeric inputs reject non-numeric cell entries on the client.
#' @return A Shiny input element.
#' @seealso [updateMatrixInput()] to change the value from the server.
#' @import utils
#' @export
#' @examples
#' if (interactive()) {
#'   library(shiny)
#'   shinyApp(
#'     ui = fluidPage(
#'       matrixInput('m', 'A 2x2 numeric matrix',
#'                   value = matrix(1:4, 2, dimnames = list(NULL, c('a', 'b'))),
#'                   class = 'numeric'),
#'       verbatimTextOutput('out')
#'     ),
#'     server = function(input, output, session) {
#'       output$out = renderPrint(input$m)
#'     }
#'   )
#' }
matrixInput = function(inputId, label = NULL, value = matrix('', 1, 1),
                       inputClass = '', rows = list(), cols = list(),
                       class = 'character') {
  stopifnot(is.matrix(value))

  if (is.null(rownames(value))) rownames(value) = rep('', nrow(value))
  if (is.null(colnames(value))) colnames(value) = rep('', ncol(value))

  defaults = list(names = TRUE, editableNames = FALSE, extend = FALSE, delta = 1)
  rows = fill_defaults(rows, modifyList(defaults, list(names = FALSE)))
  cols = fill_defaults(cols, defaults)

  inputField = htmltools::tags$div(
    id = inputId,
    class = paste('shiny-matrix', inputClass),
    'data-values' = to_json(value),
    'data-rownames' = to_json(rownames(value)),
    'data-colnames' = to_json(colnames(value)),
    'data-rows' = to_json(rows),
    'data-cols' = to_json(cols),
    'data-class' = to_json(class)
  )

  htmltools::attachDependencies(
    htmltools::tags$div(
      class = paste(
        'form-group shiny-matrix-input-container',
        'shiny-input-container-inline shiny-input-container'
      ),
      if (!is.null(label)) htmltools::tags$label(label, `for` = inputId),
      inputField
    ),
    matrix_dependency()
  )
}

matrix_dependency = function() {
  htmltools::htmlDependency(
    name = 'shinyMat',
    version = utils::packageVersion('shinyMat'),
    package = 'shinyMat',
    src = 'www',
    script = 'matrix-input.js',
    stylesheet = 'matrix-input.css'
  )
}

fill_defaults = function(x, o) {
  if (!is.list(x)) return(o)
  for (i in names(o)) if (is.null(x[[i]])) x[[i]] = o[[i]]
  x
}

# Minimal JSON serializer for the fixed shapes stored in the data-* attributes:
# a numeric/character matrix (as an array of row arrays), string vectors, and a
# small options list. Avoids depending on jsonlite for these few cases. Atomic
# vectors always serialize as arrays (never bare scalars), so the client reads a
# length-1 value as element [0] uniformly -- no scalar/array ambiguity.
to_json = function(x) {
  if (is.matrix(x)) {
    rows = vapply(seq_len(nrow(x)), function(i) to_json(x[i, ]), '')
    return(paste0('[', paste(rows, collapse = ','), ']'))
  }
  if (is.list(x)) {
    parts = vapply(names(x), function(k)
      paste0(json_atom(k), ':', to_json(x[[k]])), '')
    return(paste0('{', paste(parts, collapse = ','), '}'))
  }
  paste0('[', paste(vapply(x, json_atom, ''), collapse = ','), ']')
}

json_atom = function(v) {
  if (length(v) == 0 || is.na(v)) return('null')
  if (is.logical(v)) return(if (v) 'true' else 'false')
  if (is.numeric(v)) return(as.character(v))
  s = gsub('\\', '\\\\', v, fixed = TRUE)
  s = gsub('"', '\\"', s, fixed = TRUE)
  s = gsub('\n', '\\n', s, fixed = TRUE)
  s = gsub('\r', '\\r', s, fixed = TRUE)
  s = gsub('\t', '\\t', s, fixed = TRUE)
  paste0('"', s, '"')
}

#' Change the value of a matrix input on the client
#'
#' Replace the full matrix shown by a [matrixInput()] from the server, e.g. to
#' add or remove rows/columns or reset the grid. The client re-renders and
#' reports the new value back to Shiny.
#'
#' @param session The `session` object passed to the Shiny server function.
#' @param inputId The id of the input object.
#' @param value The new value, a [matrix]. Its row/column names become the
#'   row/column headers.
#' @return Called for its side effect; returns `NULL` invisibly.
#' @export
updateMatrixInput = function(session, inputId, value) {
  stopifnot(is.matrix(value))
  # sendInputMessage() encodes with jsonlite auto_unbox, which would collapse a
  # length-1 vector (e.g. a single column name) to a bare scalar; the client
  # expects arrays everywhere (it reads length-1 values as element [0]). Wrap in
  # lists so every vector stays a JSON array -- matching to_json() at init time.
  session$sendInputMessage(inputId, list(value = list(
    data = lapply(seq_len(nrow(value)), function(i) as.list(unname(value[i, ]))),
    rownames = as.list(rownames(value)),
    colnames = as.list(colnames(value))
  )))
}

# Convert the JSON value object {data, rownames, colnames} sent by the client
# into an R matrix, coercing cells with `coerce` (as.character/as.numeric).
json_to_matrix = function(x, coerce = as.character) {
  empty = function(v) is.null(v) || length(v) == 0
  if (empty(x$data)) {
    m = matrix(coerce(NA), length(x$rownames), length(x$colnames))
    if (!empty(x$colnames)) colnames(m) = x$colnames
    if (!empty(x$rownames)) rownames(m) = x$rownames
    return(m)
  }

  m = do.call(rbind, lapply(x$data, function(row) {
    row = if (empty(row)) character(0) else row
    row = lapply(row, function(el) if (is.null(el)) '' else el)
    coerce(unlist(row))
  }))

  if (!empty(x$colnames)) colnames(m) = x$colnames
  if (!empty(x$rownames)) rownames(m) = x$rownames
  m
}

.onLoad = function(libname, pkgname) {
  shiny::registerInputHandler('shinyMat.matrixNumeric', function(x, session, name) {
    json_to_matrix(x, as.numeric)
  }, force = TRUE)
  shiny::registerInputHandler('shinyMat.matrixCharacter', function(x, session, name) {
    json_to_matrix(x, as.character)
  }, force = TRUE)
}
