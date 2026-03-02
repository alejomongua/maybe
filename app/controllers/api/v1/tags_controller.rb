# frozen_string_literal: true

class Api::V1::TagsController < Api::V1::BaseController
  before_action :ensure_read_scope, only: [ :index ]

  def index
    family = current_resource_owner.family
    tags = family.tags.order(:name)

    render json: {
      tags: tags.map do |tag|
        {
          id: tag.id,
          name: tag.name,
          color: tag.color,
          created_at: tag.created_at,
          updated_at: tag.updated_at
        }
      end
    }
  rescue => e
    Rails.logger.error "TagsController#index error: #{e.message}"
    Rails.logger.error e.backtrace.join("\n")

    render json: {
      error: "internal_server_error",
      message: "Error: #{e.message}"
    }, status: :internal_server_error
  end
end