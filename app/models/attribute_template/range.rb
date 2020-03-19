# frozen_string_literal: true

class AttributeTemplate::Range < AttributeTemplate
  attr_accessor :min, :max, :exclusive_min, :exclusive_max

  validates :min, numericality: { greater_than_or_equal_to: 0 }
  validates :max, numericality: { greater_than_or_equal_to: 0 }

  validate do
    if min >= max
      errors.add(:min, "must be less than maximum value")
      errors.add(:max, "must be greater than minimum value")
    end
  end

  def to_attribute
    Attribute::Range.new.tap do |attr|
      attr.id = id
      attr.label = name
      attr.description = hint
    end
  end
end
