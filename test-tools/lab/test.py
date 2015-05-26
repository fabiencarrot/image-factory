#!/usr/bin/python

import os

from keystoneclient.auth.identity import v2
from keystoneclient import session
from novaclient import client

VERSION='2'

auth = v2.Password(auth_url=os.environ['OS_AUTH_URL'],
                   username=os.environ['OS_USERNAME'],
                   password=os.environ['OS_PASSWORD'],
                   tenant_name=os.environ['OS_TENANT_NAME']
)
sess = session.Session(auth=auth)

nova = client.Client(VERSION, session=sess)

print nova.servers.list()
