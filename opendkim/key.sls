# -*- coding: utf-8 -*-
# vim: ft=sls

include:
  - opendkim.install
  - opendkim.service

{% from "opendkim/map.jinja" import opendkim with context %}
{% set user, group = opendkim.conf.UserID.split(':') %}

{% set keys = opendkim.privateKey.get('key', {}) %}
{% set genkeys = opendkim.privateKey.get('genkey', {}) %}
{% set domains = keys.keys() | list + genkeys.keys() | list %}

{% for domainName in domains %}
{{ opendkim.privateKey.directory }}/{{ domainName }}/:
  file.directory:
    - makedirs: true
    - mode: 750
    - user: {{ user }}
    - group: {{ group }}
    - watch_in:
      - service: opendkim_service
    - require:
      - pkg: opendkim_packages
{% endfor %}

{% for domainName, domain in keys.items() %}

  {% for selector, key in domain.items() %} 

{{ opendkim.privateKey.directory }}/{{ domainName }}/{{ selector }}.private:
  file.managed:
    - mode: 600
    - user: {{ user }} 
    - group: {{ group}}
    - makedirs: True
    - contents: |
        {{ key | indent(8) }} 
    - watch_in:
      - service: opendkim_service
    - require:
      - pkg: opendkim_packages

  {% endfor %}

{% endfor %}

{% if genkeys %}
opendkim-genkey:
  pkg.installed:
    - name: {{ opendkim.genkey_pkg }}
{% endif %}

{% for domainName, domain in genkeys.items() %}

  {% if domainName not in keys %}
    {% do keys.update({ domainName: {} }) %}
  {% endif %}

  {% for selector in domain %} 
    {% do keys.get(domainName).update({selector: ''}) %}
    {% set file = opendkim.privateKey.directory ~ '/' ~  domainName ~ '/' ~ selector ~ '.private' %}
{{ file }}:
  cmd.run:
    - name: opendkim-genkey -s {{ selector }} -d {{ domainName }} -D {{ opendkim.privateKey.directory }}/{{ domainName }}
    - unless:
      - test -f {{ file }}
    - watch_in:
      - service: opendkim_service
    - require:
      - pkg: opendkim_packages
      - pkg: opendkim-genkey

  {% endfor %}

{% endfor %}

{% if 'manageKeyTable' in opendkim and 'KeyTable' in opendkim.conf and opendkim.manageKeyTable == true %}

{{ opendkim.conf.KeyTable }}:
  file.managed:
    - mode: 640
    - source: salt://opendkim/files/KeyTable.tmpl
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - template: 'jinja'
    - backup: minion
    - context:
        key: {{ keys }}
        keyDirectory: {{ opendkim.privateKey.directory }}
        KeyTable: {{ opendkim.conf.KeyTable }}
    - watch_in:
      - service: opendkim_service
    - require:
      - pkg: opendkim_packages

{% endif %}

{% if 'manageSigningTable' in opendkim and 'SigningTable' in opendkim.conf and opendkim.manageSigningTable == true %}

{%- if ':' in opendkim.conf.SigningTable %}
{%- set type, filePath = opendkim.conf.SigningTable.split(':') %}
{%- else %}
{%- set filePath = opendkim.conf.SigningTable %}
{%- endif %}
{{ filePath }}:
  file.managed:
    - mode: 640
    - source: salt://opendkim/files/SigningTable.tmpl
    - user: {{ user }}
    - group: {{ group }}
    - makedirs: True
    - template: 'jinja'
    - backup: minion
    - context:
        type: {{ type | default('') }}
        key: {{ keys }}
        keyDirectory: {{ opendkim.privateKey.directory }}
        SigningTable: {{ opendkim.conf.SigningTable }}
    - watch_in:
      - service: opendkim_service
    - require:
      - pkg: opendkim_packages

{% endif %}

