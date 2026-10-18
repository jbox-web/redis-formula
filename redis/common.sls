{% from "redis/map.jinja" import redis_settings with context %}

{%-   if salt['grains.get']('osfinger', '') in ['Amazon Linux-2'] %}
redis_epel_repo:
  pkgrepo.managed:
    - name: epel
    - humanname: Extra Packages for Enterprise Linux 7 - $basearch
    - mirrorlist: https://mirrors.fedoraproject.org/metalink?repo=epel-7&arch=$basearch
    - enabled: 1
    - gpgcheck: 1
    - gpgkey: https://dl.fedoraproject.org/pub/epel/RPM-GPG-KEY-EPEL-7
    - failovermethod: priority
    - require_in:
      - pkg: install-redis
{%-   endif %}

install-redis:
  pkg.installed:
    - name: {{ redis_settings.pkg_name }}
    {% if redis_settings.version is defined %}
    - version: {{ redis_settings.version }}
    - ignore_epoch: True
    {% endif %}

    {%- if grains.os_family|lower == 'suse' %}
        {# this is basically a workaround for faulty packaging #}
install-redis-user-group:
  group.present:
    - name: {{ redis_settings.group }}
  user.present:
    - name: {{ redis_settings.user }}
    - usergroup: True
    - home: {{ redis_settings.home }}
    - require:
      - group: install-redis-user-group
    - require_in:
      - file: install-redis-log-dir

install-redis-log-dir:
  file.directory:
    - name: {{ redis_settings.dir.log }}
    - mode: 755
    - user: {{ redis_settings.user }}
    - group: {{ redis_settings.group }}
    - recurse:
        - user
        - group
        - mode
    - makedirs: True

install-redis-service:
  file.replace:
    - name: {{ redis_settings.dir.service }}/redis@.service
    - pattern: ^Type=notify
    - repl: Type=simple
    - onlyif: test -f {{ redis_settings.dir.service }}/redis@.service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: install-redis-log-dir
    {%- endif %}
