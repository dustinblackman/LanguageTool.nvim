" LanguageTool: Grammar checker in Vim for English, French, German, etc.
" Maintainer:   Thomas Vigouroux <tomvig38@gmail.com>
" Last Change:  2019 Oct 14
" Version:      1.0
"
" License: {{{1
"
" The VIM LICENSE applies to LanguageTool.nvim plugin
" (see ":help copyright" except use "LanguageTool.nvim" instead of "Vim").
"
" }}} 1

" This function is the callback for text checking
function! LanguageTool#check#callback(output) "{{{1
    if empty(a:output)
        return -1
    endif

    call LanguageTool#clear()

    let l:file_content = join(nvim_buf_get_lines(0, 0, -1, v:false), "\n")
    let l:languagetool_text_winid = win_getid()
    " Loop on all errors in output of LanguageTool and
    " collect information about all errors in list s:errors
    let b:errors = a:output.matches
    let l:index = 0
    for l:error in b:errors

        " There be dragons, this is true blackmagic happening here, we hardpatch offset field of LT
        " {from|to}{x|y} are not provided by LT JSON API, thus we have to compute them
        let l:start_byte_index = byteidxcomp(l:file_content, l:error.offset + 1) + 1 " All errrors are offsetted by 2
        let l:error.fromy = byte2line(l:start_byte_index)
        let l:error.fromx = l:start_byte_index - line2byte(l:error.fromy)
        let l:error.start_byte_idx = l:start_byte_index

        let l:stop_byte_index = byteidxcomp(l:file_content, l:error.offset + l:error.length + 1) + 1
        " Sometimes the error goes too far to the end of the file
        " causing byte2line to give negative values
        if byte2line(l:stop_byte_index) >= 0
            let l:error.toy = byte2line(l:stop_byte_index)
            let l:error.tox = l:stop_byte_index - line2byte(l:error.toy)
        else
            let l:error.toy = line('$')
            let l:error.tox = col([l:error.toy, '$'])
        endif

        let l:error.stop_byte_idx = l:stop_byte_index

        let l:error.source_win = l:languagetool_text_winid
        let l:error.index = l:index
        let l:index = l:index + 1
        let l:error.nr_errors = len(b:errors)
    endfor

    " Also highlight errors in original buffer and populate location list.
    setlocal errorformat=%f:%l:%c:%m
    for l:error in b:errors
        let l:re = LanguageTool#errors#highlightRegex(l:error)

        if l:error.rule.id =~# 'HUNSPELL_RULE\|HUNSPELL_NO_SUGGEST_RULE\|MORFOLOGIK_RULE_\|_SPELLING_RULE\|_SPELLER_RULE'
            call matchadd('LanguageToolSpellingError', l:re)
        else
            call matchadd('LanguageToolGrammarError', l:re)
        endif
        laddexpr expand('%') . ':'
        \ . l:error.fromy . ':'  . l:error.fromx . ':'
        \ . l:error.rule.id . ' : ' . l:error.message
    endfor

    doautocmd User LanguageToolCheckDone
    return 0
endfunction " }}}

" This functions toggles automatic check for buffer buffername
function! LanguageTool#check#toggle(buffername, options) "{{{
    augroup LTBufferAutocmds
        if exists('b:buffer_toggled')
            execute printf('autocmd! * %s', a:buffername)
            unlet b:buffer_toggled
        else
            execute printf('autocmd InsertLeave %s call LanguageTool#check(v:false, "%s")', a:buffername, a:options)
            execute printf('autocmd CursorHoldI %s call LanguageTool#check(v:false, "%s")', a:buffername, a:options)
            let b:buffer_toggled = 1
        endif
    augroup END
endfunction "}}}
