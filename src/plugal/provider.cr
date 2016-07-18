require "redis"
require "json"

module Plugal
  class ProviderOld(T, R)
    property commands : Array(CommandDef(T, R))

    def initialize(@name : String, @commands : Array(CommandDef(T, R)))
      @redis = Redis.new      
    end

    def channels
      channels = [] of String
      @commands.each { |cmd| channels << cmd.receiver + '.' + cmd.name }
    end    

    macro def_on_command
      def on_command(name, &block : Hash(String, 
        {{@type.type_vars.first.id}})-> _)
        if cmd_def = @commands.bsearch { |cmd| cmd.name == name }
          receiver = cmd_def.receiver
          @redis.subscribe(receiver) do |on|
            on.message do |channel, command|
              command = JSON.parse(command).as(Command)
              result = block.call command.params
  
              @redis.publish receiver + '.' + name, result
            end
          end
        end
      end
    end

    def_on_command
  end

  module Provider
    macro included
      @@name = "{{@type.name.id}}"
      @@redis = Redis.new
      @@commands = [] of String
    end

    def run(receiver = "")
      @@receiver = receiver if !receiver.nil?
      if @@receiver.nil?
        return nil
      end

      setup
    end

    macro setup
      @@redis.subscribe(@@receiver) do |on|
        on.message do |channel, command|
          command = JSON.parse command
          case command["name"]
            {% for method in @type.methods %}
              {% if method.name =~ /provide_/ %}
                when {{method.name.split('_')[1]}}
                  # Creates the method call
                  result = {{method.name}}(
                    {% if !method.args.empty? %}
                      {% for arg in method.args %}
                        {{arg.name}}: command["{{arg.name}}"].raw.as({{Plugal::Command.subclasses.find { |s| s.name == method.name.split('_')[1].capitalize + "Command" }.methods.find {|i| i.name.starts_with?("_arg_#{arg.name}")}.name.split('_').last.capitalize.tr("32", "64").id}})

                        {% if arg != method.args.last %}
                          ,
                        {% end %}
                      {% end %} 
                    {% end %}
                    )

                    @@redis.publish @@receiver.not_nil! + ".{{method.name.split('_')[1].id}}", result
              {% end %} 
            {% end %}                         
          end
        end
      end
    end

    macro provide(name)
      {% for subclass in Plugal::Command.subclasses %}
        {% if subclass.name == name.capitalize.id + "Command" %}
          private def provide_{{name.id}}(
            # Selects all methods containin "_arg_" -> Splits these at '_' -> Joins the results with ", "
            {{subclass.methods.select { |m| m.name =~ /_arg_/}.map(&.name.split('_')[2].id).join(", ").id}}
            )

            {{yield subclass.methods.select { |m| m.name =~ /_arg_/}.map(&.name.split('_').last.id).join(", ").id}}
          end
        {% end %}
      {% end %}
    end
  end
end