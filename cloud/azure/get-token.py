#!/usr/bin/env python3
#
# Call Azure API to get the access token for the application.
#
# Be sure to grant the VM permission to call our application via the role
# defined in the application registration.
#
# Set P4LOGINSSO="$(pwd)/get-token.py %ssoArgs%"
#
import argparse
import http.client
import json
import sys
import urllib


def main():
    '''Invoke Azure API to get access token.'''
    parser = argparse.ArgumentParser(description='Get access token.')
    parser.add_argument('--resource', help='URI of application resource', required=True)
    args = parser.parse_args()
    headers = {
        'Metadata': 'true'
    }
    params = urllib.parse.urlencode({
        'api-version': '2018-02-01',
        'resource': args.resource
    })
    url = '/metadata/identity/oauth2/token?' + params
    conn = http.client.HTTPConnection('169.254.169.254')
    conn.request('GET', url, headers=headers)
    resp = conn.getresponse()
    if resp.status == 200:
        try:
            obj = json.loads(resp.read())
            if 'access_token' in obj:
                print(obj['access_token'])
            else:
                print('response is lacking access_token')
                sys.exit(1)
        except json.decoder.JSONDecodeError:
            print('response did not parse as JSON')
            sys.exit(1)
    else:
        print('http error: ' + resp.reason)
        sys.exit(1)


if __name__ == '__main__':
    main()
