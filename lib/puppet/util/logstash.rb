require 'puppet'
require 'puppet/util'
require 'puppet/node/facts'
require 'puppet/network/http_pool'
require 'fileutils'
require 'net/http'
require 'net/https'
require 'uri'
require 'yaml'
require 'json'
require 'time'
require 'timeout'

# Utility functions used by the report processor and the facts indirector.
module Puppet::Util::Logstash
  def settings
    return @settings if @settings
    @settings_file = Puppet[:confdir] + '/logstash.yaml'
    @settings = YAML.load_file(@settings_file)
  end

  def pe_console
    settings['pe_console'] || Puppet[:certname]
  end

  def logstash_fact_server
    settings[:factshost]
  end

  def logstash_fact_server_port
    settings[:factsport]
  end

  def get_trusted_info(node)
    trusted = Puppet.lookup(:trusted_information) do
      Puppet::Context::TrustedInformation.local(node)
    end
    trusted.to_h
  end

  def send_facts(request, time)
    # Copied from the puppetdb fact indirector.  Explicitly strips
    # out the packages custom fact '_puppet_inventory_1'
    facts = request.instance.dup
    facts.values = facts.values.dup
    facts.values[:trusted] = get_trusted_info(request.node)

    # Puppet.info "Facts of Logstash: #{facts.values[:trusted].to_json} |"

    inventory = facts.values['_puppet_inventory_1']
    package_inventory = inventory['packages'] if inventory.respond_to?(:keys)
    facts.values.delete('_puppet_inventory_1')

    Puppet.info 'sending facts to Logstash'

    facts.values = facts.values.dup
    data = {}
    data["@timestamp"] = time
    data = data.merge(facts.values[:trusted])
    server = logstash_fact_server
    port = logstash_fact_server_port
    Timeout::timeout(1000) do
      json = data.to_json
      ls = TCPSocket.new server , port
      ls.puts json
      ls.close
    end
  end

end