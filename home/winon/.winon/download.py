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

# Download list of the user's files
try:
  files = drive_service.files().list().execute()
except HttpError:
  print 'Unable to fetch file list. Exiting.'
  exit(1)

print 'Saved nyms:'
for i, f in enumerate(files['items']):
  print '\t' + str(i) + ': ' + f['title']
file_index = int(raw_input('Restore nym #: ').strip())

download_url = files['items'][file_index]['downloadUrl']
resp, content = drive_service._http.request(download_url)
if resp.status == 200:
  try:
    out_file = open(sys.argv[1], 'w')
    out_file.write(content)
    exit(0)
  except:
    exit(1)
else:
  exit(1)
  
