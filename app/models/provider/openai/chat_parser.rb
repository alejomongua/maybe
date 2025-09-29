class Provider::Openai::ChatParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    ChatResponse.new(
      id: response_id,
      model: response_model,
      messages: messages,
      function_requests: function_requests
    )
  end

  private
    attr_reader :object

    ChatResponse = Provider::LlmConcept::ChatResponse
    ChatMessage = Provider::LlmConcept::ChatMessage
    ChatFunctionRequest = Provider::LlmConcept::ChatFunctionRequest

    def response_id
      object.dig("id")
    end

    def response_model
      object.dig("model")
    end

    def messages
      choice = object.dig("choices", 0)
      return [] unless choice

      message = choice.dig("message")
      return [] unless message

      # For Chat Completions API, we get a single message with content and optional tool_calls
      message_content = message.dig("content") || ""
      
      [ChatMessage.new(
        id: response_id,
        output_text: message_content
      )]
    end

    def function_requests
      choice = object.dig("choices", 0)
      return [] unless choice

      message = choice.dig("message")
      return [] unless message

      tool_calls = message.dig("tool_calls") || []
      
      tool_calls.map do |tool_call|
        ChatFunctionRequest.new(
          id: tool_call.dig("id"),
          call_id: tool_call.dig("id"), # Use the same ID for call_id in Chat Completions API
          function_name: tool_call.dig("function", "name"),
          function_args: tool_call.dig("function", "arguments")
        )
      end
    end
end
