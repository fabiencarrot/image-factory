#!/usr/bin/env python
import os

def get_env_creds():
    return {
        'username': os.environ['OS_USERNAME'],
        'password': os.environ['OS_PASSWORD'],
        'auth_url': os.environ['OS_AUTH_URL'],
        'tenant_name': os.environ['OS_TENANT_NAME']
    }
