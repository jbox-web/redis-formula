# -*- coding: utf-8 -*-
# vim: ft=yaml
---
redis:
  # A data directory outside the packaged one: created by the formula and
  # added to the writable paths of the systemd unit.
  root_dir: /data/redis
  # `bind` given as a list.
  bind:
    - 127.0.0.1
  tcp_keepalive: 300
  # Test-only password: redis.conf must stay readable by redis only.
  pass: kitchen-test-password
  lookup:
    overcommit_memory: false
