require 'helper'

class TestPacketizedProtocol < Test::Unit::TestCase

  context "message parsing" do
    setup do
      @message = LIS::Message::Base.from_string("3L|1|N")
    end

    should "have correct frame number" do
      assert_equal 3, @message.frame_number
    end

    should "have correct type" do
      assert_equal LIS::Message::TerminatorRecord, @message.class
      assert_equal "L", @message.type_id
    end

    should "have correct sequence number" do
      assert_equal 1, @message.sequence_number
    end
  end

  context "parsing a result message" do
    setup do
      @str = "7R|1|^^^TSH|0.902|mIU/L|0.400\\0.004^4.00\\75.0|N|N|R|||20100115105636|20100115120641|B0135"
      @message = LIS::Message::Base.from_string(@str)
    end

    should "have correct type" do
      assert_equal LIS::Message::Result, @message.type
      assert_equal "R", @message.type_id
    end

    should "have correct test id" do
      assert_equal "TSH", @message.universal_test_id
    end

    should "have correct value" do
      assert_equal "0.902", @message.result_value
    end

    should "have currect value and unit" do
      assert_equal "mIU/L", @message.unit
    end
  end

end