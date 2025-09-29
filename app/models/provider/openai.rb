class Provider::Openai < Provider
  include LlmConcept

  # Subclass so errors caught in this provider are raised as Provider::Openai::Error
  Error = Class.new(Provider::Error)

  MODELS = %w[gpt-4.1]

  def initialize(access_token)
    options = { access_token: access_token }

    # Check if there is an override base URL (for using OpenAI-compatible APIs like Ollama)
    base_url = ENV["AI_BASE_URL"]
    options[:uri_base] = base_url if base_url.present?

    Rails.logger.debug("Initializing OpenAI client with options: #{options.except(:access_token)}")

    @client = ::OpenAI::Client.new(options)
  end

  def supports_model?(model)
    return true if ENV["AI_BASE_URL"].present?

    MODELS.include?(model)
  end

  def auto_categorize(transactions: [], user_categories: [], model: "")
    with_provider_response do
      raise Error, "Too many transactions to auto-categorize. Max is 25 per request." if transactions.size > 25

      result = AutoCategorizer.new(
        client,
        model: model,
        transactions: transactions,
        user_categories: user_categories
      ).auto_categorize

      log_langfuse_generation(
        name: "auto_categorize",
        model: model,
        input: { transactions: transactions, user_categories: user_categories },
        output: result.map(&:to_h)
      )

      result
    end
  end

  def auto_detect_merchants(transactions: [], user_merchants: [], model: "")
    with_provider_response do
      raise Error, "Too many transactions to auto-detect merchants. Max is 25 per request." if transactions.size > 25

      result = AutoMerchantDetector.new(
        client,
        model: model,
        transactions: transactions,
        user_merchants: user_merchants
      ).auto_detect_merchants

      log_langfuse_generation(
        name: "auto_detect_merchants",
        model: model,
        input: { transactions: transactions, user_merchants: user_merchants },
        output: result.map(&:to_h)
      )

      result
    end
  end

  def chat_response(prompt, model:, instructions: nil, functions: [], function_results: [], streamer: nil, previous_response_id: nil)
    with_provider_response do
      chat_config = ChatConfig.new(
        functions: functions,
        function_results: function_results
      )

      # For streaming, we need to handle it differently - use non-streaming for now
      # to ensure the job completes properly
      if streamer.present?
        # Use non-streaming mode for Ollama compatibility
        messages = chat_config.build_input(prompt)

        parameters = {
          model: model,
          messages: messages
        }

        # Add optional parameters if present
        parameters[:tools] = chat_config.tools if chat_config.tools.any?
        parameters[:tool_choice] = "auto" if chat_config.tools.any?
        parameters[:max_tokens] = 4096 # Set reasonable default for Ollama compatibility

        raw_response = client.chat(parameters: parameters)
        parsed = ChatParser.new(raw_response).parsed
        
        # Simulate streaming by sending the complete response as chunks
        if parsed.messages.any?
          message_text = parsed.messages.first.output_text
          # Send content chunks
          streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "output_text", data: message_text))
          # Send final response
          streamer.call(Provider::LlmConcept::ChatStreamChunk.new(type: "response", data: parsed))
        end
        
        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: messages,
          output: parsed.messages.map(&:output_text).join("\n"),
          usage: raw_response["usage"]
        )
        parsed
      else
        messages = chat_config.build_input(prompt)

        parameters = {
          model: model,
          messages: messages
        }

        # Add optional parameters if present
        parameters[:tools] = chat_config.tools if chat_config.tools.any?
        parameters[:tool_choice] = "auto" if chat_config.tools.any?
        parameters[:max_tokens] = 4096 # Set reasonable default for Ollama compatibility

        raw_response = client.chat(parameters: parameters)
        parsed = ChatParser.new(raw_response).parsed
        log_langfuse_generation(
          name: "chat_response",
          model: model,
          input: messages,
          output: parsed.messages.map(&:output_text).join("\n"),
          usage: raw_response["usage"]
        )
        parsed
      end
    end
  end

  private
    attr_reader :client

    def langfuse_client
      return unless ENV["LANGFUSE_PUBLIC_KEY"].present? && ENV["LANGFUSE_SECRET_KEY"].present?

      @langfuse_client = Langfuse.new
    end

    def log_langfuse_generation(name:, model:, input:, output:, usage: nil)
      return unless langfuse_client

      trace = langfuse_client.trace(name: "openai.#{name}", input: input)
      trace.generation(
        name: name,
        model: model,
        input: input,
        output: output,
        usage: usage
      )
      trace.update(output: output)
    rescue => e
      Rails.logger.warn("Langfuse logging failed: #{e.message}")
    end
end
