require 'puppet/indirector/facts/yaml'
require 'puppet/util/profiler'
require 'json'
require 'yaml'
require 'time'
require 'timeout'
require 'socket'
require 'pp'

# Lidar Facts
class Puppet::Node::Facts::Lidar < Puppet::Node::Facts::Yaml

  config_file = File.join([File.dirname(Puppet.settings[:config]), "logstash.yaml"])
  unless File.exist?(config_file)
    raise(Puppet::ParseError, "Logstash report config file #{config_file} missing or not readable")
  end
  CONFIG = YAML.load_file(config_file)

  desc 'Save facts to logstash and then to yamlcache.'

  def profile(message, metric_id, &block)
    message = 'LiDAR: ' + message
    arity = Puppet::Util::Profiler.method(:profile).arity
    case arity
    when 1
      Puppet::Util::Profiler.profile(message, &block)
    when 2, -2
      Puppet::Util::Profiler.profile(message, metric_id, &block)
    end
  end

  def save(request)
    # yaml cache goes first
    super(request)

    profile('lidar_facts#save', [:lidar, :facts, :save, request.key]) do
      begin
        Puppet.info 'Submitting facts to LiDAR'
        current_time = Time.now
        send_facts(request, current_time.clone.utc)
      rescue StandardError => e
        Puppet.err "Could not send facts to LiDAR: #{e}\n#{e.backtrace}"
      end
      begin
        Puppet.info 'Submitting facts to logstash'
        Puppet.debug "writing tmp file for #{self.host}"

        facts = request.instance.dup
        facts.values = facts.values.dup
        facts.values[:trusted] = get_trusted_info(request.node)

        event = Hash.new
        event["host"] = request.node
        event["@timestamp"] = Time.now.utc.iso8601
        event["@version"] = 1
        event["tags"] = ["puppet-facts"]
        event["facts"] = facts

        filename = "/tmp/puppet-report-#{self.host}.json"
        fh = File.open(filename, 'w')
        fh.write(event.to_json)
        fh.close()
        
        Timeout::timeout(CONFIG[:timeout]) do
          json = event.to_json
          ls = TCPSocket.new "#{CONFIG[:host]}" , CONFIG[:port]
          ls.puts json
          ls.close
        end
      rescue Exception => e
        Puppet.err("Failed to write to #{CONFIG[:host]} on port #{CONFIG[:port]}: #{e.message}")
      end
    end
  end

  def get_trusted_info(node)
    trusted = Puppet.lookup(:trusted_information) do
      Puppet::Context::TrustedInformation.local(node)
    end
    trusted.to_h
  end
end
