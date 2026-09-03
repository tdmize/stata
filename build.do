*! build.do -- regenerate the Stata output in the documentation pages, then
*! render the website with Quarto.
*!
*! Run it from the repository root (the folder that contains _quarto.yml):
*!
*!     cd "C:\path\to\stata"
*!     do build.do                        // every package, then quarto render
*!     do build.do mecompare              // one package, then quarto render
*!     do build.do mecompare norender     // regenerate output only
*!     do build.do render                 // quarto render only, no Stata output
*!
*! What it does.  For every .qmd page in  <pkg>/_src/  (and its subfolders) it
*! runs -dyntext-, which executes the Stata code inside  <<dd_do>> ... <</dd_do>>
*! tags and writes the finished page -- code and output filled in -- to  <pkg>/
*! under the same relative name.  Then it calls  quarto render, which builds
*! the site into  docs/  (the folder GitHub Pages serves).  Commit and push.
*!
*! (Comment lines in this file must not contain the two characters slash-star,
*! which open a block comment in Stata even inside a comment.)
*!
*! Only edit the files in  _src/.  The .qmd files next to them are generated
*! and are overwritten on every build.
*!
*! Requirements: Stata 16+ (the floor for mecompare and its siblings; dyntext
*! itself needs 15); Quarto installed and on the PATH
*! (https://quarto.org/docs/download/) -- or put its full path in the -quarto-
*! local below.  Whatever version of each command is first on the adopath is
*! the version that produces the output; the build log records it.
*!
*! The -version- line below must stay at 16 or higher.  Under version 15 the
*! documented commands fail with r(509) even though each declares version 16
*! itself: the behaviour is keyed to the version set at the do-file level.

version 16
set more off
set linesize 100
set rmsg off

* Quarto executable.  Leave as "quarto" when it is on the PATH.  Otherwise the
* full path, e.g.  local quarto `"C:\Users\trent\AppData\Local\Programs\Quarto\bin\quarto.exe"'
local quarto "quarto"

* Packages documented on the site (folder names).
local all_pkgs "mecompare suest2 metest meinequality totalme"

* ---------------------------------------------------------------- arguments --
local pkgs   ""
local dyn    1
local render 1
foreach tok in `0' {
    if `:list posof "`tok'" in all_pkgs' {
        local pkgs "`pkgs' `tok'"
    }
    else if "`tok'" == "all" {
        local pkgs "`all_pkgs'"
    }
    else if "`tok'" == "norender" {
        local render 0
    }
    else if "`tok'" == "render" {
        local dyn 0
    }
    else {
        di as err "build.do: unknown argument `tok'"
        di as err "usage:  do build.do [pkgname ...|all] [norender] | do build.do render"
        exit 198
    }
}
if "`pkgs'" == "" & `dyn' local pkgs "`all_pkgs'"

* --------------------------------------------------------------- root check --
capture confirm file "_quarto.yml"
if _rc {
    di as err "build.do must be run from the repository root (the folder that contains _quarto.yml)."
    di as err `"In Stata:   cd "<path to the repo>"   and then   do build.do"'
    exit 601
}
local root "`c(pwd)'"

* ---------------------------------------------- 1. regenerate Stata output --
if `dyn' {
    * record which version of each command produces the output
    di as txt _n "{hline 72}" _n "build.do: commands on the adopath" _n "{hline 72}"
    foreach c of local all_pkgs {
        capture noisily which `c'
        if _rc di as err "  `c' not found on the adopath"
    }

    foreach p of local pkgs {
        di as txt _n "{hline 72}" _n "build.do: `p'" _n "{hline 72}"
        cd "`root'/`p'"
        capture mkdir fig                 // for <<dd_graph: saving(fig/...)>>
        est clear

        * pages at the top level of _src/
        local files : dir "_src" files "*.qmd"
        foreach f of local files {
            di as txt `"  dyntext _src/`f'  ->  `f'"'
            dyntext "_src/`f'", saving("`f'") replace
        }

        * pages one folder down, e.g. _src/examples/  ->  examples/
        local subs : dir "_src" dirs "*"
        foreach s of local subs {
            if "`s'" == "." | "`s'" == ".." continue
            capture mkdir "`s'"
            local files : dir "_src/`s'" files "*.qmd"
            foreach f of local files {
                di as txt `"  dyntext _src/`s'/`f'  ->  `s'/`f'"'
                dyntext "_src/`s'/`f'", saving("`s'/`f'") replace
            }
        }
        cd "`root'"
    }
}

* ------------------------------------------------------- 2. quarto render --
if `render' {
    di as txt _n "{hline 72}" _n "build.do: quarto render" _n "{hline 72}"
    capture erase "build_render.log"
    !`quarto' render > build_render.log 2>&1
    capture confirm file "build_render.log"
    if !_rc type "build_render.log"

    * tell GitHub Pages not to run the site through Jekyll
    capture confirm file "docs/.nojekyll"
    if _rc {
        tempname fh
        capture file open `fh' using "docs/.nojekyll", write replace
        capture file close `fh'
    }
    di as txt _n "Site rendered to  `root'/docs/  -- open docs/mecompare/index.html to check,"
    di as txt `"then commit and push:   git add -A  &&  git commit -m "rebuild site"  &&  git push"'
}

di as res _n "build.do: done."
