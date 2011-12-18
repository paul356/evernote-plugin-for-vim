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

userShardId = ''
authToken   = ''
notebooks   = []
# {'guid' => [notes in a notebook]}
allNotes    = {}
backRef     = {}
bufIdx      = -1
noteStore   = None
evernoteListName = '__EVERNOTE_LIST__'
evernoteNameTemplate = '__EVERNOTE_NOTE__ [%s]'

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
vim.command('setlocal buftype=nowrite')
vim.command('setlocal noreadonly')

del vim.current.buffer[0:len(vim.current.buffer)]
lineIdx = 1
for notebook in notebooks:
    if lineIdx != 1:
        vim.current.buffer.append("")
    vim.current.buffer.append("+- [" + notebook.name + "]")
    lineIdx += 2
    for note in allNotes[notebook.guid]:
        vim.current.buffer.append("|- <" + note.title + ">")
        backRef[lineIdx] = (notebook, note)
        lineIdx += 1
vim.command('setlocal readonly')
vim.command("nnoremap <buffer> <silent> <CR> :call <SID>open_note(line('.'))<CR>")
vim.command("nnoremap <buffer> <silent> r :call <SID>display_note_list()<CR>")
EOF
endfunction

function! s:open_note(lineNum)
python << EOF
hintLine = int(vim.eval("a:lineNum"))
if backRef.has_key(hintLine):
    (notebook, note) = backRef[hintLine]
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
    vim.command('setlocal buftype=nowrite')
    # set width of left window to 30
    vim.command('wincmd h')
    vim.command('vertical res 30')
    vim.command('wincmd l')
    currWin = vim.eval("winnr()")
    vim.command('let b:noteGuid = "' + note.guid + '"')

    del vim.current.buffer[0:len(vim.current.buffer)]
    lines = realNote.content.split('\n')
    content = "".join(lines)
    #print content
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
elif debugLogging:
    print "no back ref for %d" % hintLine
EOF
endfunction

function! s:update_note()
if !exists('b:noteGuid')
    print "This buffer is for evernote!!!"
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

call s:authenticate_user()
call s:get_note_list()
call s:display_note_list()
command! -nargs=0 -bar PushNote call s:update_note()

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

