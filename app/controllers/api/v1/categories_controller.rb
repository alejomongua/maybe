# frozen_string_literal: true

class Api::V1::CategoriesController < Api::V1::BaseController
  before_action :ensure_read_scope, only: [ :index ]

  def index
    family = current_resource_owner.family
    categories = family.categories.order(:name)

    render json: {
      categories: categories.map do |category|
        {
          id: category.id,
          name: category.name,
          color: category.color,
          classification: category.classification,
          parent_id: category.parent_id,
          created_at: category.created_at,
          updated_at: category.updated_at
        }
      end
    }
  rescue => e
    Rails.logger.error "CategoriesController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end
end