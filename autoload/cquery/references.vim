let s:last_req_id = 0

function! s:get_server_name() abort
    let l:server_names = lsp#get_server_names()

    if count(l:server_names, 'cquery') > 0
        return 'cquery'
    elseif count(l:server_names, 'ccls') > 0
        return 'ccls'
    else
        throw 'cquery or ccls not found'
    endif
endfunction

function! s:request(server, method) abort
    call setqflist([])
    let s:last_req_id = s:last_req_id + 1

    let l:ctx = { 'counter': 1, 'list':[], 'last_req_id': s:last_req_id, 'jump_if_one': 0 }
    call lsp#send_request(a:server, {
        \ 'method': a:method,
        \ 'params': {
        \   'textDocument': lsp#get_text_document_identifier(),
        \   'position': lsp#get_position(),
        \ },
        \ 'on_notification': function('s:handle_location', [l:ctx, a:server, 'definition']),
        \ })

    echom 'Retrieving derived objects...'
endfunction

function! cquery#references#derived() abort
    let l:server = s:get_server_name()

    call s:request(l:server, 'textDocument/implementation')
endfunction

function! cquery#references#base() abort
    let l:server = s:get_server_name()

    if l:server ==# 'cquery'
        call s:request(l:server, '$cquery/base')
    elseif l:server ==# 'ccls'
        call s:request(l:server, '$ccls/inheritance')
    endif
endfunction

function! cquery#references#vars() abort
    let l:server = s:get_server_name()
    
    if l:server ==# 'cquery'
        call s:request(l:server, '$cquery/vars')
    elseif l:server ==# 'ccls'
        call s:request(l:server, '$ccls/vars')
    endif
endfunction

function! cquery#references#callers() abort
    let l:server = s:get_server_name()
    
    if l:server ==# 'cquery'
        call s:request(l:server, '$cquery/callers')
    elseif l:server ==# 'ccls'
        call s:request(l:server, '$ccls/call')
    endif
endfunction

function! s:error_msg(msg) abort
    echohl ErrorMsg
    echom a:msg
    echohl NONE
endfunction

function! s:handle_location(ctx, server, type, data) abort "ctx = {counter, list, jump_if_one, last_req_id}
    if a:ctx['last_req_id'] != s:last_req_id
        return
    endif

    let a:ctx['counter'] = a:ctx['counter'] - 1

    if lsp#client#is_error(a:data['response'])
        call s:error_msg('Failed to retrieve '. a:type . ' for ' . a:server)
    else
        let a:ctx['list'] = a:ctx['list'] + lsp#ui#vim#utils#locations_to_loc_list(a:data)
    endif

    if a:ctx['counter'] == 0
        if empty(a:ctx['list'])
            call s:error_msg('No ' . a:type .' found')
        else
            if len(a:ctx['list']) == 1 && a:ctx['jump_if_one']
                normal! m'
                let l:loc = a:ctx['list'][0]
                let l:buffer = bufnr(l:loc['filename'])
                let l:cmd = l:buffer !=# -1 ? 'b ' . l:buffer : 'edit ' . l:loc['filename']
                execute l:cmd . ' | call cursor('.l:loc['lnum'].','.l:loc['col'].')'
                redraw
            else
                call setqflist(a:ctx['list'])
                echom 'Retrieved ' . a:type
                botright copen
            endif
        endif
    endif
endfunction

