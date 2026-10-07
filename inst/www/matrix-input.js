// Vanilla-JS Shiny input binding for matrixInput. Renders an optional static
// header row of column names plus one <input> per cell. The value reported to
// Shiny is { data: [[...]], rownames: [...], colnames: [...] } with string cells.
// jQuery ($) and Shiny are globals; no build step, no external deps.
// Wrapped in an IIFE so nothing leaks into the global scope.

(() => {

const binding = new Shiny.InputBinding();

const esc = s => String(s ?? "").replace(
  /[&<>"]/g, c => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;" }[c])
);

const readState = el => {
  const $el = $(el);
  return {
    values: $el.data("values") ?? [],      // array of arrays (row-major)
    rownames: $el.data("rownames") ?? [],
    colnames: $el.data("colnames") ?? [],
    rows: $el.data("rows") ?? {},
    cols: $el.data("cols") ?? {},
    klass: ($el.data("class") ?? [])[0]    // "numeric" | "character"
  };
};

// (Re)build the <table> from el._matrix into the container.
const render = el => {
  const { values, rownames, colnames, rows, cols } = el._matrix;
  // Option scalars arrive as length-1 arrays; read element [0].
  const showCols = cols.names?.[0] === true, showRows = rows.names?.[0] === true;
  const out = ["<table>"];
  if (showCols) {
    out.push("<thead><tr>");
    if (showRows) out.push("<th></th>"); // row-header corner
    for (const name of colnames) out.push(`<th>${esc(name)}</th>`);
    out.push("</tr></thead>");
  }
  out.push("<tbody>");
  values.forEach((row, i) => {
    out.push("<tr>");
    if (showRows) out.push(`<th>${esc(rownames[i])}</th>`);
    for (const v of row) out.push(`<td><input type="text" value="${esc(v)}"></td>`);
    out.push("</tr>");
  });
  out.push("</tbody></table>");
  $(el).html(out.join(""));
};

$.extend(binding, {
  find: scope => $(scope).find(".shiny-matrix"),
  getId: el => el.id,
  initialize: el => { el._matrix = readState(el); render(el); },
  getType: el => ($(el).data("class") ?? [])[0] === "numeric" ?
    "shinyMat.matrixNumeric" : "shinyMat.matrixCharacter",
  getValue: el => ({
    data: $(el).find("tbody tr").map(function() {
      return [$(this).find("input").map(function() { return this.value; }).get()];
    }).get(),
    rownames: el._matrix.rownames,
    colnames: el._matrix.colnames
  }),
  subscribe: (el, callback) => {
    el._notify = () => callback(true);
    // Commit on blur ("change"), matching the old blur-to-commit behavior and
    // avoiding a Shiny round-trip on every keystroke.
    $(el).on("change.shinyMat", "input", function() {
      if (el._matrix.klass === "numeric") {
        const v = this.value.trim();
        if (v !== "" && isNaN(parseFloat(v))) {
          this.value = this._prev ?? "";
          alert("Input must be numeric!");
          return;
        }
      }
      this._prev = this.value;
      el._notify();
    });
    // Enter moves focus one row down in the same column.
    $(el).on("keydown.shinyMat", "input", function(e) {
      if (e.key !== "Enter") return;
      e.preventDefault();
      const col = $(this).closest("td").index();
      $(this).closest("tr").next("tr").children().eq(col).find("input").focus();
    });
  },
  unsubscribe: el => { $(el).off(".shinyMat"); el._notify = null; },
  receiveMessage: (el, msg) => {
    if (!msg?.value) return;
    Object.assign(el._matrix, {
      values: msg.value.data,
      rownames: msg.value.rownames,
      colnames: msg.value.colnames
    });
    render(el);
    el._notify?.(); // notify Shiny of the new value
  }
});

Shiny.inputBindings.register(binding, "shinyMat.matrixInput");

})();
