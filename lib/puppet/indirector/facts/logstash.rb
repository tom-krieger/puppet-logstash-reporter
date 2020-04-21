require 'puppet/indirector/facts/yaml'
require 'puppet/util/profiler'
require 'puppet/util/logstash'
require 'json'
require 'time'

# Logstash Facts
class Puppet::Node::Facts::Logstash < Puppet::Node::Facts::Yaml
  desc 'Save facts to logstash and then to yamlcache.'

  include Puppet::Util::Logstash

  def profile(message, metric_id, &block)
    message = 'Logstash: ' + message
    # Puppet.info "Message: #{message}"
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

    Puppet.info "Logstash indirector save #{request.key}"

    profile('logstash_facts#save', [:logstash, :facts, :save, request.key]) do
      begin
        # Puppet.info "Submitting facts to Logstash #{request.to_json} |"
        current_time = Time.now
        send_facts(request, current_time.clone.utc)
      rescue StandardError => e
        Puppet.err "Could not send facts to Logstash: #{e}\n#{e.backtrace}"
      end
    end
  end
end
