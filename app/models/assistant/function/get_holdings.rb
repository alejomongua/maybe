class Assistant::Function::GetHoldings < Assistant::Function
  include Pagy::Backend

  SUPPORTED_ACCOUNT_TYPES = %w[Investment Crypto].freeze

  class << self
    def default_page_size
      50
    end

    def name
      "get_holdings"
    end

    def description
      <<~INSTRUCTIONS
        Usa esto para buscar las posiciones de inversión del usuario aplicando varios filtros opcionales.

        Esta función es ideal para:
        - Encontrar posiciones o valores específicos
        - Obtener la composición y asignación del portafolio
        - Ver el rendimiento de las inversiones y el coste base

        Nota: Esta función solo devuelve posiciones de cuentas de Inversión y Criptomonedas.

        Nota sobre paginación:

        Esta función admite paginación. La respuesta incluirá las siguientes propiedades:

        - `total_pages`: Número total de páginas de resultados
        - `page`: Página actual de resultados
        - `page_size`: Número de resultados por página (siempre será #{default_page_size})
        - `total_results`: Número total de resultados para los filtros dados
        - `total_value`: Valor total de todas las posiciones para los filtros dados

        Ejemplo simple (todas las posiciones actuales):

        ```
        get_holdings({
          page: 1
        })
        ```

        Ejemplo más complejo (varios filtros):

        ```
        get_holdings({
          page: 1,
          accounts: ["Cuenta de Inversión"],
          securities: ["AAPL", "GOOGL"]
        })
        ```
      INSTRUCTIONS
    end
  end

  def strict_mode?
    false
  end

  def params_schema
    build_schema(
      required: [ "page" ],
      properties: {
        page: {
          type: "integer",
          description: "Page number"
        },
        accounts: {
          type: "array",
          description: "Filter holdings by account name (only Investment and Crypto accounts are supported)",
          items: { enum: investment_account_names },
          minItems: 1,
          uniqueItems: true
        },
        securities: {
          type: "array",
          description: "Filter holdings by security ticker symbol",
          items: { enum: family_security_tickers },
          minItems: 1,
          uniqueItems: true
        }
      }
    )
  end

  def call(params = {})
    holdings_query = build_holdings_query(params)

    pagy, paginated_holdings = pagy(
      holdings_query.includes(:security, :account).order(amount: :desc),
      page: params["page"] || 1,
      limit: default_page_size
    )

    total_value = holdings_query.sum(:amount)

    normalized_holdings = paginated_holdings.map do |holding|
      {
        ticker: holding.ticker,
        name: holding.name,
        quantity: holding.qty.to_f,
        price: holding.price.to_f,
        currency: holding.currency,
        amount: holding.amount.to_f,
        formatted_amount: holding.amount_money.format,
        weight: holding.weight&.round(2),
        average_cost: holding.avg_cost&.to_f,
        formatted_average_cost: holding.avg_cost&.format,
        account: holding.account.name,
        date: holding.date
      }
    end

    {
      holdings: normalized_holdings,
      total_results: pagy.count,
      page: pagy.page,
      page_size: default_page_size,
      total_pages: pagy.pages,
      total_value: Money.new(total_value, family.currency).format
    }
  end

  private
    def default_page_size
      self.class.default_page_size
    end

    def build_holdings_query(params)
      accounts = investment_accounts

      if params["accounts"].present?
        accounts = accounts.where(name: params["accounts"])
      end

      holdings = Holding.where(account: accounts)
        .where(
          id: Holding.where(account: accounts)
            .select("DISTINCT ON (account_id, security_id) id")
            .where.not(qty: 0)
            .order(:account_id, :security_id, date: :desc)
        )

      if params["securities"].present?
        security_ids = family.securities.where(ticker: params["securities"]).pluck(:id)
        holdings = holdings.where(security_id: security_ids)
      end

      holdings
    end

    def investment_accounts
      family.accounts.visible.where(accountable_type: SUPPORTED_ACCOUNT_TYPES)
    end

    def investment_account_names
      @investment_account_names ||= investment_accounts.pluck(:name)
    end

    def family_security_tickers
      @family_security_tickers ||= Security
        .where(id: Holding.where(account_id: investment_accounts.select(:id)).select(:security_id))
        .distinct
        .pluck(:ticker)
    end
end
