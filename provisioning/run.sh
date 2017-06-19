#!/bin/sh

cd "$(dirname $0)"
ansible-playbook playbook.yml
