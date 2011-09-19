import sys
sys.path.append('evernote-api-1.19/lib/python/')
import os.path
import evernote.edam.notestore.NoteStore as NoteStore
import evernote.edam.type.ttypes as Types
import evernote.edam.error.ttypes as Errors
#import vim
from evernoteapi import *

userShardId = ''
authToken   = ''
evernoteBufferName = '__EVERNOTE_LIST__'

authFilePath = '/tmp/.evernote_auth'
if (False):#os.path.exists(authFilePath)):
    authFile = open(authFilePath, "rb")
    userShardId = authFile.readline()
    authToken   = authFile.readline()
else:
    userAuth = UserAuth(username, password)
    authResult = userAuth.authenticateUser()
    if (authResult == None):
        print "Authentication fail for ", user.username
        exit(1);

    user = authResult.user
    authToken = authResult.authenticationToken

    authFile = open(authFilePath, "wb")
    authFile.write(user.shardId + "\n")
    authFile.write(authToken + "\n")
    authFile.close()
    userShardId = user.shardId
    authToken   = authResult.authenticationToken

noteStore = getNoteStore(userShardId)

notebooks = noteStore.listNotebooks(authToken)
if debugLogging:
    print "Found ", len(notebooks), " notebooks:"
allNotes = []
for notebook in notebooks:
    if debugLogging:
        print "  * ", notebook.name
#vim.command()

    filter = NoteStore.NoteFilter()
    filter.notebookGuid = notebook.guid
    noteLst = noteStore.findNotes(authToken, filter, 0, 200)
    for note in noteLst.notes:
        if debugLogging:
            print "------------  title  -------------"
            print note.title
            print "------------ content -------------"
            print note.content
        allNotes.append(note)

#vim.command('leftabove vertical split ' + evernoteBufferName)
#vim.buffers[-1][0] = allNotes[0].title
#for note in allNotes[1:]:
#    vim.buffers[-1].append(note.title)


# print
# print "Creating a new note in default notebook: ", defaultNotebook.name
# print
#  Create a note with one image resource in it ...
# image = open('enlogo.png', 'rb').read()
# md5 = hashlib.md5()
# md5.update(image)
# hash = md5.digest()
# hashHex = binascii.hexlify(hash)
# 
# data = Types.Data()
# data.size = len(image)
# data.bodyHash = hash
# data.body = image
# 
# resource = Types.Resource()
# resource.mime = 'image/png'
# resource.data = data
# 
# note = Types.Note()
# note.title = "Test note from EDAMTest.py"
# note.content = '<?xml version="1.0" encoding="UTF-8"?>'
# note.content += '<!DOCTYPE en-note SYSTEM "http://xml.evernote.com/pub/enml2.dtd">'
# note.content += '<en-note>Here is the Evernote logo:<br/>'
# note.content += '<en-media type="image/png" hash="' + hashHex + '"/>'
# note.content += '</en-note>'
# note.resources = [ resource ]
# 
# createdNote = noteStore.createNote(authToken, note)
# print "Successfully created a new note with GUID: ", createdNote.guid

