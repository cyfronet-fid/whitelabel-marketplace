# frozen_string_literal: true

class Provider::CreateAsDraft < Provider::ApplicationService
  def call
    @provider.status = :draft
    @provider.save(validate: false)
    @provider.reindex
    @provider
  end
end
