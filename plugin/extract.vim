" Script vars {{{
func! extract#clear()
    let s:all = []
    let s:allType = []
    let s:extractAllDex = 0
    let s:currentType = ''
    let s:allCount = 0
    let s:changenr = -1
    let s:currentReg = ""
    let s:currentRegType = ""
    let s:initcomplete = 0
endfun
call extract#clear()
" end local vars}}}

" Vars users can pick {{{
if !has_key(g:,"extract_maxCount")
    let g:extract_maxCount = 5
endif

if !has_key(g:,"extract_defaultRegister")
    let g:extract_defaultRegister = '0'
endif

if !has_key(g:,"extract_ignoreRegisters")
    let g:extract_ignoreRegisters = ['a', '.']
endif

if !has_key(g:,"extract_useDefaultMappings")
    let g:extract_useDefaultMappings = 1
endif

" end vars}}}

" Yanked, extract it out {{{
autocmd TextYankPost * call extract#YankHappened(v:event)

func! extract#YankHappened(event)
    if count(g:extract_ignoreRegisters,  split(a:event['regname'])) > 0 
        return
    endif

    call s:addToList(a:event)
endfunc

func! extract#echo()
    echom string(s:all)
endfun

func! extract#echoType()
    echom string(s:allType)
endfun

func! s:addToList(event)
    " Add to register IF it doesn't already exist
    if count(s:all, a:event['regcontents']) == len(a:event['regcontents'])
        let l:index = index(s:all, a:event['regcontents'])
        call remove(s:all, l:index)
        call remove(s:allType, l:index)
        let s:allCount = s:allCount - 1
    endif

    let s:all = add(s:all, (a:event['regcontents']))
    let s:allType = add(s:allType, (a:event['regtype']))

    if s:allCount > (g:extract_maxCount - 1)
        call remove(s:all, 0)
        call remove(s:allType, 0)
    else
        let s:allCount = s:allCount + 1
        let s:extractAllDex = s:allCount - 1
    endif
endfunc

" end yank and add }}}

func! s:saveReg(reg) "{{{
    let s:lastUsedReg = a:reg
    let s:currentRegType = getregtype(g:extract_defaultRegister)
    let s:currentReg     = getreg(g:extract_defaultRegister, 1, 1)
    let s:lastType       = getregtype(g:extract_defaultRegister)
    if s:currentRegType != 'v'
        let s:specialType = s:currentRegType
    else
        let s:specialType = ''
    endif
endfun "}}}

func! extract#regPut(cmd, reg) "{{{
    " save cmd used
    let s:currentCmd = a:cmd


    " check if we need to put something new
    call s:addToList({'regcontents': getreg(a:reg, 1, 1), 'regtype' : getregtype(a:reg)})
    call s:saveReg(s:all[s:extractAllDex])

    call setreg(g:extract_defaultRegister, s:all[s:extractAllDex], s:allType[s:extractAllDex])

    call extract#put()
endfun "}}}

func! extract#put() "{{{
    " put from our reg
    exe "norm! \"". g:extract_defaultRegister . s:currentCmd

    " restore reg
    call setreg(g:extract_defaultRegister, s:currentReg, s:currentRegType)

    " save new change
    let s:changenr = changenr()
endfunc "}}}

func! extract#cycle(inc) "{{{
    if s:allCount < 2 || s:changenr != changenr()
        return
    endif


    " Update index, loop if neg or count
    let s:extractAllDex = s:extractAllDex + a:inc

    if s:extractAllDex < 0
        let s:extractAllDex = s:allCount - 1
    elseif s:extractAllDex > s:allCount - 1
        let s:extractAllDex = 0
    endif

    call s:saveReg(s:all[s:extractAllDex])
    call setreg(g:extract_defaultRegister, s:all[s:extractAllDex], s:allType[s:extractAllDex])

    silent! undo

    if s:doDelete
        exe s:currentRange[0]. ',' . s:currentRange[1] . 'delete'
        norm! k
    endif

    call extract#put()
endfunc "}}}

func! extract#cyclePasteType() "{{{
    if s:changenr != changenr()
        return
    endif

    if s:lastType ==# 'v'
        let s:lastType = 'V'
    elseif s:lastType ==# 'V'
        let s:lastType = s:specialType
    else
        let s:lastType = 'v'
    endif

    call setreg(g:extract_defaultRegister, s:lastUsedReg, s:lastType)

    silent! undo

    call extract#put()

endfun "}}}

