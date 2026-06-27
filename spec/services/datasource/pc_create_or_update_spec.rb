# frozen_string_literal: true

require "rails_helper"

RSpec.describe Datasource::PcCreateOrUpdate, backend: true do
  let!(:provider) { create(:provider, pid: "provider-1") }

  it "persists other when the order type is missing" do
    datasource = described_class.new(payload, :published).call

    expect(datasource.order_type).to eq("other")
  end

  def payload
    {
      "id" => "datasource-1",
      "name" => "Imported datasource",
      "description" => "Datasource description",
      "webpage" => "https://example.org/datasource",
      "resourceOrganisation" => provider.pid,
      "resourceProviders" => [provider.pid],
      "publicContacts" => ["ops@example.org"],
      "versionControl" => true,
      "researchProductTypes" => ["dataset"]
    }
  end
end
