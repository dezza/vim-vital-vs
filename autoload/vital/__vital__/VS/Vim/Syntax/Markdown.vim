function! s:apply(...) abort
  if !exists('b:___VS_Vim_Syntax_Markdown')
    call s:_execute('runtime! syntax/markdown.vim')

    " We manually apply fenced code block
    syntax clear markdownCode
    syntax clear markdownEscape

    " Add syntax for basic html entities.
    syntax match vital_vs_vim_syntax_markdown_entities_lt /&lt;/ containedin=ALL conceal cchar=<
    syntax match vital_vs_vim_syntax_markdown_entities_gt /&gt;/ containedin=ALL conceal cchar=>
    syntax match vital_vs_vim_syntax_markdown_entities_amp /&amp;/ containedin=ALL conceal cchar=&
    syntax match vital_vs_vim_syntax_markdown_entities_quot /&quot;/ containedin=ALL conceal cchar="
    syntax match vital_vs_vim_syntax_markdown_entities_nbsp /&nbsp;/ containedin=ALL conceal cchar=\ 

    " Ignore possible escape chars (https://github.github.com/gfm/#example-308)
    for l:char in split('!"#$%&()*+,-.g:;<=>?@[]^_`{|}~' . "'", '\zs')
      execute printf('syntax match vital_vs_vim_syntax_markdown_escape_%s /[^\\]\?\zs\\\V%s/ conceal cchar=%s containedin=ALL',
      \   l:char,
      \   l:char,
      \   l:char,
      \ )
    endfor
    syntax match vital_vs_vim_syntax_markdown_escape_escape /[^\\]\\\\/ conceal cchar=\ containedin=ALL

    let b:___VS_Vim_Syntax_Markdown = {}
  endif

  let l:bufnr = bufnr('%')
  try
    for [l:mark, l:filetype] in items(s:_get_filetype_map(l:bufnr, get(a:000, 0, {})))
      let l:group = substitute(toupper(l:mark), '\.', '_', 'g')
      if has_key(b:___VS_Vim_Syntax_Markdown, l:group)
        continue
      endif
      let b:___VS_Vim_Syntax_Markdown[l:group] = v:true

      try
        call s:_execute('syntax include @%s syntax/%s.vim', l:group, l:filetype)
        call s:_execute('syntax region %s matchgroup=Conceal start=/%s/rs=e matchgroup=Conceal end=/%s/re=s contains=@%s containedin=TOP keepend concealends',
        \   l:group,
        \   printf('```%s\s*', l:mark),
        \   '```\s*\%(\s\|' . "\n" . '\|$\)',
        \   l:group
        \ )
      catch /.*/
        unsilent echomsg printf('[VS.Vim.Syntax.Markdown] The `%s` is not valid filetype! You can add `"let g:markdown_fenced_languages = ["FILETYPE=%s"]`.', l:mark, l:mark)
      endtry
    endfor
  catch /.*/
    unsilent echomsg string({ 'exception': v:exception, 'throwpoint': v:throwpoint })
  endtry
endfunction

"
"  _execute
"
function! s:_execute(command, ...) abort
  let b:current_syntax = ''
  unlet b:current_syntax

  let g:main_syntax = ''
  unlet g:main_syntax

  execute call('printf', [a:command] + a:000)
endfunction

"
" _get_filetype_map
"
function! s:_get_filetype_map(bufnr, filetype_map) abort
  let l:filetype_map = {}
  for l:mark in s:_find_marks(a:bufnr)
    let l:filetype_map[l:mark] = s:_get_filetype_from_mark(l:mark, a:filetype_map)
  endfor
  return l:filetype_map
endfunction

"
" _find_marks
"
function! s:_find_marks(bufnr) abort
  let l:marks = {}

  " find from buffer contents.
  let l:text = join(getbufline(a:bufnr, '^', '$'), "\n")
  let l:pos = 0
  while 1
    let l:match = matchlist(l:text, '```\s*\(\w\+\)', l:pos, 1)
    if empty(l:match)
      break
    endif
    let l:marks[l:match[1]] = v:true
    let l:pos = matchend(l:text, '```\s*\(\w\+\)', l:pos, 1)
  endwhile

  return keys(l:marks)
endfunction

"
" _get_filetype_from_mark
"
function! s:_get_filetype_from_mark(mark, filetype_map) abort
  for l:config in get(g:, 'markdown_fenced_languages', [])
    if l:config !~# '='
      if l:config ==# a:mark
        return a:mark
      endif
    else
      let l:config = split(l:config, '=')
      if l:config[1] ==# a:mark
        return l:config[0]
      endif
    endif
  endfor
  return get(a:filetype_map, a:mark, a:mark)
endfunction

