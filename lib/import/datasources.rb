# frozen_string_literal: true

class Import::Datasources
  include Importable

  def initialize(
    eosc_registry_base_url,
    dry_run: true,
    ids: [],
    filepath: nil,
    faraday: Faraday,
    logger: ->(msg) { puts msg },
    default_upstream: :eosc_registry,
    token: nil,
    rescue_mode: false
  )
    @eosc_registry_base_url = eosc_registry_base_url
    @dry_run = dry_run
    @faraday = faraday
    @default_upstream = default_upstream
    @token = token
    @rescue_mode = rescue_mode

    @logger = logger
    @ids = ids || []
    @filepath = filepath

    @created_count = 0
    @updated_count = 0
    @not_modified_count = 0
  end

  def call
    log "Importing datasources from EOSC Registry..."
    datasources_data = external_datasources_data
    request_datasources = datasources_data.select { |res| @ids.empty? || @ids.include?(eid(res)) }
    output = []

    log "EOSC Registry - all datasources #{datasources_data.length}"

    request_datasources.each do |datasource_data|
      output.append(datasource_data)
      import_datasource(datasource_data)
    end

    log "PROCESSED: #{datasources_data.length}, CREATED: #{@created_count}, " \
          "UPDATED: #{@updated_count}, NOT MODIFIED: #{@not_modified_count}"

    Datasource.reindex

    File.open(@filepath, "w") { |file| file << JSON.pretty_generate(output) } unless @filepath.nil?
  end

  private

  def external_datasources_data
    begin
      @token ||= Importers::Token.new(faraday: @faraday).receive_token
      response =
        Importers::Request.new(@eosc_registry_base_url, "public/datasource", faraday: @faraday, token: @token).call
    rescue Errno::ECONNREFUSED, Importers::Token::RequestError => e
      abort("import exited with errors - could not connect to #{@eosc_registry_base_url} \n #{e.message}")
    end
    response.body["results"]
  end

  def name(datasource_data)
    datasource_data["name"] || datasource_data.dig("service", "name")
  end

  def eid(datasource_data)
    datasource_data["id"] || datasource_data.dig("service", "id")
  end

  def registry_status(datasource_data, datasource_payload)
    status_source = datasource_data.key?("active") ? datasource_data : datasource_payload

    object_status(status_source["active"], status_source["suspended"]) if status_source.key?("active")
  end

  def import_datasource(datasource_data)
    datasource, image_url = parse_datasource_data(datasource_data)
    datasource_source = ServiceSource.find_by(eid: datasource[:pid], source_type: "eosc_registry")

    if datasource_source.nil?
      create_new_datasource(datasource, image_url)
    else
      import_existing_datasource(datasource, image_url, datasource_source)
    end
  rescue ActiveRecord::RecordInvalid => e
    log "[ERROR] - #{e}! #{name(datasource_data)} (eid: #{eid(datasource_data)}) will NOT be created"
  rescue StandardError => e
    log "[ERROR] - Unexpected #{e}! #{name(datasource_data)} (eid: #{eid(datasource_data)}) will NOT be created!"
  end

  def parse_datasource_data(datasource_data)
    synchronized_at = datasource_data.dig("metadata", "modifiedAt")&.to_i || Time.now.to_i
    datasource_payload = registry_payload(datasource_data)
    datasource = Importers::Datasource.call(datasource_payload, synchronized_at)
    image_url = datasource.delete(:logo_url)
    datasource[:type] = "Datasource"
    datasource[:status] = registry_status(datasource_data, datasource_payload) || :published

    [datasource, image_url]
  end

  def registry_payload(datasource_data)
    datasource_data["service"]&.merge(datasource_data["resourceExtras"] || {}) || datasource_data
  end

  def create_new_datasource(datasource, image_url)
    @created_count += 1
    log "Adding [NEW] datasource: #{datasource[:name]}, eid: #{datasource[:pid]}"
    create_datasource(datasource, image_url) unless @dry_run
  end

  def import_existing_datasource(datasource, image_url, datasource_source)
    existing_datasource = Datasource.find_by(id: datasource_source.service_id)
    if existing_datasource&.upstream_id == datasource_source.id
      @updated_count += 1
      log "Updating [EXISTING] datasource #{datasource[:name]}, " +
            "id: #{datasource_source["id"]}, eid: #{datasource[:pid]}"
      update_datasource(existing_datasource, datasource, image_url) unless @dry_run
    else
      @not_modified_count += 1
      log "Datasource upstream is not set to EOSC Registry," \
            " not updating #{existing_datasource&.name}, id: #{datasource_source.id}"
    end
  end

  def create_datasource(datasource, image_url)
    datasource = Datasource.new(datasource)
    if datasource.valid?
      Importers::Logo.call(datasource, image_url) unless @rescue_mode
      datasource = Service::Create.call(datasource)
      datasource_source =
        ServiceSource.create!(service_id: datasource.id, eid: datasource.pid, source_type: "eosc_registry")
      update_from_eosc_registry(datasource, datasource_source, true)
    else
      datasource.status = %w[published suspended].include?(datasource.status) ? :errored : :draft
      datasource.save(validate: false)
      datasource_source =
        ServiceSource.create!(service_id: datasource.id, eid: datasource.pid, source_type: "eosc_registry")
      update_from_eosc_registry(datasource, datasource_source, false)
      log "Datasource #{datasource.name}, eid: #{datasource.pid} saved with errors: #{datasource.errors.full_messages}"

      Importers::Logo.call(datasource, image_url) unless @rescue_mode
      datasource.save(validate: false)
    end
  end

  def update_datasource(existing_datasource, datasource, image_url)
    Importers::Logo.call(existing_datasource, image_url) unless @rescue_mode
    Service::Update.call(existing_datasource, datasource)
  end

  def update_from_eosc_registry(datasource, datasource_source, validate)
    return unless @default_upstream == :eosc_registry

    datasource.upstream_id = datasource_source.id
    datasource.save(validate: validate)
  end

  def log(msg)
    @logger.call(msg)
  end
end
