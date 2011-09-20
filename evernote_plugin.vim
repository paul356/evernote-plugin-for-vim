" initialization part
python << EOF
import sys
sys.path.append('evernote-api-1.19/lib/python/')
import os.path
import evernote.edam.notestore.NoteStore as NoteStore
import evernote.edam.type.ttypes as Types
import evernote.edam.error.ttypes as Errors
import vim
from evernoteapi import *

userShardId = ''
authToken   = ''
notebooks   = []
allNotes    = {}
backRef     = {}
bufIdx      = -1
noteStore   = None
evernoteBufferName = '__EVERNOTE_LIST__'
EOF

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

function! s:get_note_list()
python << EOF
noteStore = getNoteStore(userShardId)

notebooks = noteStore.listNotebooks(authToken)
allNotes  = {}
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
if not evernoteBufferName in vim.current.buffer.name:
    vim.command('leftabove vertical split ' + evernoteBufferName)
vim.command('set nowrap')
vim.command('vertical res 40')
vim.command('setlocal buftype=nofile')
vim.command('setlocal noswapfile')
vim.command('setlocal noreadonly')

del vim.current.buffer[0:len(vim.current.buffer)]
lineIdx = 1
for notebook in notebooks:
    if lineIdx != 1:
        vim.current.buffer.append("")
    vim.current.buffer.append("NOTEBOOK   [" + notebook.name + "]")
    lineIdx += 2
    for note in allNotes[notebook.guid]:
        vim.current.buffer.append("           <" + note.title + ">")
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
    vim.command('setlocal noreadonly')
    del vim.current.buffer[0:len(vim.current.buffer)]
    lines = realNote.content.split('\n')
    vim.current.buffer[0] = lines[0]
    for line in lines[1:]:
        vim.current.buffer.append(line)
    vim.command('setlocal readonly')
elif debugLogging:
    print "no back ref for %d" % hintLine
EOF
endfunction

call s:authenticate_user()
call s:get_note_list()
call s:display_note_list()

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

