require "redis"
require "json"

module Plugal
  module Receiver
    macro included
      @@name = {{@type.name.stringify}}
      @@redis_commander = Redis.new
      @@redis_receiver = Redis.new
      @@commands = [] of String

      generate_send
    end 

    macro receive(name)
      {% for subclass in Plugal::Command.subclasses %}
        {% if subclass.name == name.capitalize.id + "Command" %}
          private def receive_{{name.id}}(result : Plugal::Result(
            # Finds the method called "_result_*" -> Splits this at '_' -> Gets the right type
            {% result_type = subclass.methods.find { |m| m.name =~ /_result_/}.name.split('_').last.capitalize.id %}
            {{result_type}}
          ))

            {{yield Plugal::Result.type_var.first = result_type}}
          end
        {% end %}
      {% end %}
    end

    def commands
      @@commands ||= {{Plugal::Command.subclasses.map &.name.stringify}}
    end    

    # :nodoc
    macro generate_send  
      def send(name, **args)    
      case name.to_s.capitalize + "Command" 
      {% for subclass in Plugal::Command.subclasses %}
        when "{{subclass.name.id}}"          
          cmd = {{subclass.name.id}}.new **args
          result = @@redis_commander.publish @@name, cmd.to_json    
      {% end %}
      else
        puts "Command #{name.to_s.capitalize}Command not found!"
      end
      end
    end

    def run(&block)
      proc = block
      generate_run
    end

    # :nodoc:
    macro generate_run
      commands = Tuple.new(
      {% for method in @type.methods %}
        {% if method.name =~ /receive_/ %}
          @@name + ".{{method.name.split('_')[1].id}}"
          {% if method != @type.methods.last %}
            ,
          {% end %}
        {% end %}
      {% end %}
      )

      @@redis_receiver.subscribe(*commands) do |on|
        on.message do |channel, result|
          case channel
          {% for method in @type.methods %}
            {% if method.name =~ /receive_/ %}
              when @@name + ".{{cmd_name = method.name.split('_')[1].id}}"
                command = {{Plugal::Command.subclasses.find { |c| c.name == cmd_name.capitalize + "Command"}}}.from_json result
                {{method.name.id}} command.result.not_nil!
            {% end %}
          {% end %} 
          end          
        end 

        on.subscribe do |channel, subscriptions|
          proc.call
        end  
      end
    end
  end
end