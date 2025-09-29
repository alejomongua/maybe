class Provider::Openai::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    # For Chat Completions API streaming, chunks have a different structure
    choices = object.dig("choices")
    return nil unless choices && choices.any?

    choice = choices.first
    delta = choice.dig("delta")
    return nil unless delta

    # Check if this is a content delta
    if delta.key?("content")
      Chunk.new(type: "output_text", data: delta.dig("content"))
    # Check if this is a tool call delta (function call)
    elsif delta.key?("tool_calls")
      # For tool calls, we need to handle the completed response
      # In streaming mode, tool calls are sent as a completed response
      if choice.dig("finish_reason") == "tool_calls"
        Chunk.new(type: "response", data: parse_response(object))
      end
    # Check if this is the final chunk with usage data
    elsif object.key?("usage")
      # This is the final chunk with usage information
      # We can ignore it or use it for logging
      nil
    end
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk

    def parse_response(response)
      Provider::Openai::ChatParser.new(response).parsed
    end
end
