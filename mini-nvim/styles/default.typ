// default: light touches on pandoc's template.
#show heading: set block(above: 1.4em, below: 0.7em)
#show link: set text(fill: rgb("#1a5fb4"))
#show raw.where(block: true): block.with(
  fill: luma(245), inset: 8pt, radius: 4pt, width: 100%,
)
#show raw.where(block: false): box.with(
  fill: luma(240), inset: (x: 3pt), outset: (y: 3pt), radius: 2pt,
)
