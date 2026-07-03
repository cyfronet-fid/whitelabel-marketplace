# frozen_string_literal: true

require "rails_helper"

RSpec.describe Importers::Datasource, backend: true do
  it "defaults a missing order type to other" do
    imported_hash = described_class.call({})

    expect(imported_hash[:order_type]).to eq("other")
  end
end
