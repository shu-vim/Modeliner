vim9script

# Modeliner
#
# Version: 0.3.0
# Description:
#
#   Generates a modeline from current settings. 
#
# Last Change: 27-Jun-2008.
# Maintainer: Shuhei Kubota <chimachima@gmail.com>
#
# Usage:
#   execute ':Modeliner'.
#   Then a modeline is generated.
#
#   The modeline will either be appended next to the current line or replace
#   the existing one.
#
#   If you want to customize option, modify g:Modeliner_format.

if !exists('g:Modeliner_format')
    var g:Modeliner_format = 'et ff= sts= sw= ts='
    # /[ ,:]/ delimited.
    #
    # if the type of a option is NOT 'boolean' (see :help 'option-name'),
    # append '=' to the end of each option.
endif


#[text] vi: tw=80 noai
#[text]	vim:tw=80 noai
# ex:tw=80 : noai:
#
#[text] vim: set tw=80 noai:[text]
#[text] vim: se tw=80 noai:[text]
#[text] vim:set tw=80 noai:[text]
# vim: set tw=80 noai: [text]
# vim:se tw=80 noai:


command! Modeliner  call <SID>Modeliner_execute()


# to retrieve the position
var Modeline_SEARCH_PATTERN = '\svi:\|vim:\|ex:'
# to extract options from existing modeline
var Modeline_EXTRACT_PATTERN = '\v(.*)\s+(vi|vim|ex):\s*(set?\s+)?(.+)' # very magic
# first form
#let s:Modeline_EXTRACT_OPTPATTERN1 = '\v(.+)' # very magic
# second form
var Modeline_EXTRACT_OPTPATTERN2 = '\v(.+):(.*)' # very magic


def Modeliner_execute()
    var options = []

    # find existing modeline, and determine the insert position
    var info = s:SearchExistingModeline()

    # parse g:Modeliner_format and join options with them
    var extractedOptStr = g:Modeliner_format .. ' ' .. info.optStr
    extractedOptStr = substitute(extractedOptStr, '[ ,:]\+', ' ', 'g')
    extractedOptStr = substitute(extractedOptStr, '=\S*', '=', 'g')
    extractedOptStr = substitute(extractedOptStr, 'no\(.\+\)', '\1', 'g')
    var opts = sort(split(extractedOptStr))
    #echom 'opt(list): ' .. join(opts, ', ')

    var optStr = ''
    var prevO = ''
    for o in opts
        if o == prevO | continue | endif
        prevO = o

        var optExpr: any
        if stridx(o, '=') != -1
            # let optExpr = 'ts=' . &ts
            #execute 'var optExpr = "' .. o .. '" .. &' .. strpart(o, 0, strlen(o) - 1)
            optExpr = o .. eval('&' .. strpart(o, 0, strlen(o) - 1))
        else
            # let optExpr = (&et ? '' : 'no') . 'et'
            #execute 'var optExpr = (&' .. o .. ' ? "" : "no") .. "' .. o .. '"'
            var v = eval('&' .. o)
            optExpr = (v ? '' : 'no') .. o
        endif

        optStr = optStr .. ' ' .. optExpr
    endfor

    var modeline: string
    if info.lineNum == 0
        modeline = s:Commentify(optStr)
    else
        modeline = info.firstText .. ' vim: set' .. optStr .. ' :' .. info.lastText
    endif


    # insert new modeline 
    if info.lineNum != 0
        #modeline FOUND -> replace the modeline

        #show the existing modeline
        var orgLine = line('.')
        var orgCol  = col('.')
        call cursor(info.lineNum, 1)
        normal V
        redraw

        #confirm
        #if confirm('Are you sure to overwrite this existing modeline?', "&Yes\n&No", 1) == 1
        echo 'Are you sure to overwrite this existing modeline? [y/N]'
        if char2nr(tolower(nr2char(getchar()))) == char2nr('y')
            call setline(info.lineNum, modeline)

            #show the modeline being changed
            if (info.lineNum != line('.')) && (info.lineNum != line('.') + 1)
                redraw
                sleep 1
            endif
        endif

        #back to the previous position
        echo
        execute "normal \<ESC>"
        call cursor(orgLine, orgCol)
    else
        #modeline NOT found -> append new modeline
        call append('.', modeline)
    endif

