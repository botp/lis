require 'date'

module LIS::Message
  module ClassMethods
    CONVERSION_WRITER = {
      :string => lambda { |s| s },
      :int => lambda { |s| s.to_i },
      :timestamp => lambda { |s| DateTime.strptime(s, "%Y%m%d%H%M%S") }
    }

    attr_reader :field_count

    def from_string(message)
      type, data = parse(message)
      klass = (@@messages_by_type || {})[type]
      raise "unknown message type #{type.inspect}" unless klass

      obj = klass.allocate
      obj.type_id = type

      data = data.to_enum(:each_with_index).inject({}) do |h,(elem,idx)|
        h[idx+2] = elem; h
      end

      obj.instance_variable_set("@fields", data)
      obj
    end

    def initialize_from_message(*list_of_fields)
    end

    def default_fields
      arr = Array.new(@field_count)
      (0 .. @field_count).inject(arr) do |arr,i|
        default = (get_field_attributes(i) || {})[:default]
        if default
          default = default.call if default.respond_to?(:call)
          arr[i-1] = default
        end
        arr
      end
    end

    def has_field(idx, name = nil, opts={})
      set_index_for(name, idx) if name
      set_field_attributes(idx, { :name => name,
                                  :type => opts[:type] || :string,
                                  :default => opts[:default]})

      @field_count = [@field_count || 0, idx].max

      return unless name

      define_method :"#{name}=" do |val|
        @fields ||= {}
        @fields[idx] = val
      end

      define_method :"#{name}" do
        field_attrs = self.class.get_field_attributes(idx)
        val = (@fields || {})[idx]
        converter = CONVERSION_WRITER[field_attrs[:type]] if field_attrs
        val = converter.call(val) if converter
        val
      end
    end

    def parse(string)
      type, data = string.scan(/^(.)\|(.*)$/)[0]
      data = data.split(/\|/)

      return [type, data]
    end

    def type_id(char = nil)
      return @@messages_by_type.find {|c,klass| klass == self }.first unless char
      @@messages_by_type ||= {}
      @@messages_by_type[char] = self
    end

    def set_index_for(field_name, idx)
      @field_indices ||= {}
      @field_indices[field_name] = idx
    end

    def get_index_for(field_name)
      val = @field_index[field_name]
      val ||= superclass.get_index_for(field_name) if superclass.respond_to?(:get_index_for)
      val
    end

    def get_field_attributes(index)
      @field_names ||= {}
      val = (@field_names || {})[index]
      val ||= superclass.get_field_attributes(index) if superclass.respond_to?(:get_field_attributes)
      val
    end

    #private

    def set_field_attributes(index, hash)
      @field_names ||= {}
      @field_names[index] = hash
    end
  end

  class Base
    extend ClassMethods
    attr_accessor :frame_number
    attr_accessor :type_id

    has_field 2, :sequence_number, :type => :int

    # def []=(idx, val)
    #   attrs = if (idx.is_a?(Symbol))
    #             #self.class.get_named_field_attributes(idx)
    #           else
    #             #{:name => nil, :type => :string}
    #           end
    #
    #   @field
    # end

    def type_id
     self.class.type_id
    end

    def to_message
      @fields ||= {}
      arr = Array.new(self.class.default_fields)
      type_id + @fields.inject(arr) { |a,(k,v)| a[k-1] = v; a }.join("|")
    end
  end


  class Header < Base
    type_id "H"
    has_field  2, :delimiter_definition, :default => "^&"
    has_field  4, :access_password, :default => "PASSWORD"
    has_field  5, :sender_name
    has_field  6, :sender_address
    has_field  7 # reserved
    has_field  8 # sender_telephone_number
    has_field  9, :sender_characteristics, :default => "8N1"
    has_field 10, :receiver_name
    has_field 11 # comments/special_instructions
    has_field 12, :processing_id, :default => "P"
    has_field 13, :version, :default => "1"
    has_field 14, :timestamp, :default => lambda { Time.now.strftime("%Y%m%d%H%M%S") }

    def initialize(sender_name = "SenderID", receiver_name = "ReceiverID")
      self.sender_name = sender_name
      self.receiver_name = receiver_name
    end

  end

  class Order < Base
    type_id "O"
    has_field 3, :specimen_id
    has_field 5, :universal_test_id
    has_field 6, :priority
    has_field 7, :requested_at
    has_field 8, :collected_at
  end

  class Result < Base
    type_id "R"
    has_field  3, :universal_test_id_internal
    has_field  4, :result_value
    has_field  5, :unit
    has_field  6, :reference_ranges
    has_field  7, :abnormal_flags
    has_field  9, :result_status
    has_field 12, :test_started_at, :type => :timestamp
    has_field 13, :test_completed_at, :type => :timestamp

    def universal_test_id
      universal_test_id_internal.gsub(/\^/,"")
    end
    def universal_test_id=(val)
      universal_test_id_internal = "^^^#{val}"
    end

  end

  class Patient < Base
    type_id "P"
  end

  class Query < Base
    type_id "Q"
    has_field 3, :starting_range_id_internal

    def starting_range_id
      starting_range_id_internal.gsub(/\^/,"")
    end
    def starting_range_id=(val)
      starting_range_id_internal = "^#{val}"
    end
  end


  class TerminatorRecord < Base
    TERMINATION_CODES = {
      "N" => "Normal termination",
      "T" => "Sender Aborted",
      "R" => "Receiver Abort",
      "E" => "Unknown system error",
      "Q" => "Error in last request for information",
      "I" => "No information available from last query",
      "F" => "Last request for information Processed"
    }

    type_id "L"
    has_field 3, :termination_code
  end

end