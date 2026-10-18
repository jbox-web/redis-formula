# frozen_string_literal: true

control 'redis' do
  impact 1.0
  title 'Manage Redis Server'
  desc '
    Manage the redis server
  '
  tag 'redis', 'package'

  redis_service =
    case system.platform[:family]
    when 'redhat', 'fedora', 'arch'
      'redis'
    when 'debian'
      'redis-server'
    when 'suse'
      'redis@default'
    end

  describe service(redis_service) do
    it { should be_installed }
    it { should be_enabled }
    it { should be_running }
  end

  describe port(6379) do
    it { should be_listening }
  end

  # The pillar password is required, and answered.
  describe command('redis-cli -a kitchen-test-password --no-auth-warning ping') do
    its('stdout') { should eq "PONG\n" }
  end
end

control 'redis configuration' do
  title 'redis.conf is private and rendered from the pillar'

  describe file('/etc/redis/redis.conf') do
    it { should be_owned_by 'redis' }
    its('group') { should eq 'redis' }
    its('mode') { should cmp '0640' }
    # `bind` given as a list in the pillar.
    its('content') { should match(/^bind 127\.0\.0\.1$/) }
    its('content') { should match(%r{^dir /data/redis$}) }
  end

  describe directory('/data/redis') do
    it { should be_owned_by 'redis' }
    its('mode') { should cmp '0750' }
  end

  describe file('/etc/systemd/system/redis-server.service.d/override.conf') do
    its('content') { should include 'ReadWriteDirectories=-/data/redis' }
  end
end
