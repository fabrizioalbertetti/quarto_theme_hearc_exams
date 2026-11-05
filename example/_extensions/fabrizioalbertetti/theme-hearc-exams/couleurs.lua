-- Colore du texte en LaTeX : [texte]{.rouge}, [texte]{.bleu}, ...
local couleurs = { rouge = true, bleu = true, vert = true, orange = true, gris = true }

function Span(el)
  if not FORMAT:match("latex") then return nil end
  for _, cls in ipairs(el.classes) do
    if couleurs[cls] then
      local res = { pandoc.RawInline("latex", "\\textcolor{" .. cls .. "}{") }
      for _, i in ipairs(el.content) do table.insert(res, i) end
      table.insert(res, pandoc.RawInline("latex", "}"))
      return res
    end
  end
end
