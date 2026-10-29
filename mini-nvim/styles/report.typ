// report: level-1 headings underlined, code framed.
#show heading.where(level: 1): it => block(above: 1.8em, below: 1em)[
  #set text(size: 1.3em)
  #it
  #v(-0.5em)
  #line(length: 100%, stroke: 0.6pt + luma(120))
]
#show heading: set block(above: 1.4em, below: 0.7em)
#show link: set text(fill: rgb("#1a5fb4"))
#show raw.where(block: true): block.with(
  stroke: 0.5pt + luma(180), inset: 8pt, radius: 3pt, width: 100%,
)
