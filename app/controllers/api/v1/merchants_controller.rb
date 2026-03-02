# frozen_string_literal: true

class Api::V1::MerchantsController < Api::V1::BaseController
  before_action :ensure_read_scope, only: [ :index ]

  def index
    family = current_resource_owner.family
    merchants = family.merchants.order(:name)

    render json: {
      merchants: merchants.map do |merchant|
        {
          id: merchant.id,
          name: merchant.name,
          color: merchant.color,
          created_at: merchant.created_at,
          updated_at: merchant.updated_at
        }
      end
    }
  rescue => e
    Rails.logger.error "MerchantsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end
end