import sys
import os
from google.oauth2 import service_account
from googleapiclient.discovery import build
from googleapiclient.http import MediaFileUpload

def upload_file(file_path, folder_id, credentials_json):
    creds = service_account.Credentials.from_service_account_file(
        credentials_json, 
        scopes=['https://www.googleapis.com/auth/drive']
    )
    service = build('drive', 'v3', credentials=creds)

    file_metadata = {
        'name': os.path.basename(file_path),
        'parents': [folder_id]
    }
    
    media = MediaFileUpload(file_path, resumable=True)
    file = service.files().create(
        body=file_metadata,
        media_body=media,
        fields='id'
    ).execute()
    
    print(f"File ID: {file.get('id')}")

if __name__ == "__main__":
    upload_file(sys.argv[1], sys.argv[2], sys.argv[3])