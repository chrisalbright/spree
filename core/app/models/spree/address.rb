module Spree
  class Address < ActiveRecord::Base
    belongs_to :country
    belongs_to :state

    has_many :shipments

    validates :firstname, :lastname, :address1, :city, :zipcode, :country, :phone, :presence => true
    validate :state_validate

    attr_accessible :country, :as => :internal

    attr_accessible :firstname, :lastname, :address1, :address2, :city, :zipcode, :country_id, :state_id, :phone, :state_name, :company, :alternative_phone

    # disconnected since there's no code to display error messages yet OR matching client-side validation
    def phone_validate
      return if phone.blank?
      n_digits = phone.scan(/[0-9]/).size
      valid_chars = (phone =~ /^[-+()\/\s\d]+$/)
      if !(n_digits > 5 && valid_chars)
        errors.add(:phone, :invalid)
      end
    end

    def self.default
      country = Spree::Country.find(Spree::Config[:default_country_id]) rescue Spree::Country.first
      new({:country => country}, :as => :internal)
    end

    # can modify an address if it's not been used in an order (but checkouts controller has finer control)
    # def editable?
    #   new_record? || (shipments.empty? && checkouts.empty?)
    # end

    def full_name
      "#{firstname} #{lastname}".strip
    end

    def state_text
      state.nil? ? state_name : (state.abbr.blank? ? state.name : state.abbr)
    end

    def zone
      (state && state.zone) || (country && country.zone)
    end

    def zones
      Zone.match(self)
    end

    def same_as?(other)
      return false if other.nil?
      attributes.except('id', 'updated_at', 'created_at') ==  other.attributes.except('id', 'updated_at', 'created_at')
    end

    alias same_as same_as?

    def to_s
      "#{full_name}: #{address1}"
    end

    def clone
      self.class.new(self.attributes.except('id', 'updated_at', 'created_at'))
    end

    def ==(other_address)
      self_attrs = self.attributes
      other_attrs = other_address.respond_to?(:attributes) ? other_address.attributes : {}

      [self_attrs, other_attrs].each { |attrs| attrs.except!('id', 'created_at', 'updated_at', 'order_id') }

      self_attrs == other_attrs
    end

    def empty?
      attributes.except('id', 'created_at', 'updated_at', 'order_id', 'country_id').all? { |_, v| v.nil? }
    end

    private

      def state_validate
        #skip state validation without country (also required)
        #or when disabled by perfernce
        return if !country.present? || !Spree::Config[:address_requires_state]

        #ensure associated state belongs to country
        if state.present?
          if state.country == country
            self.state_name = nil #not required as we have a valid state and country combo
          else
            if state_name.present?
              self.state = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        #ensure state_name belongs to country without states, or that it matches a predefined state name/abbr
        if state_name.present?
          if country.states.present?
            states = country.states.find_all_by_name_or_abbr(state_name)

            if states.size == 1
              self.state = states.first
              self.state_name = nil
            else
              errors.add(:state, :invalid)
            end
          end
        end

        #ensure at least one state field is populated
        if !state.present? && state_name.blank?
          errors.add(:state, :blank)
        end
      end

  end
end