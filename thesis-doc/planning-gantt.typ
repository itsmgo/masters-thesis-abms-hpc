#let light-border = 0.1pt
#let strong-border = 0.5pt
#let stronger-border = 0.9pt
#let cell-w = 12.9pt
#let cell-h = cell-w

#let orange = rgb("ff8c42")
#let yellow = rgb("ebd234")
#let blue = rgb("3e81ab")
#let teal   = rgb("5f9ea0")
#let green  = rgb("a6ce63")
#let colors = (blue, teal, green, yellow, orange)

#let block(color) = table.cell([], fill: color)
#let empty = table.cell([], fill: none)
#let month(t) = table.cell([#text(t, size:9pt)], colspan: 4, fill: none, stroke: (top: none, right: none)
)

#let months = ("Nov", "Dec", "Jan", "Feb", "Mar", "Apr", "May", "Jun")
#let weeks = months.len() * 4
#let tasks = (
  (1, 1, 0, 3),
  (1, 2, 1, 4),
  (1, 3, 4, 3),
  (2, 1, 6, 4),
  (2, 2, 8, 5),
  (2, 3, 10, 3),
  (3, 1, 2, 4),
  (3, 2, 6, 6),
  (3, 3, 10, 8),
  (4, 1, 16, 4),
  (4, 2, 18, 5),
  (5, 1, 22, 6),
  (5, 2, 24, 6),
)
#let pacs = (
  ("End of PAC1", 11),
  ("End of PAC2", 7),
  ("End of PAC3", 7),
  ("PAC4", 2),
)
#let pacs-durations = (6, 6+11, 6+11+7, 6+11+7+7, 6+11+7+7+2)

#table(
  columns: (40pt, ..range(weeks).map(_ => cell-w)),
  inset: 4pt,
  stroke: (x, y) => if x in pacs-durations and y != 0 {
    (right: light-border, top: light-border, bottom: light-border, left: stronger-border)
  } else if calc.rem-euclid(x, 4) == 1 {
    (right: light-border, top: light-border, bottom: light-border, left: strong-border)
  } else if y == 1 and x == 0 {
    (right: light-border, top: light-border, bottom: light-border, left: none)
  } else if x == 0 {
    (right: light-border, top: light-border, bottom: light-border, left: none)
  } else {
    light-border
  },

  // ---------- HEADER ----------
  table.header(
      table.cell([], fill: none, stroke: (top: none, left: none)),
      ..for m in months { (month(m),) },
  ),

  // ----------  ROWS  ----------
  ..for (major, minor, offset, duration) in tasks {
    ([#text("T."+str(major)+"."+str(minor), size:8pt)],
    ..for i in range(0, offset) { (empty,) },
    ..for i in range(offset, offset + duration) { (block(colors.at(major - 1)),) },
    ..for i in range(offset + duration, weeks) { (empty,) },)
  },

  // ---------- FOOTER ----------
  table.cell([], colspan: 6, fill: none, stroke: (bottom: none, left: none), align: left),
  ..for (pac, span) in pacs {
  (table.cell([#v(5pt) #strong(text(pac, size: 8pt))], colspan: span, fill: none, stroke: (bottom: none, right: none), align: left),)
  }
)
