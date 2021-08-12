# frozen_string_literal: true

require "rails_helper"
require "jira/setup"

describe Import::Resources do
  let(:test_url) { "https://localhost/api" }
  let(:unirest) { double(Unirest) }

  def make_and_stub_eosc_registry(ids: [], dry_run: false, filepath: nil, log: false,
                        default_upstream: nil)
    options = {
        dry_run: dry_run,
        ids: ids,
        filepath: filepath,
        unirest: unirest
    }

    unless log
      options[:logger] = ->(_msg) { }
    end

    if default_upstream
      options[:default_upstream] = default_upstream
    end

    eosc_registry = Import::Resources.new(test_url, options)

    def stub_http_file(eosc_registry, file_fixture_name, url, content_type: "image/png")
      r = open(file_fixture(file_fixture_name))
      r.define_singleton_method(:content_type) { content_type }
      allow(eosc_registry).to receive(:open).with(url, ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE).and_return(r)
    end

    stub_http_file(eosc_registry, "PhenoMeNal_logo.png",
                   "http://phenomenal-h2020.eu/home/wp-content/uploads/2016/06/PhenoMeNal_logo.png")

    stub_http_file(eosc_registry, "MetalPDB.png",
                   "http://metalweb.cerm.unifi.it/global/images/MetalPDB.png")

    stub_http_file(eosc_registry, "PDB_logo_rect_medium.svg",
                   "https://pdb-redo.eu/images/PDB_logo_rect_medium.svg",
                   content_type: "image/svg+xml")

    eosc_registry
  end

  let(:eosc_registry) { make_and_stub_eosc_registry(log: true) }
  let(:log_less_eosc_registry) { make_and_stub_eosc_registry(log: false) }
  let!(:scientific_domain_other) { create(:scientific_domain, name: "Other",
                                          eid: "scientific_subdomain-other-other") }
  let!(:target_user_other) { create(:target_user, name: "Other", eid: "target_user-other") }
  let!(:storage) { create(:category, name: "Storage") }
  let!(:training) { create(:category, name: "Training & Support") }
  let!(:security) { create(:category, name: "Security & Operations") }
  let!(:analytics) { create(:category, name: "Processing & Analysis") }
  let!(:data) { create(:category, name: "Data management", eid: "category-data") }
  let!(:data_subcategory) { create(:category, name: "Access", eid: "data-applications-software") }

  let!(:compute) { create(:category, name: "Compute") }
  let!(:networking) { create(:category, name: "Networking") }
  let!(:provider) { create(:provider, name: "BlueBRIDGE") }

  def expect_responses(unirest, test_url, services_response = nil)
    unless services_response.nil?
      expect(unirest).to receive(:get).with("#{test_url}/resource/rich/all?quantity=10000&from=0",
                                            headers: { "Accept" => "application/json" }).and_return(services_response)
    end
  end

  describe "#error responses" do
    it "should abort if /api/services errored" do
      response = double(code: 500, body: {})
      expect_responses(unirest, test_url, response)
      expect { log_less_eosc_registry.call }.to raise_error(SystemExit).and output.to_stderr
    end
  end

  describe "#standard responses" do
    before(:each) do
      response = double(code: 200, body: create(:eosc_registry_services_response))
      expect_responses(unirest, test_url, response)
      allow_any_instance_of(Importers::Service).to receive(:map_provider).and_return(provider)
    end

    it "should create an offer for a new services" do
      expect { eosc_registry.call }.to output(/PROCESSED: 3, CREATED: 3, UPDATED: 0, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(3).and change { Offer.count }.by(3)
      service = Service.first

      expect(service.offers).to_not be_nil

      offer = service.offers.first

      expect(offer.name).to eq("Offer")
      expect(offer.description).to eq("#{service.name} Offer")
      expect(offer.order_type).to eq("other")
      expect(offer.status).to eq("published")

      expect(Service.find_by(name: "MetalPDB").offers).to_not be_nil
      expect(Service.find_by(name: "PDB_REDO server").offers).to_not be_nil
    end

    it "should not update service which has upstream to null" do
      service = create(:service)
      create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eosc_registry")

      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"], log: true)

      expect { eosc_registry.call }.to output(/PROCESSED: 3, CREATED: 0, UPDATED: 0, NOT MODIFIED: 1$/).to_stdout.and change { Service.count }.by(0)
      expect(Service.first.as_json(except: [:created_at, :updated_at])).to eq(service.as_json(except: [:created_at, :updated_at]))
    end

    it "should update service which has upstream to external id and repeated providers" do
      service = create(:service)
      create(:offer, service: service)
      source = create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eosc_registry")
      service.update!(upstream_id: source.id)

      service.reload

      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"], log: true)

      expect { eosc_registry.call }.to output(/PROCESSED: 3, CREATED: 0, UPDATED: 1, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(0)
      expect(Service.first.as_json(except: [:created_at, :updated_at])).to eq(service.as_json(except: [:created_at, :updated_at]))
    end

    it "should not create an offer for updated services with offers" do
      service = create(:service, status: :published)
      create(:offer, service: service)
      source = create(:service_source, eid: "phenomenal.phenomenal", service_id: service.id, source_type: "eosc_registry")
      service.update!(upstream_id: source.id)

      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"], log: true)

      expect { eosc_registry.call }.to output(/PROCESSED: 3, CREATED: 0, UPDATED: 1, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(0).and change { Offer.count }.by(0)
    end

    it "should not change db if dry_run is set to true" do
      eosc_registry = make_and_stub_eosc_registry(dry_run: true, log: true)
      expect { eosc_registry.call }.to output(/PROCESSED: 3, CREATED: 3, UPDATED: 0, NOT MODIFIED: 0$/).to_stdout.and change { Service.count }.by(0).and change { Provider.count }.by(0)
    end

    it "should filter by ids if they are provided" do
      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"])
      expect { eosc_registry.call }.to change { Service.count }.by(1)
      expect(Service.last.name).to eq("PhenoMeNal")
    end

    it "should output file with unprocessed data (only selected services)" do
      filename = "eosc_registry_output.json"
      mock_file = StringIO.new
      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"], filepath: filename)
      expect(eosc_registry).to receive(:open).with(filename, "w").and_yield(mock_file)
      eosc_registry.call
      expect(mock_file.string).to eq(file_fixture("eosc_registry_import_output.json").read)
    end

    it "should gracefully handle error with logo download" do
      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"])
      allow(eosc_registry).to receive(:open).with("http://phenomenal-h2020.eu/home/wp-content/uploads/2016/06/PhenoMeNal_logo.png",
                                        ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE).and_raise(OpenURI::HTTPError.new("", status: 404))
      eosc_registry.call
      expect(Service.first.logo.attached?).to be_falsey
    end

    it "should gracefully handle error with logo download" do
      eosc_registry = make_and_stub_eosc_registry(ids: ["phenomenal.phenomenal"])
      allow(eosc_registry).to receive(:open).with("http://phenomenal-h2020.eu/home/wp-content/uploads/2016/06/PhenoMeNal_logo.png",
                                        ssl_verify_mode: OpenSSL::SSL::VERIFY_NONE).and_raise(Errno::EHOSTUNREACH.new)
      eosc_registry.call
      expect(Service.first.logo.attached?).to be_falsey
    end
  end
end