include:
  - redis.common

{% from "redis/map.jinja" import redis_settings as r with context %}

redis_config:
  file.managed:
    - name: {{ r.cfg_name }}
    - template: jinja
    {% if r.source_path is not defined %}
    - source: salt://redis/files/redis-{{ r.cfg_version }}.conf.jinja
    {% else %}
    - source: {{ r.source_path }}
    {%- endif %}
    {#- The file may carry `requirepass`: readable by redis only, never shown
        in a state diff. #}
    - user: {{ r.user }}
    - group: {{ r.group }}
    - mode: '0640'
    - show_changes: False
    - makedirs: True
    - require:
      - pkg: install-redis

{#- `dir` in redis.conf: redis refuses to start when it is missing. #}
redis_root_dir:
  file.directory:
    - name: {{ r.root_dir }}
    - user: {{ r.user }}
    - group: {{ r.group }}
    - mode: '0750'
    - makedirs: True
    - require:
      - pkg: install-redis
    - require_in:
      - service: redis_service

    {%- if r.get('systemd_rw_root_dir', False) %}

{#- The packaged unit runs with ProtectSystem=strict and only allows writes to
    its own data directory: without this drop-in, RDB snapshots fail in any
    other `root_dir`. #}
redis_systemd_dropin:
  file.managed:
    - name: /etc/systemd/system/{{ r.svc_name }}.service.d/override.conf
    - contents: |
        [Service]
        ReadWriteDirectories=-{{ r.root_dir }}
    - makedirs: True
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: redis_systemd_dropin
    - require_in:
      - service: redis_service
    - watch_in:
      - service: redis_service
    {%- endif %}

    {% if r.disable_transparent_huge_pages is defined and r.disable_transparent_huge_pages %}
redis_disable_transparent_huge_pages:
    cmd.run:
      - name: echo "never" > /sys/kernel/mm/transparent_hugepage/enabled
      - unless: grep -i '^never' /sys/kernel/mm/transparent_hugepage/enabled
    {%- endif %}

    {%- if grains.os_family|lower == 'arch' %}
redis_service_simple:
  file.replace:
    - name: {{ r.dir.service }}/redis.service
    - pattern: Type=notify
    - repl: Type=simple
    - onlyif: test -f {{ r.dir.service }}/redis.service
    - require_in:
      - service: redis_service
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: redis_service_simple
    {%- endif %}

redis_service:
  service.{{ r.svc_state }}:
    - name: {{ r.svc_name }}
    - enable: {{ r.svc_onboot }}
    - watch:
      - file: redis_config
    - retry: {{ r.retry_option|json }}

    {% if r.overcommit_memory == True %}
redis_overcommit_memory:
  sysctl.present:
    - name: vm.overcommit_memory
    - value: 1
        {% if grains['os_family'] == 'Arch' %}
    - require_in:
      - service: redis_service
        {% endif %}
    {%- endif %}
