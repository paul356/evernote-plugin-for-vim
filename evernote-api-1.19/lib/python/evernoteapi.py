import sys
sys.path.append('/home/hp-user/box/evernote-api-1.19/lib/python')

import hashlib
import binascii
import time
import thrift.protocol.TBinaryProtocol as TBinaryProtocol
import thrift.transport.THttpClient as THttpClient
import evernote.edam.userstore.UserStore as UserStore
import evernote.edam.userstore.constants as UserStoreConstants
import evernote.edam.notestore.NoteStore as NoteStore
import evernote.edam.type.ttypes as Types
import evernote.edam.error.ttypes as Errors

username = 'test356'
password = 'test356'
debugLogging = False

#
# NOTE: You must change the consumer key and consumer secret to the 
#       key and secret that you received from Evernote
#
consumerKey = "paul356"
consumerSecret = "5a581ee7624a0e13"

evernoteHost = "sandbox.evernote.com"
userStoreUri = "https://" + evernoteHost + "/edam/user"
noteStoreUriBase = "https://" + evernoteHost + "/edam/note/"

class UserAuth:
    def __init__(self, user, key):
        self.username = user
        self.password = key

    def getUserStore(self):
        userStoreHttpClient = THttpClient.THttpClient(userStoreUri)
        userStoreProtocol = TBinaryProtocol.TBinaryProtocol(userStoreHttpClient)
        self.userStore = UserStore.Client(userStoreProtocol)

    def checkVersion(self):
        versionOK = self.userStore.checkVersion("Python EDAMTest",
                                                UserStoreConstants.EDAM_VERSION_MAJOR,
                                                UserStoreConstants.EDAM_VERSION_MINOR)
        if not versionOK:
            print "Is my EDAM protocol version up to date? ", str(versionOK)
        return versionOK

    def authenticateUser(self):
        # Authenticate the user
        if not hasattr(self, "userStore"):
            self.getUserStore()
            if not self.checkVersion():
                return None
        try :
            authResult = self.userStore.authenticate(self.username, self.password,
                                                     consumerKey, consumerSecret)
            return authResult
        except Errors.EDAMUserException as e:
            parameter = e.parameter
            errorCode = e.errorCode
            errorText = Errors.EDAMErrorCode._VALUES_TO_NAMES[errorCode]
            
            print "Authentication failed (parameter: " + parameter + " errorCode: " + errorText + ")"
            
            if errorCode == Errors.EDAMErrorCode.INVALID_AUTH:
                if parameter == "consumerKey":
                    print "Your consumer key was not accepted by", evernoteHost
                    print "This sample client application requires a client API key."
                    print "If you requested a web service API key, you must authenticate using OAuth."
                elif parameter == "username":
                    print "You must authenticate using a username and password from", evernoteHost
                elif parameter == "password":
                    print "The password that you entered is incorrect"

            print ""
            return None

def getNoteStore(userShardId):
    noteStoreUri        = noteStoreUriBase + userShardId
    noteStoreHttpClient = THttpClient.THttpClient(noteStoreUri)
    noteStoreProtocol   = TBinaryProtocol.TBinaryProtocol(noteStoreHttpClient)
    noteStore = NoteStore.Client(noteStoreProtocol)
    return noteStore
