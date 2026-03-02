class Assistant::Function::Calculate < Assistant::Function
  class << self
    def name
      "calculate"
    end

    def description
      <<~INSTRUCTIONS
        Use this tool to perform precise arithmetic calculations instead of computing them yourself.
        Always use this when you need to sum, subtract, multiply, divide, or compute percentages on numbers.

        This is especially important when:
        - Totaling a list of transaction amounts
        - Computing net income (income minus expenses)
        - Calculating percentage shares or changes
        - Any other math where precision is required

        Examples:

        Sum a list of values:
        ```
        calculate({ operation: "sum", operands: [12.50, 8.00, 99.99] })
        ```

        Subtract two values:
        ```
        calculate({ operation: "subtract", operands: [500.00, 123.45] })
        ```

        Compute what percentage A is of B:
        ```
        calculate({ operation: "percentage", operands: [25.00, 200.00] })
        # returns 12.5 (i.e. 25 is 12.5% of 200)
        ```
      INSTRUCTIONS
    end
  end

  OPERATIONS = %w[sum add subtract multiply divide percentage].freeze

  def call(params = {})
    operation = params["operation"].to_s.downcase
    operands  = Array(params["operands"]).map { |n| BigDecimal(n.to_s) }

    unless OPERATIONS.include?(operation)
      return { error: "Unknown operation '#{operation}'. Supported: #{OPERATIONS.join(', ')}" }
    end

    if operands.empty?
      return { error: "No operands provided." }
    end

    result = case operation
    when "sum", "add"
      operands.sum
    when "subtract"
      operands.reduce(:-)
    when "multiply"
      operands.reduce(:*)
    when "divide"
      return { error: "Division by zero." } if operands[1..].any?(&:zero?)
      operands.reduce(:/)
    when "percentage"
      return { error: "percentage requires exactly 2 operands (part, total)." } if operands.size != 2
      return { error: "Division by zero: total is 0." } if operands[1].zero?
      (operands[0] / operands[1]) * BigDecimal("100")
    end

    {
      operation: operation,
      operands: operands.map(&:to_f),
      result: result.to_f
    }
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "operation", "operands" ],
      properties: {
        operation: {
          type: "string",
          enum: OPERATIONS,
          description: "Arithmetic operation to perform: 'sum' or 'add' to add all operands, 'subtract' to reduce left-to-right, 'multiply' to multiply all, 'divide' to divide left-to-right, 'percentage' to compute (operands[0] / operands[1]) * 100."
        },
        operands: {
          type: "array",
          items: { type: "number" },
          description: "List of numbers to operate on. For 'sum'/'multiply' any count is accepted; for 'percentage' exactly 2 are required (part, total)."
        }
      }
    )
  end
end
