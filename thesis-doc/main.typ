#set page(margin: (top: 1.25in, right: 1.0in, left: 1.0in, bottom: 0.75in))
#set text(font: "New Computer Modern", size: 12pt)
#set par(
  first-line-indent: 1em,
  spacing: 1em,
  justify: true,
)
#set enum(numbering: "1.1.", full: true)
#set math.equation(numbering: "(1)")
#set figure(numbering: "1")

#include "cover.typ"


#show outline.entry.where(level: 1): set block(above: 1.5em)
#show outline.entry.where(level: 1): set text(weight: 700)
#show outline.entry.where(level: 2): set block(above: 0.75em)

#pagebreak(to: "odd")
#outline(title: [Table of Contents #v(1.25em)])

#show outline.entry.where(level: 1): set text(weight: 500)
#show outline.entry: it => link(it.element.location(), it.indented(it.prefix(), it.inner(), gap: 20pt))

#pagebreak()
#outline(title: [List of Figures], target: figure.where(kind: image))

#pagebreak()
#outline(title: [List of Tables], target: figure.where(kind: table))

#set heading(numbering: "1.1")
#show heading: it => v(1em) + block(counter(heading).display() + " " + it.body, height: 1.25em)
#show heading.where(level: 1): it => v(2em) + block(text(16pt, "Chapter " + counter(heading).display().at(0))) + block(text(20pt, it.body), height: 2em)
#let headings-on-odd-page(it) = {
  show heading.where(level: 1): it => {
    {
      set page(header: none, numbering: none)
      pagebreak(to: "odd")
    }
    it
  }
  it
}
#show: headings-on-odd-page
#set page(
  numbering: "1",
  header: context {
    let chapters = query(heading.where(level: 1))
    let current = counter(page).get()
    for (ch-a, ch-b) in chapters.windows(2) {
      let pg-a = counter(page).at(ch-a.location())
      let pg-b = counter(page).at(ch-b.location())
      if (current > pg-a and current < pg-b) {
        let page = current.at(0)
        let h-separator = h(1fr)
        let v-separator = [ #v(-0.6em) #line(length: 100%, stroke: 0.25pt) ]
        if calc.rem-euclid(current.at(0), 2) == 0 {
          [ #page #h-separator #text(10pt, [_Performance analysis of social network models in agent based systems_]) #v-separator ]
        } else {
          [ #text(10pt, [Chapter #counter(heading.where(level: 1)).display(). #ch-a.body]) #h-separator #page #v-separator ]
        }
      }
    }
  },
  footer: none)

#include "intro.typ"

#include "model_descriptions.typ"

#set page(margin: 0.85in)
#set text(size: 10pt)
#set heading(numbering: none)
#show heading: it => pagebreak() + block(it.body, height: 2em)

#bibliography("references.bib")
