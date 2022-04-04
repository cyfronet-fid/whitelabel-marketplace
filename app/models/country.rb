# frozen_string_literal: true

class Country
  SCHENGEN = %w[AT BE CH CZ DE DK EE EL ES FI FR HU IS IT LI LT LU LV MT NL NO PL PT SE SI SK].freeze

  REGIONS = %w[WW EO EU EZ AH].freeze

  ISO3166::Data.register(alpha2: "WW", iso_short_name: "World", translations: { "en" => "Worldwide" })

  ISO3166::Data.register(alpha2: "EO", iso_short_name: "Europe", translations: { "en" => "Europe" })

  ISO3166::Data.register(alpha2: "EU", iso_short_name: "European Union", translations: { "en" => "European Union" })

  ISO3166::Data.register(alpha2: "EZ", iso_short_name: "Euro Zone", translations: { "en" => "Euro Zone" })

  ISO3166::Data.register(alpha2: "AH", iso_short_name: "Schengen Area", translations: { "en" => "Schengen Area" })

  ISO3166::Data.register(alpha2: "N/E", iso_short_name: "non-European", translations: { "en" => "non-European" })

  ISO3166::Data.unregister("GB")
  ISO3166::Data.unregister("GR")

  ISO3166::Data.register(
    alpha2: "UK",
    iso_short_name: "United Kingdom of Great Britain and Northern Ireland",
    region: "Europe",
    eu_member: false,
    eea_member: false,
    translations: {
      "en" => "United Kingdom of Great Britain and Northern Ireland"
    }
  )

  ISO3166::Data.register(
    alpha2: "EL",
    iso_short_name: "Greece",
    region: "Europe",
    eu_member: true,
    eea_member: true,
    translations: {
      "en" => "Greece"
    }
  )

  class << self
    def for(value)
      return value if value.is_a?(ISO3166::Country)

      searched_country = ISO3166::Country.new(value)
      return searched_country if searched_country.present? || value.blank?

      Sentry.capture_message("Country with alpha2 code: #{value}, couldn't be found")
      ISO3166::Country.new("N/E")
    end

    def load(code)
      return nil if code.blank?
      Country.for(code)
    end

    def dump(obj)
      return nil if obj.blank?
      obj.alpha2
    end

    def all
      @all ||= (ISO3166::Country.find_all_countries_by_region("Europe") + [ISO3166::Country.new("N/E")]).sort
    end

    def options
      ISO3166::Country.all
    end

    def countries_for_region(region)
      case region
      when "World"
        Country.world
      when "European Union"
        Country.european_union
      when "Schengen Area"
        Country.schengen_area
      when "Europe"
        ISO3166::Country.find_all_countries_by_region("Europe")
      when "Euro Zone"
        ISO3166::Country.find_all_countries_by_currency_code("EUR").select(&:in_eu?)
      else
        ISO3166::Country.find_all_countries_by_region(region)
      end
    end

    def european_union
      ISO3166::Country.all.select(&:in_eu?)
    end

    def world
      ISO3166::Country.all
    end

    def find_by_name(name)
      ISO3166::Country.find_country_by_iso_short_name(name)
    end

    def schengen_area
      Country::SCHENGEN.map { |p| ISO3166::Country.new(p) }
    end

    def convert(name)
      regions_for_country(name).blank? ? convert_name_to_code(name) : convert_to_regions_add_country(name)
    end

    def regions
      Country::REGIONS.map { |p| ISO3166::Country.new(p) }
    end

    def convert_name_to_code(name)
      Country.dump(Country.find_by_name(name))
    end

    def convert_to_regions_add_country(name)
      regions_for_country(name).push(convert_name_to_code(name))
    end

    def regions_for_country(country)
      regions = []
      regions.push(convert_name_to_code("World")) if Country.world.include?(Country.find_by_name(country))
      if Country.european_union.include?(Country.find_by_name(country))
        regions.push(convert_name_to_code("European Union"))
      end
      if Country.schengen_area.include?(Country.find_by_name(country))
        regions.push(convert_name_to_code("Schengen Area"))
      end
      if ISO3166::Country.find_all_countries_by_region("Europe").include?(Country.find_by_name(country))
        regions.push(convert_name_to_code("Europe"))
      end
      regions.map { |r| r }
    end
  end

  class Array
    class << self
      def load(code)
        return nil if code.blank?
        code.map { |c| Country.for(c) }
      end

      def dump(obj)
        return nil if obj.blank?
        obj.compact.map(&:alpha2)
      end

      # def push(obj)
      #   Array.prototype.push.call(this, el)
      # end
    end
  end
end