enddef


def Commentify(s: string): string
    var result: string
	var commentstring = &commentstring
	if len(commentstring) == 0
		commentstring = '%s'
	endif
    if exists('g:NERDMapleader') # NERDCommenter
        result = b:left .. ' vim: set' .. s .. ' : ' .. b:right
    else
        result = substitute(commentstring, '%s', ' vim: set' .. s .. ' : ', '')
    endif

    return result
enddef


def SearchExistingModeline(): dict<any>
    var info = {'lineNum': 0, 'text': '', 'firstText': '', 'lastText': '', 'optStr': ''}

    var candidates = []

    # cursor position?
    call add(candidates, line('.'))
    # user may position the cursor to previous line...
    call add(candidates, line('.') + 1)
    var cnt = 0
    while cnt < &modelines
    # header?
        call add(candidates, cnt + 1)
    # footer?
        call add(candidates, line('$') - cnt)
        cnt = cnt + 1
    endwhile

    # search
    for i in candidates
        var lineNum = i
        var text = getline(lineNum)

        if match(text, s:Modeline_SEARCH_PATTERN) != -1
            info.lineNum = lineNum
            info.text = text
            break
        endif
    endfor

    # extract texts
    if info.lineNum != 0
        #echom 'modeline: ' info.lineNum . ' ' . info.text

        info.firstText = substitute(info.text, s:Modeline_EXTRACT_PATTERN, '\1', '')

        var isSecondForm = (strlen(substitute(info.text, s:Modeline_EXTRACT_PATTERN, '\3', '')) != 0)
        #echom 'form : ' . string(isSecondForm + 1)
        if !isSecondForm
            info.lastText = ''
            info.optStr = substitute(info.text, s:Modeline_EXTRACT_PATTERN, '\4', '')
        else
            info.lastText = substitute(
                            \ substitute(info.text, s:Modeline_EXTRACT_PATTERN, '\4', ''),
                            \ s:Modeline_EXTRACT_OPTPATTERN2,
                            \ '\2',
                            \ '')
            info.optStr = substitute(
                                \ substitute(info.text, s:Modeline_EXTRACT_PATTERN, '\4', ''),
                                \ s:Modeline_EXTRACT_OPTPATTERN2,
                                \ '\1',
                                \ '')
        endif
    endif

    #echom 'firstText: ' . info.firstText
    #echom 'lastText: ' . info.lastText
    #echom 'optStr: ' . info.optStr

    return info
enddef


def ExtractOptionStringFromModeline(text: string)
    var info = {}

    info.firstText = substitute(text, s:Modeline_EXTRACT_PATTERN, '\1', '')

    var isSecondForm = (strlen(substitute(text, s:Modeline_EXTRACT_PATTERN, '\3', '') != 0)
    if isSecondForm == 0
        info.lastText = ''
        info.optStr = substitute(text, s:Modeline_EXTRACT_PATTERN, '\2', '')
    else
        info.lastText = substitute(
                        \ substitute(text, s:Modeline_EXTRACT_PATTERN, '\4', ''),
                        \ s:Modeline_EXTRACT_OPTPATTERN2,
                        \ '\2',
                        \ '')
        info.optStr = substitute(
                            \ substitute(text, s:Modeline_EXTRACT_PATTERN, '\4', ''),
                            \ s:Modeline_EXTRACT_OPTPATTERN2,
                            \ '\1',
                            \ '')
    endif

    return info
enddef

# vim: set noet ft=vim sts=4 sw=4 ts=4 tw=78 : 
