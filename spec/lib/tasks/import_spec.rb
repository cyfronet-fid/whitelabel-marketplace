# frozen_string_literal: true

require "rails_helper"

describe "import:resources", type: :task, backend: true do
  let(:resource_importer) { double("Import::Resources") }
  let(:provider_importer) { double("Import::Providers") }

  around do |example|
    preserve_env("MP_IMPORT_EOSC_REGISTRY_URL") do
      ENV.delete("MP_IMPORT_EOSC_REGISTRY_URL")
      example.run
    end
  end

  it "preloads the Rails environment" do
    expect(task.prerequisites).to include "environment"
  end

  it "should pass ENV variables" do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with("MP_IMPORT_EOSC_REGISTRY_URL").and_return(
      "https://integration.providers.sandbox.eosc-beyond.eu/api"
    )
    allow(ENV).to receive(:[]).with("DRY_RUN").and_return("1")
    allow(ENV).to receive(:[]).with("IDS").and_return("sampleeid,sampleeid2")
    allow(ENV).to receive(:[]).with("OUTPUT").and_return("/tmp/output.json")
    allow(ENV).to receive(:[]).with("UPSTREAM").and_return("eosc_registry")
    allow(ENV).to receive(:[]).with("MP_IMPORT_TOKEN").and_return("password")

    allow(resource_importer).to receive(:call)
    import_class_stub = class_double(Import::Resources).as_stubbed_const(transfer_nested_constants: true)
    allow(import_class_stub).to receive(:new).with(
      "https://integration.providers.sandbox.eosc-beyond.eu/api",
      dry_run: false,
      ids: [],
      filepath: nil,
      default_upstream: :eosc_registry,
      token: nil,
      rescue_mode: false
    ).and_return(resource_importer)

    subject.invoke
  end

  it "should call Import::Resources.call" do
    allow(resource_importer).to receive(:call)
    import_class_stub = class_double(Import::Resources).as_stubbed_const(transfer_nested_constants: true)
    allow(import_class_stub).to receive(:new).with(
      "https://integration.providers.sandbox.eosc-beyond.eu/api",
      default_upstream: :eosc_registry,
      dry_run: false,
      filepath: nil,
      ids: [],
      token: nil,
      rescue_mode: false
    ).and_return(resource_importer)

    subject.invoke
  end

  it "should call Import::Providers.call" do
    allow(provider_importer).to receive(:call)
    import_class_stub = class_double(Import::Providers).as_stubbed_const(transfer_nested_constants: true)
    allow(import_class_stub).to receive(:new).with(
      "https://integration.providers.sandbox.eosc-beyond.eu/api",
      dry_run: false,
      filepath: nil
    ).and_return(provider_importer)

    subject.invoke
  end

  def preserve_env(*keys)
    original = keys.index_with { |key| ENV.key?(key) ? ENV[key] : nil }
    yield
  ensure
    keys.each { |key| original[key].nil? ? ENV.delete(key) : ENV[key] = original[key] }
  end
end

describe "import:authorize", type: :task, backend: true do
  around do |example|
    preserve_env("MP_IMPORT_TOKEN", "IMPORT_CLIENT_ID", "IMPORT_CLIENT_SECRET", "CHECKIN_TOKEN_ENDPOINT") do
      example.run
    end
  end

  after { task.reenable }

  it "preloads the Rails environment" do
    expect(task.prerequisites).to include "environment"
  end

  it "sets MP_IMPORT_TOKEN from import client credentials" do
    ENV.delete("MP_IMPORT_TOKEN")
    ENV["IMPORT_CLIENT_ID"] = "import-client"
    ENV["IMPORT_CLIENT_SECRET"] = "import-secret"
    ENV["CHECKIN_TOKEN_ENDPOINT"] = "https://checkin.example/token"

    token_importer = instance_double(Importers::ClientCredentialsToken, receive_token: "received-token")
    allow(Importers::ClientCredentialsToken).to receive(:new).and_return(token_importer)

    task.invoke

    expect(ENV.fetch("MP_IMPORT_TOKEN", nil)).to eq("received-token")
  end

  it "keeps an existing MP_IMPORT_TOKEN" do
    ENV["MP_IMPORT_TOKEN"] = "manual-token"
    ENV["IMPORT_CLIENT_ID"] = "import-client"
    ENV["IMPORT_CLIENT_SECRET"] = "import-secret"

    expect(Importers::ClientCredentialsToken).not_to receive(:new)

    task.invoke

    expect(ENV.fetch("MP_IMPORT_TOKEN", nil)).to eq("manual-token")
  end

  it "raises a configuration error for partial import client credentials" do
    ENV.delete("MP_IMPORT_TOKEN")
    ENV["IMPORT_CLIENT_ID"] = "import-client"
    ENV.delete("IMPORT_CLIENT_SECRET")

    expect { task.invoke }.to raise_error(Importers::ClientCredentialsToken::ConfigurationError)
  end

  def preserve_env(*keys)
    original = keys.index_with { |key| ENV.key?(key) ? ENV[key] : nil }
    yield
  ensure
    keys.each { |key| original[key].nil? ? ENV.delete(key) : ENV[key] = original[key] }
  end
end
