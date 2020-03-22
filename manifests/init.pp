# == Class: logstash_reporter
#
# This class deploys and configures a puppet reporter to send reports to logstash
#
#
# === Parameters
#
# [*logstash_host*]
#   String.  Logstash host to write reports to
#   Default: 127.0.0.1
#
# [*logstash_port*]
#   Integer.  Port logstash is listening for tcp connections on
#   Default: 5999
#
# [*config_file*]
#   String.  Path to write the config file to
#   Default: /etc/puppet/logstash.yaml
#
# [*config_owner*]
#   String.  Owner of the config file
#
# [*config_group*]
#   String.  Group of the config file
#
# [*update_ini]
#
# === Examples
#
# * Installation:
#     class { 'logstash_reporter': }
#
# === Authors
#
# * John E. Vincent
# * Justin Lambert <mailto:jlambert@letsevenup.com>
# * Richard Pijnenburg <mailto:richard.pijnenburg@elastic.co>
#
class logstash_reporter (
  String $logstash_host   = '127.0.0.1',
  Integer $logstash_port  = 5999,
  String $config_file     = $::logstash_reporter::params::config_file,
  String $config_owner    = $::logstash_reporter::params::config_owner,
  String $config_group    = $::logstash_reporter::params::config_group,
  Boolean $update_ini     = $::logstash_reporter::params::update_ini,
  String $reports         = $::logstash_reporter::params::reports,
) inherits logstash_reporter::params {

  file { $config_file:
    ensure  => file,
    owner   => $config_owner,
    group   => $config_group,
    mode    => '0444',
    content => template('logstash_reporter/logstash.yaml.erb'),
  }

  $ini_default = {
    ensure  => present,
    path    => $config_file,
    section => 'master',
    setting => 'reports',
    value   => $reports,
  }

  if $update_ini {
    if $::is_pe {
      $ini_pe = {
        notify  => Service['pe-puppetserver'],
      }
    } else {
        $ini_pe = {}
    }

    $ini_data = merge($ini_default, $ini_pe)

    ini_setting { 'enable logstash reporting':
      * => $ini_data,
    }
  }

}

