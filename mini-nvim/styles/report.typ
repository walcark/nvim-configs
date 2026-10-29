// report: airy spacing, numbered headings underlined at level 1, light
// tables framed top and bottom, coloured links.

// Space between paragraphs, and around headings, larger for higher levels.
#set par(spacing: 1.4em)
#show heading: set block(above: 1.8em, below: 1.2em)
#show heading.where(level: 2): set block(above: 2.1em, below: 1.3em)
#show heading.where(level: 1): it => block(above: 2.2em, below: 1.2em)[
  #set text(size: 1.3em)
  #it
  #v(-0.5em)
  #line(length: 100%, stroke: 0.6pt + luma(120))
]

// Links: web addresses and links inside the document, one colour.
#show link: set text(fill: rgb("#1a5fb4"))

// Tables: columns sized to their content, a rule above, below the header
// row and below the last row, nothing else.
#show table: set table(
  inset: (x: 8pt, y: 5pt),
  stroke: (x, y) => if y == 0 { (bottom: 0.5pt + luma(120)) },
)
#show table.cell.where(y: 0): set text(weight: "bold")
// Cells left-aligned: pandoc leaves them on `auto`, which would inherit
// the centring of the table itself.
#show table: set align(left)
#show table: it => block(stroke: (top: 0.9pt + luma(60), bottom: 0.9pt + luma(60)), it)
#show figure.where(kind: table): set block(above: 1.4em, below: 1.4em)

#show raw.where(block: true): block.with(
  stroke: 0.5pt + luma(180), inset: 8pt, radius: 3pt, width: 100%,
)
