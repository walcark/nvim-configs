# Styles of :MarkdownPreview

A style is two files with the same name:

- `<name>.yaml`: pandoc defaults. Page and text settings that pandoc's Typst
  template understands (papersize, margin, mainfont, fontsize, codefont,
  section-numbering, page-numbering, linestretch...).
- `<name>.typ`: Typst rules applied on top, at the start of the body
  (`#show` and `#set` for headings, code blocks, links...). No `#set page`
  here: a page rule after the title block would start a new page.

Chosen by, in this order: `:Preview <name>`, `style: <name>` in the note's
front matter, then `default`. Only fonts that Typst embeds are used, so the
rendering is the same on every machine.
