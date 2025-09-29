class Provider::Openai::ChatConfig
  def initialize(functions: [], function_results: [])
    @functions = functions
    @function_results = function_results
  end

  def tools
    functions.map do |fn|
      {
        type: "function",
        function: {
          name: fn[:name],
          description: fn[:description],
          parameters: fn[:params_schema],
          strict: fn[:strict]
        }
      }
    end
  end

  def build_input(prompt)
    messages = [{ role: "user", content: prompt }]
    Rails.logger.debug("ChatConfig - Initial message: #{messages.first.inspect}")

    # Add function results as tool messages for Chat Completions API
    function_results.each do |fn_result|
      tool_message = {
        role: "tool",
        tool_call_id: fn_result[:call_id],
        content: fn_result[:output].to_json
      }
      messages << tool_message
      Rails.logger.debug("ChatConfig - Added tool message: #{tool_message.inspect}")
    end

    Rails.logger.debug("ChatConfig - Final messages: #{messages.inspect}")
    messages
  end

  private
    attr_reader :functions, :function_results
end
