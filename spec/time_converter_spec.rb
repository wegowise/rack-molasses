require 'spec_helper'

describe Rack::Molasses::TimeConverter do

  let(:converter) { subject.class }

  describe '.to_seconds' do

    it "converts seconds to seconds" do
      converter.to_seconds('20 seconds').should == 20
    end

    it "converts minutes to seconds" do
      converter.to_seconds('56 minutes').should == 56 * TestHelp::ONE_MINUTE
    end

    it "converts hours to seconds" do
      converter.to_seconds('5 hours').should == 5 * TestHelp::ONE_HOUR
    end

    it "converts days to seconds" do
      converter.to_seconds('15 days').should == 15 * TestHelp::ONE_DAY
    end

    it "converts weeks to seconds" do
      converter.to_seconds('9 weeks').should == 9 * TestHelp::ONE_WEEK
    end

    it "converts months to seconds" do
      converter.to_seconds('8 months').should == 8 * TestHelp::ONE_MONTH
    end

    it "converts years to seconds" do
      converter.to_seconds('2 years').should == 2 * TestHelp::ONE_YEAR
    end

    it "handles the singular case" do
      converter.to_seconds('1 second').should == 1
      converter.to_seconds('1 minute').should == TestHelp::ONE_MINUTE
      converter.to_seconds('1 hour').should == TestHelp::ONE_HOUR
      converter.to_seconds('1 day').should == TestHelp::ONE_DAY
      converter.to_seconds('1 week').should == TestHelp::ONE_WEEK
      converter.to_seconds('1 month').should == TestHelp::ONE_MONTH
      converter.to_seconds('1 year').should == TestHelp::ONE_YEAR
    end

    it "should raise an error when units not recognized" do
      lambda { converter.to_seconds('8 jiffys') }.should raise_error(Rack::Molasses::Error)
    end

  end

end
