# shinyMat

<!-- badges: start -->

[![R-CMD-check](https://github.com/yihui/shinyMat/actions/workflows/R-CMD-check.yaml/badge.svg)](https://github.com/yihui/shinyMat/actions/workflows/R-CMD-check.yaml)

<!-- badges: end -->

A lightweight editable matrix input for [Shiny](https://shiny.posit.co).

**shinyMat** renders a small grid of text inputs that reports its value to Shiny
as a matrix. The client binding is a single dependency-free vanilla-JavaScript
file — no Vue, no lodash, no build step — attached automatically as an
`htmlDependency`, so apps need no `addResourcePath()` setup. It is a trimmed
reimplementation of the subset of
[shinyMatrix](https://github.com/INWTlab/shiny-matrix) that typical apps use: a
static header row of column names plus editable cells, with the matrix resized
from the server rather than the client.

## Installation

``` r
# development version
remotes::install_github("yihui/shinyMat")
```

## Usage

``` r
library(shiny)
library(shinyMat)

ui = fluidPage(
  matrixInput(
    "m", "Edit the cells:",
    value = matrix(c(12, 24, 0.8, 0.6), 2, dimnames = list(NULL, c("Time", "Rate"))),
    class = "numeric"
  ),
  verbatimTextOutput("out")
)

server = function(input, output, session) {
  output$out = renderPrint(input$m)

  # Replace the whole matrix from the server (e.g. add/remove rows, reset):
  # updateMatrixInput(session, "m", new_matrix)
}

shinyApp(ui, server)
```

## Functions

- `matrixInput()` — create the input. `value` is a [matrix]; its row/column
  names become the headers. `class` is `"character"` or `"numeric"` (numeric
  inputs reject non-numeric cells on the client).
- `updateMatrixInput()` — replace the full matrix from the server; the client
  re-renders and reports the new value back to Shiny.

The value read from `input[[inputId]]` is a matrix of the chosen storage mode,
with the row/column names supplied to `matrixInput()`/`updateMatrixInput()`.

## Acknowledgements

This package was written with the help of Claude Code. It is a Vue-free, trimmed
reimplementation of [shinyMatrix](https://github.com/INWTlab/shiny-matrix) by
INWT Statistics; the original is more full-featured (pagination, editable and
multi-level headers, client-side row/column extension, copy/paste).
