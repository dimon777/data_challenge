'''
This module extracts files from SFTP srevre and uploads them to REST API
as end to end process without stiring data locally

Copyright (c) Dmitry Buzolin

TODO: Add standard logging
TODO: Explore pandas + dfply if more complex transformations would be required
'''

import os
import zipfile
from operator import attrgetter
import re
from io import BytesIO
import pysftp
import requests



FDICT = {'companies': {'|':','}, 'quartiles': {"'~'": ',', '#@#@#': '\n'}} # dict() to hold conversions for each file type
FTPHOST = 's-119de3726dda4e829.server.transfer.us-east-1.amazonaws.com' # SFTP host
FTPUSER = os.environ['FTPUSER']
FTPPASS = os.environ['FTPPASS']
PREFIX = '/data-ftp/datafeed' # prefix for files location on SFTP server
URL = f'https://u2h3nrk1sc.execute-api.us-east-1.amazonaws.com/dev/load?username={FTPUSER}&tablename={}' # REST API EP

def transform(adict, text):
    '''
    Performs quick and dirty transformation on the files in memory:
        - replaces field and line terminators to standard values from supplied dictionary
        - removes the fist row
        - relies on composite regexp substitution

    Args:
        file_path (str): name of the file on SFTP server.
        data_file (str): data file to extract from ZIP archive.

    Returns:
        str: latin-1 encoded string reprezenting extracted data file content.
    '''
    rec = re.compile("|".join(map(re.escape, adict.keys())))
    transformed_data = rec.sub(lambda match: adict[match.group(0)], text)
    return transformed_data[transformed_data.find('\n')+1:]


def rest_upload(url, data):
    '''
    Performs content upload to REST API, handles errors

    Args:
        url (str): REST API url
        data (str): latin-1 encoded string content. Note that it works event though
                    Binary file content is expected/required in the assigmnent.
                    bytearray(str) can be used to improve (sorry I don't have time for this :) ).

    Returns:
        str: request response object
    '''

    try:
        res = requests.post(
            url=url,
            data=data, #json.dumps(d),
            headers={'Content-Type': 'application/text'}
        )
    except ConnectionError as ex:
        print('Error connecting to REST backend, exiting...')
        raise ex
    except Exception as ex:
        print('Other error during REST API call', ex)
        raise ex
    return res


def main():
    ''' main() '''
    def get_file(file_path, data_file):
        '''
        Gets file path on SFTP servre, downloads, unzips and returns content
        as a dict {'name':'companies.txt','content':<str>}
        For large files this should be refactored to use generator

        Args:
            file_path (str): name of the file on SFTP server.
            data_file (str): data file to extract from ZIP archive.

        Returns:
            str: latin-1 encoded string reprezenting extracted data file content.

        TODO:
            Add exception handling for SFTP ops
        '''
        f_obj = BytesIO()
        sftp.getfo(file_path, f_obj)
        zip_file = zipfile.ZipFile(f_obj)
        uz_file = zip_file.read(data_file).decode('latin-1')
        return uz_file



   # Getting files from the SFTP server and store in dictionary object
    sftp = pysftp.Connection(FTPHOST, username=FTPUSER, password=FTPPASS)

    recent_files = {}
    with sftp.cd(PREFIX):
        attr = sftp.listdir_attr()
        for fname, _ in FDICT.items():
            all_files = [a for a in attr if a.filename.startswith(fname) and a.filename.endswith('zip')]
            latest_file = max(all_files, key=attrgetter('st_mtime'))
            recent_files[fname] = get_file(latest_file.filename, fname+'.txt')
    sftp.close()

    # Transforming files in memory and uploading to REST endpoint
    for fname, content in recent_files.items():
        tranformed_data = transform(FDICT.get(fname), content)
        res = rest_upload(URL.format(fname), tranformed_data)
        if res.status_code == 202:
            print(f'success uploading file: {fname}')
        elif res.status_code == 403:
            print(f'error during file upload: {fname}')


if __name__ == "__main__":
    main()
