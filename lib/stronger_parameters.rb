Bundler.require(:default)
require 'active_model'
require 'active_support/hash_with_indifferent_access'
require 'active_support/core_ext/hash'
require 'set'

class StrongerParameters < ActiveSupport::HashWithIndifferentAccess
  include ActiveModel::Validations

  def self.name
    "StrongerParamters"
  end

  module WhistListing
    def validate(model)
      model.allowed_params.merge(attributes)
      super
    end
  end

  def self.validates_nested(*attr_names, &block)
    validates_with StrongerParameters::NestedValidator, _merge_attributes(attr_names), &block
  end
  
  class NestedValidator < ActiveModel::EachValidator
    def initialize(options, &block)
      options[:with] ||= Class.new(StrongerParameters, &block)
      super
    end

    def validate_nested(record, attribute, value)
      return if there_is_no_reason_to_validate(value)

      errors = value.is_a?(Array) ? errors_from_array(value) : errors_from_hash(value)
      record.errors.add(attribute, errors) unless errors.empty?
    end

    def validate_each(record, attribute, value)
      record.allowed_params << attribute
      nested = record[attribute]

      if nested.is_a?(Array)
        nested.each {|n| validate_nested(record, attribute, value)}
      else
        validate_nested(record, attribute, value)
      end
    end
    
    private
    def there_is_no_reason_to_validate(value)
      value.nil? && !options[:presence]  
    end

    def errors_from_array(array)
      array.inject([]) do |errors, item|
        nested = options[:with].new(item)
        errors << nested.errors unless nested.valid?
        errors
      end
    end

    def errors_from_hash(hash)
      hash = options[:with].new(hash)
      hash.valid?
      hash.errors
    end
  end

  class InclusionValidator < ActiveModel::Validations::InclusionValidator # :nodoc:
    include WhistListing
  end

  class LengthValidator < ActiveModel::Validations::LengthValidator # :nodoc:
    include WhistListing
  end

  class ExclusionValidator < ActiveModel::Validations::ExclusionValidator # :nodoc:
    include WhistListing
  end 

  class PresenceValidator < ActiveModel::Validations::PresenceValidator # :nodoc:
    include WhistListing
  end 

  class AllowedValidator < ActiveModel::EachValidator
    def validate(model)
      model.allowed_params.merge(attributes)
    end
  end

  def allowed_params
    @allowed_params ||= Set.new([:controller, :action, :format])
  end

  # Params cannot be set. Not sure what is
  # calling this method
  def []=(key,val)
  end

  def read_attribute_for_validation(key)
    self[key]
  end

  def whitelist!
    not_allowed = self.keys - allowed_params.collect(&:to_s)
    
    if not_allowed.any?
      not_allowed.each do |k|
        errors.add(k, "is not allowed") 
      end
      return false
    end

    true
  end

  def valid?(context = nil)
    super && whitelist!
  end
end
