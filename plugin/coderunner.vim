" *vim-coderunner* Run code on-the-fly in vim
"
" Version: 1.0.0
" Author:  Dylan <https://github.com/0x84/vim-coderunner>

if exists("g:loaded_coderunner")
    finish
endif
let g:loaded_coderunner = 1
let s:rpath = expand("<sfile>:p:h:h")

" Defaults {
if !exists("g:vcr_languages")
    let g:vcr_languages = {}
endif

if !exists("g:vcr_no_mappings")
    let g:vcr_no_mappings = 0
endif
" }

let g:ansi_escaped = 0

" Funcs {
func! s:Run(ranged, l1, l2, lang)
    let lang = s:findLanguage(a:lang)
    if type(lang) != type({}) | return | endif

    " Get the code
    if a:ranged
        let code = getline(a:l1, a:l2)
    else
        let file = expand("%:p")
        if strlen(file) > 0
            call s:Execute(lang, file)
            return
        else
            " Run it without save
            let code = getline(1, "$")
        endif
    endif

    " Make a tempfile
    let fname = tempname()
    if has_key(lang, "ext") && strlen(get(lang, "ext")) > 0
        let fname = fname . "." . lang["ext"]
    endif

    " Check for shebang line
    if has_key(lang, "shebang") && match(code[0], lang["shebang"]) == -1
        call insert(code, lang["shebang"])
    endif

    " Write it to a tempfile
    call writefile(code, fname)

    " Execute
    call s:Execute(lang, fname)
endfunc

" Check to see if a language for the current filetype exists or not
func! s:findLanguage(lang)
    if strlen(a:lang) > 0 && has_key(g:vcr_languages, a:lang)
        return g:vcr_languages[a:lang]
    endif

    " No filetype?
    if strlen(&filetype)
        let ft = split(&filetype, "\\.")[0]
        if has_key(g:vcr_languages, ft)
            let lang = g:vcr_languages[ft]
        endif
    else
        " Check for shebang line
        let firstline = getline(1)
        if firstline[0:1] !=# "#!"
            echom "No filetype specified! (".firstline[0:1].")"
            return
        endif

        let test = substitute(firstline[2:], '^\s*\(.\{-}\)\s*$', '\1', '')
        if strlen(test) > 0
            let ft = split(split(firstline[2:], '/')[-1])[-1]
            if has_key(g:vcr_languages, ft)
                let lang = g:vcr_languages[ft]
            endif
        else
            unlet lang
        endif
    endif

    if exists("lang")
        if type(lang) != type({}) || !has_key(lang, "cmd")
            echoe "Language for ".&filetype." isn't set up properly"
            return
        " elseif !executable(lang["cmd"])
        "     echoe "Language for ".&filetype." isn't executable (".lang['cmd'].")"
        "     return
        endif
        return lang
    endif

    echom "No language available for this filetype"
    return
endfunc


func! s:Execute(lang, fname)
    if has_key(a:lang, "compiler")
        let old_cmdheight=&cmdheight
        set cmdheight=5
        let env = printf("command cd %s;CR_FILENAME=%s CR_ENCODING=%s", shellescape(fnamemodify(a:fname, ":p:h")), shellescape(fnamemodify(a:fname, ":p:t")), get(a:lang, "enc", "UTF-8"))
        let compiler = printf("%s %s/compiler/%s %s", env, s:rpath, a:lang["compiler"], get(a:lang, "compiler_flags", ""))
        echohl MoreMsg | echom "Compiler>> " . compiler | echohl None
        let compile_out = system(compiler)
        if v:shell_error
            call s:Preview(compile_out, compiler)
            echohl ErrorMsg | echon 'Compile failed' | echohl None
            silent execute "set cmdheight=".old_cmdheight
            return
        else
            echohl MoreMsg | echon 'Compile successful' | echohl None
        endif
        if has_key(a:lang, "cmd") && strlen(a:lang["cmd"])
            let cmd = substitute(get(a:lang, "cmd", ""), "$compiler", compile_out, "g")
            let cmd = substitute(cmd, "$filename", shellescape(a:fname), "g")
            let cmd = printf("%s %s %s", env, cmd, get(a:lang, "flags", ""))
            echohl MoreMsg | echom "Command>> " . cmd | echohl None
            let result = system(cmd)
            call s:Preview(result, cmd)
        endif
        silent execute "set cmdheight=".old_cmdheight
    else
        let cmd = printf("%s %s %s", a:lang["cmd"], get(a:lang, "flags", ""), shellescape(a:fname))
        echohl MoreMsg | echom "Command>> " . cmd | echohl None
        let result = system(cmd)
        call s:Preview(result, cmd)
    endif
endfunc


