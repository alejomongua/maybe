class Provider::Openai::ChatStreamParser
  Error = Class.new(StandardError)

  def initialize(object)
    @object = object
  end

  def parsed
    # This parser is no longer needed since streaming is handled directly in the main method
    # Keeping it as a placeholder for future enhancements
    nil
  end

  private
    attr_reader :object

    Chunk = Provider::LlmConcept::ChatStreamChunk
end
