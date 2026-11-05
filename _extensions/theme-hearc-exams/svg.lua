--[[
  Inclusion directe d'images SVG (y compris les diagrammes draw.io *.drawio.svg)
  dans le PDF, sans conversion manuelle ni outil externe :

    ![](schema.drawio.svg){width=70%}

  Le SVG est converti en PDF avec le Typst fourni par Quarto. Le PDF est
  écrit à côté du SVG (schema.drawio.pdf) et régénéré à chaque rendu, donc
  toujours à jour après une modification dans draw.io.

  Toute image seule dans son paragraphe (SVG ou non) reste sur la même page
  que le texte qui la précède.

  Remarque : les libellés draw.io doivent être en texte simple (style
  html=0, case « Formatted Text » décochée), car les libellés HTML
  (foreignObject) ne sont pas rendus en dehors d'un navigateur.
]]

local function typst_exe()
  local ok, path = pcall(function() return quarto.paths.typst() end)
  if ok and path and path ~= "" then return path end
  return "typst"
end

local function svg_vers_pdf(src)
  local docdir = pandoc.path.directory(quarto.doc.input_file)
  local abs = pandoc.path.is_absolute(src) and src or pandoc.path.join({ docdir, src })
  abs = pandoc.path.normalize(abs)
  local dir, nom = pandoc.path.directory(abs), pandoc.path.filename(abs)
  local pdf_abs = abs:gsub("%.[sS][vV][gG]$", ".pdf")

  local typ = "#set page(width: auto, height: auto, margin: 0pt)\n"
    .. '#image("/' .. nom:gsub('"', '\\"') .. '")\n'
  local ok, err = pcall(pandoc.pipe, typst_exe(),
    { "compile", "--root", dir, "-", pdf_abs }, typ)
  if not ok then
    quarto.log.warning("Conversion SVG -> PDF impossible pour " .. src .. " : " .. tostring(err))
    return nil
  end
  return (src:gsub("%.[sS][vV][gG]$", ".pdf"))
end

local function Image(img)
  if not img.src:lower():match("%.svg$") or img.src:match("^%a+://") then return nil end
  local pdf = svg_vers_pdf(img.src)
  if pdf then
    img.src = pdf
    return img
  end
end

-- Une image seule dans son paragraphe reste sur la même page que le texte
-- qui la précède (pas d'énoncé orphelin en bas de page).
local function Para(p)
  if #p.content == 1 and p.content[1].t == "Image" then
    return { pandoc.RawBlock("latex", "\\imagedebut"), p, pandoc.RawBlock("latex", "\\imagefin") }
  end
end

if not FORMAT:match("latex") then return {} end
return { { Image = Image, Para = Para } }
