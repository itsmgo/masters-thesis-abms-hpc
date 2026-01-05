#set page(margin: 1.0in)
#set text(font: "New Computer Modern", size: 12pt)
#set par(
  first-line-indent: 1em,
  spacing: 1em,
  justify: true,
)
#set enum(numbering: "1.1.", full: true)

#include "cover.typ"

#set page(numbering: "1")

#show outline.entry.where(level: 1): set block(above: 1.5em)
#show outline.entry.where(level: 1): set text(weight: 700)
#show outline.entry.where(level: 2): set block(above: 0.75em)

#pagebreak()
#outline(title: [Table of Contents #v(1.25em)])

#show outline.entry.where(level: 1): set text(weight: 500)
#show outline.entry: it => link(it.element.location(), it.indented(it.prefix(), it.inner(), gap: 20pt))

#pagebreak()
#outline(title: [List of Figures], target: figure.where(kind: image))

#pagebreak()
#outline(title: [List of Tables], target: figure.where(kind: table))

#set heading(numbering: "1.1")
#show heading: it => v(1em) + block(counter(heading).display() + " " + it.body, height: 1.25em)
#show heading.where(level: 1): it => pagebreak() + v(2em) + block(text(16pt, "Chapter " + counter(heading).display().at(0))) + block(text(20pt, it.body), height: 2em)

#include "intro.typ"

#set page(margin: 0.85in)
#set text(size: 10pt)
#set heading(numbering: none)
#show heading: it => pagebreak() + block(it.body, height: 2em)

#bibliography("references.bib")
