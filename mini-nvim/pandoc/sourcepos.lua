-- pandoc filter for :MarkdownPreview's cursor sync. With `+sourcepos`, pandoc
-- wraps every block and inline in a Div or Span carrying its source position.
-- This unwraps them (they would weigh down the Typst output) and puts an
-- invisible marker before each block instead: the line it starts on, and the
-- page it lands on once laid out. `typst query <srcline>` then gives the
-- line -> page table.

-- The first line of a position, which may hold several ranges: a table's is
-- "f.md@2:1-3:1;1:1-4:1" (its body, then the whole table).
local function line_of(attr)
    local pos = attr.attributes['data-pos']
    if not pos then return nil end
    local first
    for l in pos:gmatch('[@;](%d+):') do
        l = tonumber(l)
        if not first or l < first then first = l end
    end
    return first
end

local function marker(n)
    return pandoc.RawBlock('typst',
        ('#context [#metadata((line: %d, page: here().page())) <srcline>]'):format(n))
end

function Span(el)
    if el.attributes.wrapper then return el.content end
end

function Div(el)
    if not el.attributes.wrapper then return nil end
    local out, n = {}, line_of(el.attr)
    if n then out[1] = marker(n) end
    for _, b in ipairs(el.content) do out[#out + 1] = b end
    return out
end

-- Blocks that carry their position themselves instead of a wrapper.
local function mark(el)
    local n = line_of(el.attr)
    el.attributes['data-pos'] = nil
    if n then return { marker(n), el } end
end
Header, Table, CodeBlock = mark, mark, mark
