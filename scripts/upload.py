#!/usr/bin/python2.7

import httplib2
import sys

from apiclient.discovery import build
from apiclient.errors import HttpError
from apiclient.http import MediaFileUpload
from oauth2client.client import OAuth2WebServerFlow
from oauth2client.client import FlowExchangeError

CLIENT_ID = '707426582080-ler3q9hme33cpk9smr5pvr93cmausetr.apps.googleusercontent.com'
CLIENT_SECRET = 'N0uGKcj4ofQXrLt1lVZUXK21'

OAUTH_SCOPE = 'https://www.googleapis.com/auth/drive'
REDIRECT_URI = 'urn:ietf:wg:oauth:2.0:oob'

# Run through the OAuth flow and retrieve credentials
flow = OAuth2WebServerFlow(CLIENT_ID, CLIENT_SECRET, OAUTH_SCOPE, redirect_uri=REDIRECT_URI)
authorize_url = flow.step1_get_authorize_url()
print 'Open a browser and visit: ' + authorize_url
code = raw_input('Enter verification code: ').strip()
try:
  credentials = flow.step2_exchange(code)
except FlowExchangeError:
  print 'Invalid verification code. Exiting.'
  exit(1)

# Create an httplib2.Http object and authorize it with our credentials
http = httplib2.Http()
http = credentials.authorize(http)

drive_service = build('drive', 'v2', http=http)

title = raw_input('Enter a title: ').strip()
description = raw_input('Enter a description: ').strip()

# Insert a file
filename = sys.argv[1]
media_body = MediaFileUpload(filename, mimetype='application/octet-stream', resumable=True)
body = {
  'title': title,
  'description': description,
  'mimeType': 'application/octet-stream'
}

try:
  file = drive_service.files().insert(body=body, media_body=media_body).execute()
  print 'File uploaded successfully. Exiting.' 
  exit(0)
except HttpError:
  print 'Upload failed. Exiting.'
  exit(1)