" Open a preview window and inject output into it
func! s:Preview(content, cmd)
    " Open preview buffer
    execute "silent pedit! Output"

    " Switch to preview window
    wincmd P
    setl buftype=nofile noswapfile syntax=none bufhidden=delete
    normal ggdG
    exec ":set nocursorline"
    if g:ansi_escaped
      echom "Rendering ansi..."
      exec ":AnsiEsc!"
    else
      exec ":AnsiEsc"
      let g:ansi_escaped = 1
    endif
    " Write it into the window
    call append('^', split(a:content, "\n"))
    normal gg
    normal $
    nnoremap <buffer> <leader><cr> :pclose<CR>
endfunc


" For associating default filetypes to interpreters
func! s:defLanguage(filetype, opts)
    if !has_key(g:vcr_languages, a:filetype)
        let g:vcr_languages[a:filetype] = a:opts
    endif
endfunc

func! s:compLanguage(A, L, P)
    let ret = []
    for lang in sort(keys(g:vcr_languages))
        if stridx(lang, a:A) != -1
            let ret = add(ret, lang)
        endif
    endfor
    return ret
endfunc

" Auto run mode {
let s:auto_run_dict = {}
function! s:Autorun(lang)
    if strlen(bufname('%')) < 1
        echohl ErrorMsg | echon 'Please save file first' | echohl None
        return
    endif

    let lang = ""
    if strlen(a:lang)
        let lang = a:lang
    endif

    let file = fnamemodify(bufname('%'), ':p')
    if has_key(s:auto_run_dict, file)
        call remove(s:auto_run_dict, file)
        echohl MoreMsg | echon 'autorun disabled' | echohl None
    else
        let s:auto_run_dict[file] = lang
        echohl MoreMsg | echon 'autorun enabled' | echohl None
    endif
endfunction

function! s:onbufwrite()
    let fnames = keys(s:auto_run_dict)
    if !len(fnames) | return | endif
    let file = fnamemodify(bufname('%'), ':p')
    if has_key(s:auto_run_dict, file)
        call s:Run(0, 1, '$', get(s:auto_run_dict, file))
    endif
endfunction

augroup autorun
    autocmd!
    autocmd BufWritePost * silent call s:onbufwrite()
augroup end
" }


" }

""""""""""""""""""""""""""
" Bootstrap {

" Defaults
call s:defLanguage("php",          {"cmd": "php", "shebang": "<?php"})
call s:defLanguage("python",       {"cmd": "python"})
call s:defLanguage("py",           {"cmd": "python"})
call s:defLanguage("ruby",         {"cmd": "ruby"})
call s:defLanguage("perl",         {"cmd": "perl"})
call s:defLanguage("javascript",   {"cmd": "node"})
call s:defLanguage("js",           {"cmd": "node"})
call s:defLanguage("coffee",       {"cmd": "coffee"})
call s:defLanguage("sh",           {"cmd": "sh"})
call s:defLanguage("bash",         {"cmd": "bash"})
call s:defLanguage("zsh",          {"cmd": "zsh"})
call s:defLanguage("fish",         {"cmd": "fish"})
call s:defLanguage("lua",          {"cmd": "lua"})
call s:defLanguage("go",           {"cmd": "go", "flags": "run", "shebang": "package main", "ext": "go"})
call s:defLanguage("applescript",  {"cmd": "osascript"})
call s:defLanguage("swift",        {"compiler": "swift.sh", "cmd": "./$compiler", "ext": "swift"})
call s:defLanguage("java",         {"compiler": "java.sh", "enc": "UTF-8", "cmd": "eval $compiler", "ext": "java"})
call s:defLanguage("c",            {"compiler": "c.sh", "compiler_flags": "-std=c99", "cmd": "./$compiler", "ext": "c"})
call s:defLanguage("cpp",          {"compiler": "cpp.sh", "cmd": "./$compiler", "ext": "cpp"})
call s:defLanguage("objc",         {"compiler": "objc.sh", "compiler_flags": "-fobjc-arc -framework Foundation", "cmd": "./$compiler", "ext": "m"})
call s:defLanguage("objcpp",       {"compiler": "objcpp.sh", "compiler_flags": "-fobjc-arc -framework Foundation", "cmd": "./$compiler", "ext": "mm"})

" Maps
command! -nargs=* -complete=customlist,s:compLanguage -range=0 RunCode :call s:Run(<count>, <line1>, <line2>, <q-args>)
command! -nargs=* -complete=customlist,s:compLanguage AutoRun :call s:Autorun(<q-args>)

if g:vcr_no_mappings != 1
    map <silent> <leader>r :RunCode<CR>
    if has("gui_macvim")
        map <silent> <D-r> :RunCode<CR>
    endif
endif

" }


" vim:set foldmarker={,} foldlevel=1 foldmethod=marker foldenable:
