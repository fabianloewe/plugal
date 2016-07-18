require "redis"
require "json"

module Plugal
  module Receiver
    macro included
      @@name = {{@type.name.id.stringify}}
      @@redis = Redis.new
      @@commands = [] of String
    end 

    macro receive(name)
      {% for subclass in Plugal::Command.subclasses %}
        {% if subclass.name == name.capitalize.id + "Command" %}
          private def receive_{{name.id}}(result : Plugal::Result(
            # Finds the method called "_result_*" -> Splits this at '_' -> Gets the right type
            {{subclass.methods.find { |m| m.name =~ /_result_/}.name.split('_').last.capitalize.id}}
          ))

            {{yield Plugal::Result.type_var.first = subclass.methods.find { |m| m.name =~ /_result_/}.name.split('_').last.capitalize.id}}
          end

          private def send_{{name.id}}(*args)
            
          end
        {% end %}
      {% end %}
    end

    def commands
      @@commands ||= {{Plugal::Command.subclasses.map &.name.stringify}}
    end    

    def send(name, *args)
      generate_send
    end

    # :nodoc
    macro generate_send
      case name.to_s.capitalize + "Command" 
      {% for subclass in Plugal::Command.subclasses %}
        when {{subclass.name.id}}
          %cmd = {{subclass.name.id}}.new *args
          @@redis.publish @@name, %cmd.to_json
      {% end %}
      end
    end

    def run
      generate_run
    end

    # :nodoc:
    macro generate_run
      commands = Tuple.new(
      {% for method in @type.methods %}
        {% if method.name =~ /receive_/ %}
          (@@name + ".{{method.name.split('_')[1].id}}")
          {% if method != @type.methods.last %}
            ,
          {% end %}
        {% end %}
      {% end %}
      )

      @@redis.subscribe(*commands) do |on|
        on.message do |channel, result|
          case channel
          {% for method in @type.methods %}
            {% if method.name =~ /receive_/ %}
              when {{method.name.split('_')[1]}}
                result = {{method.args.first.restriction}}.from_json result
                {{method.name.id}} result
            {% end %}
          {% end %} 
          end
        end
      end
    end
  end
end