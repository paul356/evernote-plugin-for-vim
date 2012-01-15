" initialization part
python << EOF
import sys
sys.path.append('evernote-api-1.19/lib/python/')
import os.path
import evernote.edam.notestore.NoteStore as NoteStore
import evernote.edam.type.ttypes as Types
import evernote.edam.error.ttypes as Errors
import vim
import re
from evernoteapi import *

noteStore   = None
userShardId = ''
authToken   = ''
notebooks   = []
defaultNotebook = None
# {'guid' => [notes in a notebook]}
allNotes    = {}
backRef     = {}
evernoteListName = '__EVERNOTE_LIST__'
evernoteNameTemplate = '__EVERNOTE_NOTE__ [%s]'

# evernote use xml to store note content
evernoteNoteTemaplateBegin = """<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">
<en-note>"""
evernoteNoteTemaplateEnd = """
</en-note>"""

def compatMark(markStr):
    str = [i for i in markStr if i != " " and i != "\n" and i != "\t"]
    return "".join(str)

def findNote(guid):
    for notebook in notebooks:
        for note in allNotes[notebook.guid]:
            if note.guid == guid:
                return note
    return None

def getNotebookByName(notebookName):
    for notebook in notebooks:
        if (notebookName == notebook.name):
            return notebook
    return None

def insertBackref(note):
    backKeys = backRef.keys()
    backKeys.sort()
    lastIdx = -1
    idx = 0
    ln = len(backKeys)
    while idx < ln:
        key = backKeys[idx]
        if backRef[key][0].guid == createdNote.notebookGuid:
            lastIdx = idx
        elif lastIdx != -1:
            break
        idx += 1
    print "last idx is %d" % lastIdx
    idx = ln-1
    while idx > lastIdx:
        backRef[backKeys[idx]+1] = backRef[backKeys[idx]]
        if not backRef.has_key(backKeys[idx]-1):
            del backRef[backKeys[idx]]
        idx -= 1
    backRef[backKeys[lastIdx]+1] = (backRef[backKeys[lastIdx]][0], createdNote)
EOF

function! g:dump_buffer()
python << EOF
i = 0
for line in vim.current.buffer:
    print "%d %s" % (i, line)
    i += 1
EOF
endfunction

" The authentication function
function! s:authenticate_user()
python << EOF
authFilePath = '/tmp/.evernote_auth'
userAuth = UserAuth(username, password)
authResult = userAuth.authenticateUser()
if (authResult == None):
    print "Authentication fail for " + user.username
    exit(1);

user = authResult.user
userShardId = user.shardId
authToken = authResult.authenticationToken

authFile = open(authFilePath, "wb")
authFile.write(user.shardId + "\n")
authFile.write(authToken + "\n")
authFile.close()
EOF
endfunction

" get the note list from evernote
function! s:get_note_list()
python << EOF
noteStore = getNoteStore(userShardId)

notebooks = noteStore.listNotebooks(authToken)
# Dictionary used to store notebooks.
# Take notebook guid as key, and allNotes[notebook.guid] is the list of notes.
allNotes  = {}
# backRef is the back reference from the line number to the note
# Take line number as key, and backRef[line] is a pair (pointer to note, pointer to notebook)
backRef   = {}
if debugLogging:
    print "Found %d notebooks:" % len(notebooks)
for notebook in notebooks:
    if debugLogging:
        print "  * " + notebook.name

    if notebook.defaultNotebook:
        defaultNotebook = notebook

    filter = NoteStore.NoteFilter()
    filter.notebookGuid = notebook.guid
    noteLst = noteStore.findNotes(authToken, filter, 0, 200)
    allNotes[notebook.guid] = [];
    for note in noteLst.notes:
        if debugLogging:
            print "------------  title  -------------"
            print note.title
            print "------------ content -------------"
            print note.content
        allNotes[notebook.guid].append(note)
EOF
endfunction

function! s:display_note_list()
python << EOF
if vim.current.buffer.name == None or not evernoteListName in vim.current.buffer.name:
    vim.command('leftabove vertical split ' + evernoteListName)
vim.command('set nowrap')
vim.command('vertical res 30')
vim.command('setlocal noswapfile')
vim.command('setlocal buftype=nowrite')
vim.command('setlocal noreadonly')

del vim.current.buffer[0:len(vim.current.buffer)]
lineIdx = 1
for notebook in notebooks:
    if lineIdx != 1:
        vim.current.buffer.append("")
    lineIdx += 1
    vim.current.buffer.append("+- [" + notebook.name + "]")
    backRef[lineIdx] = (notebook, None)
    lineIdx += 1
    for note in allNotes[notebook.guid]:
        vim.current.buffer.append("|- <" + note.title + ">")
        backRef[lineIdx] = (notebook, note)
        lineIdx += 1
vim.command('setlocal readonly')
vim.command("nnoremap <buffer> <silent> <CR> :call <SID>s:open_note(line('.'))<CR>")
vim.command("nnoremap <buffer> <silent> r :call <SID>s:display_note_list()<CR>")
EOF
endfunction

function! s:open_note(lineNum)
python << EOF
hintLine = int(vim.eval("a:lineNum"))
(notebook, note) = (None, None)
if backRef.has_key(hintLine):
    (notebook, note) = backRef[hintLine]
elif debugLogging:
    print "no back ref for %d" % hintLine

