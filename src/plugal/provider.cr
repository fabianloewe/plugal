require "redis"
require "msgpack"
require "colorize"

module Plugal
  module Provider
    macro included
      @@name = "{{@type.name.id}}"
      @@redis_executor = Redis.new
      @@redis_responder = Redis.new
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
      @@redis_executor.subscribe(@@receiver) do |on|
        on.message do |channel, command_str|
          command_name = JSON.parse command_str
          case command_name["name"]
            {% for method in @type.methods %}
              {% if method.name =~ /provide_/ %}
                when {{method.name.split('_')[1]}}
                begin
                  {% cmd_class = Plugal::Command.subclasses.find { |s| s.name == method.name.split('_')[1].capitalize + "Command" } %}
                  command = {{cmd_class.id}}.from_msgpack command_str

                  # Creates the method call
                  result = {{method.name}}(
                    {% if !method.args.empty? %}
                      {% for arg in method.args %}
                        {{arg.name}}: command.{{arg.name}} 

                        {% if arg != method.args.last %}
                          ,
                        {% end %}
                      {% end %} 
                    {% end %}
                    )

                    {% result_type = cmd_class.methods.find { |i| i.name.starts_with?("_result_") }.name.split('_').last.capitalize.id %}
                    result = if result.is_a?({{result_type.id}})
                               Plugal::Result({{result_type.id}}).new result
                             else
                               result
                             end                      

                    command = {{cmd_class}}.new(
                      {% if !method.args.empty? %}
                        {% for arg in method.args %}
                          {{arg.name}}: command.{{arg.name}},
                        {% end %} 
                      {% end %}
                      result: result
                    ).to_msgpack

                    result = @@redis_responder.publish @@receiver.not_nil! + ".{{method.name.split('_')[1].id}}", command
                  rescue e
                    puts "ERROR: ".colorize(:red), e
                  end
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

private macro create_cmdline

end