func! extract#complete(cmd, isRegisterComplete) " {{{
    " save stuff
    let s:currentCmd = a:cmd
    let s:doDelete = 0
    let s:isRegisterCompleteType = a:isRegisterComplete

    " init blank list
    let words = []

    " if register...
    if a:isRegisterComplete
        " get the contents
        redir => s:com
        silent! reg
        redir END
        let lol = split(s:com, "\n")
        let l:ind = -1
        " ignore first line, the rest parse
        for s in lol
            let l:ind = l:ind + 1
            if l:ind == 0
                continue
            endif
            let kind = strpart(s, 1, 2)
            let type = getregtype(kind)
            if count(g:extract_ignoreRegisters,  split(kind)) > 0
                continue
            endif
            let word = getreg(kind, 1, 1)
            let i2 = -1

            " remove extra whitespace for multiple lines
            let finalwords = []

            for w in word
                let i2 = i2 + 1
                if i2 == 0
                    call add(finalwords,w)
                    continue
                endif
                call add(finalwords,substitute(w, '^\s\+\|\s\+$', "@", "g"))
            endfor
            " finally add to words for completion
            call add(words,{'empty': 1, 'menu': '['. getregtype(kind) . ' '. len(finalwords) .' ]', 'kind' : kind, 'word' : strpart((join(finalwords, '')), 0, winwidth('.') / 2 )})
        endfor
    " if we are list and we aren't empty
    elseif s:allCount > 0
        let l:ind = -1
        " loop and add items with index
        for x in s:all
            let l:ind = l:ind + 1
            call add(words, {'empty': 1, 'kind': l:ind, 'menu': '['.s:allType[l:ind]. ' '. len(s:all[l:ind]) .']', 'word': strpart(join(s:all[l:ind]),0, winwidth('.')/2)})
        endfor
        let words = reverse(words)
    else
        return ""
    endif

    " with words, complete at current positon, init complete for autocmd, and
    " return '' so we don't insert anything.
    call complete(col('.'), words)
    let s:initcomplete = 1
    return ''
endfun "}}}

func! extract#UnComplete() "{{{
    " if we aren't init we didn't do the complete bail
    if !s:initcomplete
        return
    endif

    " if we did do the complete let us know not to do this again
    " init put with cmd and reg name
    let k = v:completed_item['kind']
    let s:initcomplete = 0

    " if we are characther wise there and we only have 1 line, just do as is.
    if strpart(v:completed_item['menu'],1,1) ==# 'v' && strpart(v:completed_item['menu'],3,1) ==# '1'
        return
    endif

    " if we are registers use them, if we are the list, use index
    if s:isRegisterCompleteType
        call s:saveReg(k)
        call setreg(g:extract_defaultRegister, getreg(k,1,1), getregtype(k))
    else
        call s:saveReg(s:all[str2nr(k)])
        call setreg(g:extract_defaultRegister, s:all[str2nr(k)], s:allType[str2nr(k)])
    endif

    " undo the complete...
    norm! u

    " and put the results!
    call extract#put()
endfun
autocmd CompleteDone * :call extract#UnComplete() "}}}

" Commands and mapping {{{
" helpers
com! -nargs=1 ExtractPut call extract#regPut(<q-args>[0], v:register) | let s:doDelete = 0
com! -nargs=1 ExtractSycle call extract#cycle(<q-args>)
com! -nargs=0 ExtractCycle call extract#cyclePasteType()
com! -range -nargs=1 ExtractPutVisual let s:changenr = changenr() | let s:currentCmd = <q-args>[0] | let s:currentRange = [<line1>, <line2>] | let s:doDelete = visualmode() ==# 'V'
com! -nargs=0 ExtractClear call extract#clear()

" norm put
nnoremap <expr><Plug>(extract-put) ':ExtractPut p<cr>'
nnoremap <expr><Plug>(extract-Put) ':ExtractPut P<cr>'

" visual put
vnoremap <Plug>(extract-put) p:extractPutVisual p<cr>
vnoremap <Plug>(extract-Put) P:extractPutVisual P<cr>

" norm and visual cycle
noremap <expr><Plug>(extract-sycle) ':ExtractSycle 1<cr>'
noremap <expr><Plug>(extract-Sycle) ':ExtractSycle -1<cr>'
noremap <expr><Plug>(extract-cycle) ':ExtractCycle<cr>'

" completion put and cycle if use mess up
inoremap <Plug>(extract-completeReg) <c-g>u<C-R>=extract#complete('gP',1)<cr>
inoremap <Plug>(extract-completeList) <c-g>u<C-R>=extract#complete('gP',0)<cr>
inoremap <Plug>(extract-sycle) <esc>:ExtractSycle 1<cr>a
inoremap <Plug>(extract-Sycle) <esc>:ExtractSycle -1<cr>a
inoremap <Plug>(extract-cycle) <esc>:ExtractCycle<cr>a

" Default mappings {{{
if g:extract_useDefaultMappings
    " mappings for putting
    nmap p <Plug>(extract-put)
    nmap P <Plug>(extract-Put)

    " mappings for cycling
    map s <Plug>(extract-sycle)
    map S <Plug>(extract-Sycle)
    map <c-s> <Plug>(extract-cycle)

    " mappings for visual
    vmap p <Plug>(extract-put)
    vmap P <Plug>(extract-Put)

    " mappings for insert
    imap <m-v> <Plug>(extract-completeReg)
    imap <c-v> <Plug>(extract-completeList)
    imap <c-s> <Plug>(extract-cycle)
    imap <m-s> <Plug>(extract-sycle)
    imap <m-S> <Plug>(extract-Sycle)

endif "}}}

"end Commands and Mapping }}}