if (note == None):
    if notebook != None and debugLogging:
        print "line %d refer to a notebook" % hintLine
else:
    realNote = noteStore.getNote(authToken, note.guid, 1, 0, 0, 0)
    lastWin = vim.eval("winnr()")
    # see if exist a right window
    vim.command('wincmd l')
    currWin = vim.eval("winnr()")
    winName = evernoteNameTemplate % note.title
    if (lastWin == currWin):
        # no window to the right
        vim.command("rightbelow vertical split " + winName)
    else:
        vim.command('edit ' + winName)
    vim.command('setlocal noreadonly')
    vim.command('setlocal noswapfile')
    vim.command('setlocal buftype=nowrite')
    # set width of left window to 30
    vim.command('wincmd h')
    vim.command('vertical res 30')
    vim.command('wincmd l')
    # TODO: associate buffer with evernote
    currWin = vim.eval("winnr()")
    vim.command('let b:noteGuid = "' + note.guid + '"')

    del vim.current.buffer[0:len(vim.current.buffer)]
    lines = realNote.content.split('\n')
    content = "".join(lines)
    #print content
    # TODO: refactor the following code
    enNoteStart = re.search(r"<\s*en-note\s*>", content)
    content = content[enNoteStart.end():]
    matchIter = re.finditer(r"<[^>]*>", content)
    currLine = ""
    lastEnd  = 0
    firstLine = True
    for match in matchIter:
        #print match.group(0)
        compatMatch = compatMark(match.group(0))
        if compatMatch == "</en-note>":
            currLine += content[lastEnd:match.start()]
            if firstLine:
                vim.current.buffer[0] = currLine
                firstLine = False
            else:
                vim.current.buffer.append(currLine)
            break
        elif compatMatch == "</p>" or compatMatch == "<br/>" or compatMatch == "</li>":
            currLine += content[lastEnd:match.start()]
            if firstLine:
                vim.current.buffer[0] = currLine
                firstLine = False
            else:
                vim.current.buffer.append(currLine)
            #print currLine
            currLine  = ""
            lastEnd = match.end()
        else:
            currLine += content[lastEnd:match.start()]
            lastEnd = match.end()
EOF
endfunction

function! s:update_note()
if !exists('b:noteGuid')
    echo "ERROR: This document is not in evernote!"
endif
python << EOF
guid = vim.eval("b:noteGuid")
note = findNote(guid)
newNote = Types.Note()
newNote.guid = note.guid
newNote.title = note.title
content = ""
for line in vim.current.buffer:
    content += line + "<br/>"
newNote.content = evernoteNoteTemaplateBegin + content + evernoteNoteTemaplateEnd
noteStore.updateNote(authToken, newNote)
EOF
endfunction

function! s:add_note(...)
if exists('b:noteGuid')
    echo "ERROR: This document is already in evernote!"
    echo "ERROR: If you want to update it, use :UpdateNote"
endif
if a:0 >= 1
    let l:noteName=a:1
endif
if a:0 >= 2
    let l:notebookName=a:2
endif
python << EOF
title = ''
if vim.eval("exists(\"l:noteName\")"):
    title = vim.eval("l:noteName")
notebookName = ''
if vim.eval("exists(\"l:notebookName\")"):
    notebookName = vim.eval("l:notebookName")

# set title of new note
newNote = Types.Note()
if (title == ''):
    newNote.title = 'NewNote'
else:
    newNote.title = title

# get notebook for new note, or use default
if (notebookName != ''):
    notebook = getNotebookByName(notebookName)
    if notebook != None:
        newNote.notebookGuid = notebook.guid

# use content of current buffer as new note content
content = ""
for line in vim.current.buffer:
    content += line + "<br/>"
newNote.content = evernoteNoteTemaplateBegin + content + evernoteNoteTemaplateEnd
createdNote = noteStore.createNote(authToken, newNote)

# add new note's guid to backRef and allNotes
allNotes[createdNote.notebookGuid].append(createdNote)
insertBackref(createdNote)
vim.command("call s:display_note_list()")
EOF
endfunction

call s:authenticate_user()
call s:get_note_list()
call s:display_note_list()
command! -nargs=0 -bar UpdateNote call s:update_note()
command! -nargs=* -bar AddNote call s:add_note(<f-args>)

" print
" print "Creating a new note in default notebook: ", defaultNotebook.name
" print
"  Create a note with one image resource in it ...
" image = open('enlogo.png', 'rb').read()
" md5 = hashlib.md5()
" md5.update(image)
" hash = md5.digest()
" hashHex = binascii.hexlify(hash)
" 
" data = Types.Data()
" data.size = len(image)
" data.bodyHash = hash
" data.body = image
" 
" resource = Types.Resource()
" resource.mime = 'image/png'
" resource.data = data
" 
" note = Types.Note()
" note.title = "Test note from EDAMTest.py"
" note.content = '<?xml version="1.0" encoding="UTF-8"?>'
" note.content += '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">'
" note.content += '<en-note>Here is the Evernote logo:<br/>'
" note.content += '<en-media type="image/png" hash="' + hashHex + '"/>'
" note.content += '</en-note>'
" note.resources = [ resource ]
" 
" createdNote = noteStore.createNote(authToken, note)
" print "Successfully created a new note with GUID: ", createdNote.guid

