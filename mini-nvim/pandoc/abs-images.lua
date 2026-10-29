-- pandoc filter for :MarkdownPreview. The preview is compiled from a temp
-- directory, so relative image paths would point nowhere: make them absolute
-- against the note's own directory (MDPREVIEW_DIR).
local dir = os.getenv('MDPREVIEW_DIR')

function Image(el)
    if dir and not el.src:match('^/') and not el.src:match('^%a[%w+.-]*://') then
        el.src = dir .. '/' .. el.src
    end
    return el
end
