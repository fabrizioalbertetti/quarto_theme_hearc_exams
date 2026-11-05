--[[
  Examens HE-Arc : énoncé / corrigé à partir d'un même fichier.

  Métadonnées lues (en-tête YAML du .qmd ou _quarto.yml) :
    title           titre (en-tête et titre du document)
    solution        true -> corrigé, false -> énoncé
    exam:
      classe        ex. ISC3
      annee         ex. 2026-2027
      date          date affichée en pied de page (à droite)
      type          ex. CP -> pied de page central "Corrigé CP" dans le corrigé
      materiel      matériel autorisé
      duree         durée de l'examen
      points        total de points
      nom           true/false : cadre NOM / Prénom dans l'énoncé (défaut true)
      logo          chemin vers un logo (défaut : logo HE-Arc de l'extension)

  Blocs :
    ::: {.sol reponse="3cm"}   solution (corrigé) ou boîte de réponse vide (énoncé)
    ::: {.exam}                contenu affiché uniquement dans l'énoncé, encadré
]]

local solution = false

local function is_true(v)
  if v == nil then return false end
  if type(v) == "boolean" then return v end
  return pandoc.utils.stringify(v) == "true"
end

-- Convertit une valeur de métadonnée en LaTeX
local function to_latex(v)
  if v == nil then return "" end
  if type(v) == "boolean" or type(v) == "number" then return tostring(v) end
  local inlines
  if type(v) == "string" then
    inlines = pandoc.Inlines({ pandoc.Str(v) })
  elseif pandoc.utils.type(v) == "Inlines" then
    inlines = v
  else
    inlines = pandoc.Inlines({ pandoc.Str(pandoc.utils.stringify(v)) })
  end
  local out = pandoc.write(pandoc.Pandoc({ pandoc.Plain(inlines) }), "latex")
  return (out:gsub("%s+$", ""))
end

local function default_logo()
  local path = quarto.utils.resolve_path("logo-he-arc-ing.jpg")
  return (path:gsub("\\", "/"))
end

local function add_header(meta, tex)
  local hi = meta["header-includes"]
  if hi == nil then
    hi = pandoc.MetaList({})
  elseif pandoc.utils.type(hi) ~= "List" then
    hi = pandoc.MetaList({ hi })
  end
  hi:insert(1, pandoc.MetaBlocks({ pandoc.RawBlock("latex", tex) }))
  meta["header-includes"] = hi
end

local exam = {}

local function Meta(meta)
  solution = is_true(meta.solution)
  exam = meta.exam or {}

  local type_exam = exam.type and to_latex(exam.type) or ""
  local pied_centre = type_exam ~= "" and ("Corrigé " .. type_exam) or "Corrigé"
  local logo = exam.logo and pandoc.utils.stringify(exam.logo) or default_logo()

  local tex = table.concat({
    "\\newif\\ifsolution",
    solution and "\\solutiontrue" or "\\solutionfalse",
    "\\def\\cptitre{" .. to_latex(meta.title) .. "}",
    "\\def\\cpclasse{" .. to_latex(exam.classe) .. "}",
    "\\def\\cpannee{" .. to_latex(exam.annee) .. "}",
    "\\def\\cppieddroite{" .. to_latex(exam.date) .. "}",
    "\\def\\cppiedcentre{\\ifsolution " .. pied_centre .. "\\fi}",
    "\\def\\cplogo{" .. logo .. "}",
  }, "\n")
  add_header(meta, tex)
  return meta
end

local function Div(el)
  if el.classes:includes("sol") then
    if solution then
      local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{solbox}") })
      blocks:extend(el.content)
      blocks:insert(pandoc.RawBlock("latex", "\\end{solbox}"))
      return blocks
    end
    local h = el.attributes["reponse"] or "3cm"
    return pandoc.RawBlock("latex", "\\reponse{" .. h .. "}")
  end

  if el.classes:includes("exam") then
    if solution then return {} end
    local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{exambox}") })
    blocks:extend(el.content)
    blocks:insert(pandoc.RawBlock("latex", "\\end{exambox}"))
    return blocks
  end
end

-- Bloc d'informations en début de document
local function Pandoc(doc)
  local lignes = {}
  local function ligne(label, v)
    if v ~= nil and pandoc.utils.stringify(v) ~= "" then
      table.insert(lignes, "**" .. label .. " :** " .. pandoc.utils.stringify(v))
    end
  end
  ligne("Matériel autorisé", exam.materiel)
  ligne("Durée", exam.duree)
  ligne("Total de points", exam.points)

  local md = table.concat(lignes, " \\\n")
  if not solution and (exam.nom == nil or is_true(exam.nom)) then
    md = md .. "\n\n::: {.exam}\n**NOM :** \\hspace{6cm} **Prénom :**\n:::\n"
  end
  if md == "" then return nil end

  local intro = pandoc.read(md, "markdown").blocks:walk({ Div = Div })
  intro:extend(doc.blocks)
  doc.blocks = intro
  return doc
end

return {
  { Meta = Meta },
  { Div = Div },
  { Pandoc = Pandoc },
}
