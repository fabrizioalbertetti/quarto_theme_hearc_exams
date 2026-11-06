--[[
  Examens HE-Arc : énoncé / corrigé à partir d'un même fichier.

  Métadonnées lues (en-tête YAML du .qmd ou _quarto.yml) :
    title           titre, ex. nom du cours (titre du document)
    subtitle        sous-titre, ex. Contrôle Principal (en-tête et titre du document)
    solution        true -> corrigé, false -> énoncé
    exam:
      short         nom court du cours affiché dans l'en-tête, ex. IA (défaut : title)
      classe        ex. ISC3
      annee         ex. 2026-2027
      date          date affichée en pied de page (à droite)
      type          ex. CP -> pied de page central "Corrigé CP" dans le corrigé
      materiel      matériel autorisé
      duree         durée de l'examen
      instructions  consignes (liste YAML ou texte), affichées en liste à puces
      points        total de points ; absent ou "auto" -> somme des "(N pts)"
                    des titres et des questions numérotées ("1. (2 pts) …")
                    (avertissement si valeur différente ou si rien n'est trouvé)
      nom           true/false : cadre NOM / Prénom dans l'énoncé (défaut true)
      logo          chemin vers un logo (défaut : logo HE-Arc de l'extension)

  Blocs :
    ::: {.sol reponse="3cm"}   solution (corrigé) ou boîte de réponse vide (énoncé)
                               reponse="0" : rien dans l'énoncé (ex. justification de QCM)
    ::: {.exam}                contenu affiché uniquement dans l'énoncé, encadré
    ::: {.qcm colonnes="2"}    QCM : liste "- [ ] fausse" / "- [x] correcte"
                               (cases vides dans l'énoncé, cochées dans le corrigé)
    ::: {.colonnes n="2"}      contenu (p. ex. questions de QCM) sur n colonnes
                               (2 par défaut) ; une question n'est jamais coupée
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
    "\\def\\cpsoustitre{" .. to_latex(meta.subtitle) .. "}",
    "\\def\\cpcourt{" .. to_latex(exam.short or meta.title) .. "}",
    "\\def\\cpclasse{" .. to_latex(exam.classe) .. "}",
    "\\def\\cpannee{" .. to_latex(exam.annee) .. "}",
    "\\def\\cppieddroite{" .. to_latex(exam.date) .. "}",
    "\\def\\cppiedcentre{\\ifsolution " .. pied_centre .. "\\fi}",
    "\\def\\cplogo{" .. logo .. "}",
  }, "\n")
  add_header(meta, tex)
  return meta
end

-- QCM : liste de tâches Markdown (- [ ] fausse / - [x] correcte)
-- Énoncé : cases vides. Corrigé : cases correctes cochées.
-- Retire la marque ☐/☒ d'un élément de liste ; renvoie la case LaTeX à afficher
local function case_qcm(item)
  local correcte = false
  local first = item[1]
  if first and (first.t == "Plain" or first.t == "Para") and first.content[1]
      and first.content[1].t == "Str" then
    local marque = first.content[1].text
    if marque == "☒" or marque == "☐" then
      correcte = (marque == "☒")
      first.content:remove(1)
      if first.content[1] and first.content[1].t == "Space" then
        first.content:remove(1)
      end
    end
  end
  return (solution and correcte) and "\\qcmcoche" or "\\qcmvide"
end

local function qcm(el)
  local cols = tonumber(el.attributes["colonnes"] or "1") or 1
  local out = pandoc.Blocks({})

  for _, block in ipairs(el.content) do
    if block.t == "BulletList" and cols > 1 then
      -- Grille : réponses courtes réparties ligne par ligne sur `cols` colonnes
      local cellules = {}
      for i, item in ipairs(block.content) do
        local case = case_qcm(item)
        local texte = pandoc.write(pandoc.Pandoc(item), "latex"):gsub("%s+$", "")
        local sep = (i % cols == 0) and " \\\\[3pt]\n" or " &\n"
        table.insert(cellules, "\\qcmcellule{" .. case .. "}{" .. texte .. "}" .. sep)
      end
      local n = #block.content
      if n % cols ~= 0 then table.insert(cellules, " \\\\[3pt]\n") end
      out:insert(pandoc.RawBlock("latex",
        "\\qcmgrille{" .. cols .. "}{\n" .. table.concat(cellules) .. "}"))
    elseif block.t == "BulletList" then
      out:insert(pandoc.RawBlock("latex", "\\begin{qcm}"))
      for _, item in ipairs(block.content) do
        out:insert(pandoc.RawBlock("latex", "\\item[" .. case_qcm(item) .. "]"))
        out:extend(item)
      end
      out:insert(pandoc.RawBlock("latex", "\\end{qcm}"))
    else
      out:insert(block)
    end
  end
  return out
end

local function Div(el)
  if el.classes:includes("sol") then
    if solution then
      -- \nopagebreak : la solution reste collée à sa question
      local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\nopagebreak\\begin{solbox}") })
      blocks:extend(el.content)
      blocks:insert(pandoc.RawBlock("latex", "\\end{solbox}"))
      return blocks
    end
    local h = el.attributes["reponse"] or "3cm"
    if tonumber((h:gsub("%a+$", ""))) == 0 then return {} end -- reponse="0" : rien dans l'énoncé
    return pandoc.RawBlock("latex", "\\reponse{" .. h .. "}")
  end

  if el.classes:includes("qcm") then
    return qcm(el)
  end

  if el.classes:includes("colonnes") then
    local n = tonumber(el.attributes["n"] or "2") or 2
    local titre = el.attributes["titre-latex"] or ""
    local blocks = pandoc.Blocks({ pandoc.RawBlock("latex",
      "\\begin{colonnes}[{" .. titre .. "}]{" .. n .. "}") })
    blocks:extend(el.content)
    blocks:insert(pandoc.RawBlock("latex", "\\end{colonnes}"))
    return blocks
  end

  if el.classes:includes("exam") then
    if solution then return {} end
    local blocks = pandoc.Blocks({ pandoc.RawBlock("latex", "\\begin{exambox}") })
    blocks:extend(el.content)
    blocks:insert(pandoc.RawBlock("latex", "\\end{exambox}"))
    return blocks
  end
end

-- Points "(N pts)" / "(N pt)" / "(N points)" dans un texte, ou nil
local function lire_points(inlines)
  local s = pandoc.utils.stringify(inlines)
  local n = s:match("%(%s*([%d%.,]+)%s*pts?%.?%s*%)")
    or s:match("%(%s*([%d%.,]+)%s*points?%s*%)")
  return n and tonumber((n:gsub(",", ".")))
end

-- Somme des points indiqués :
--   - dans les titres : "## Exercice 1 (4 pts)" ;
--   - dans le premier paragraphe des questions numérotées : "1. (2 pts) Question…",
--     y compris dans ::: {.colonnes} et ::: {.qcm}.
-- Un élément n'est compté que si aucun parent (titre ou question) n'est déjà
-- compté (ex. "### a) (1 pt)" sous "## Exercice 1 (4 pts)" n'est pas additionné).
-- Le contenu des solutions (::: {.sol}) est ignoré.
local function somme_points(blocks, parent_compte)
  local total, niveau_compte = 0, nil
  for _, b in ipairs(blocks) do
    if b.t == "Header" then
      if niveau_compte and b.level <= niveau_compte then niveau_compte = nil end
      local n = lire_points(b.content)
      if n and not parent_compte and niveau_compte == nil then
        total = total + n
        niveau_compte = b.level
      end
    else
      local compte = parent_compte or niveau_compte ~= nil
      if b.t == "OrderedList" or b.t == "BulletList" then
        for _, item in ipairs(b.content) do
          local first = item[1]
          local n = b.t == "OrderedList" and first
            and (first.t == "Para" or first.t == "Plain") and lire_points(first.content)
          if n and not compte then
            total = total + n
          else
            total = total + somme_points(item, compte)
          end
        end
      elseif b.t == "Div" and not b.classes:includes("sol") then
        total = total + somme_points(b.content, compte)
      elseif b.t == "BlockQuote" then
        total = total + somme_points(b.content, compte)
      end
    end
  end
  return total
end

local function format_points(x)
  if x == math.floor(x) then return string.format("%d", x) end
  return (string.format("%g", x):gsub("%.", ","))
end

-- Calculé avant que les titres placés devant ::: {.colonnes} soient déplacés
local total = 0
local function calcul_points(doc)
  total = somme_points(doc.blocks)
end

-- Un titre suivi directement de ::: {.colonnes} passe dans le préambule de
-- multicols, pour ne pas rester seul en bas de page.
local function titres_colonnes(blocks)
  for i = #blocks - 1, 1, -1 do
    local h, d = blocks[i], blocks[i + 1]
    if h.t == "Header" and d.t == "Div" and d.classes:includes("colonnes") then
      d.attributes["titre-latex"] = (pandoc.write(pandoc.Pandoc({ h }), "latex"):gsub("%s+$", ""))
      blocks:remove(i)
    end
  end
  return blocks
end

-- Bloc d'informations en début de document
local function Pandoc(doc)
  -- exam.points absent ou "auto" : somme des points des exercices
  local points = exam.points and pandoc.utils.stringify(exam.points) or "auto"
  if points == "auto" then
    if total > 0 then
      points = format_points(total)
    else
      points = nil
      quarto.log.warning("exam.points : aucun \"(N pts)\" trouvé dans les titres ni dans "
        .. "les questions numérotées ; le total de points n'est pas affiché. "
        .. "Indiquer les points (ex. \"1. (2 pts) Question…\") ou fixer exam.points.")
    end
  elseif total > 0 and tonumber((points:gsub(",", "."))) ~= total then
    quarto.log.warning("exam.points = " .. points .. " mais la somme des exercices vaut "
      .. format_points(total))
  end

  local lignes = {}
  local function ligne(label, v)
    if v ~= nil and pandoc.utils.stringify(v) ~= "" then
      table.insert(lignes, "**" .. label .. " :** " .. pandoc.utils.stringify(v))
    end
  end
  ligne("Matériel autorisé", exam.materiel)
  ligne("Durée", exam.duree)
  ligne("Total de points", points)

  local intro = pandoc.Blocks({})
  if #lignes > 0 then
    intro:extend(pandoc.read(table.concat(lignes, " \\\n"), "markdown").blocks)
  end

  -- Consignes : liste YAML (ou texte simple) affichée en liste à puces
  local instr = exam.instructions
  if instr ~= nil then
    if pandoc.utils.type(instr) ~= "List" then instr = { instr } end
    local items = {}
    for _, i in ipairs(instr) do
      local inl = pandoc.utils.type(i) == "Inlines" and i or pandoc.Inlines(pandoc.utils.stringify(i))
      if #inl > 0 then table.insert(items, { pandoc.Plain(inl) }) end
    end
    if #items > 0 then
      intro:insert(pandoc.Para({ pandoc.Strong("Consignes :") }))
      intro:insert(pandoc.BulletList(items))
    end
  end

  if not solution and (exam.nom == nil or is_true(exam.nom)) then
    intro:extend(pandoc.read("::: {.exam}\n**NOM :** \\hspace{6cm} **Prénom :**\n:::\n",
      "markdown").blocks:walk({ Div = Div }))
  end
  if #intro == 0 then return nil end

  intro:extend(doc.blocks)
  doc.blocks = intro
  return doc
end

return {
  { Meta = Meta },
  { Pandoc = calcul_points },
  { Blocks = titres_colonnes },
  { Div = Div },
  { Pandoc = Pandoc },
}
