
{%- from "redis/map.jinja" import redis_settings as r with context %}

redis-server-service-clean:
  service.dead:
    - name: {{ r.svc_name }}
    - enable: false
    - require_in:
      - pkg: redis-server-clean

redis-server-clean:
  pkg.removed:
    - name: {{ r.pkg_name }}
