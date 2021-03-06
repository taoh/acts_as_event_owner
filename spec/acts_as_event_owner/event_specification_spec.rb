require File.expand_path('../../spec_helper', __FILE__)

describe ActsAsEventOwner::EventSpecification do
  before(:each) do
    clean_database!
    Time.zone = 'Eastern Time (US & Canada)'
  end

  describe "defaults" do
    it "defaults start_at to now" do
      now = Time.zone.now
      Time.stub!(:now).and_return(now)
      spec = new_event_specification
      spec.should be_valid
      spec.start_at.should == now
    end

    it "defaults duration to one hour" do
      spec = new_event_specification
      spec.should be_valid
      spec.end_at.should == spec.start_at + 1.hour
    end

    it "defaults repeat until forever" do
      spec = new_event_specification(:repeat => :daily)
      spec.should be_valid
      spec.until.should be_nil
    end
  end

  describe "validations" do
    it "requires a valid repeat interval" do
      spec = new_event_specification(:repeat => :bogus)
      spec.should_not be_valid
      spec.errors[:repeat].should be_present
    end

    it "requires a description" do
      spec = new_event_specification(:description => nil)
      spec.should_not be_valid
      spec.errors[:description].should be_present
    end
  end

  describe "non-recurring events" do
    it "passes validations" do
      new_event_specification.should be_valid
    end

    it "does not generate an RRULE" do
      new_event_specification.to_rrule.should be_nil
    end
  end

  describe "events recurring multiple times per day" do
    it "passes validations" do
      new_event_specification(:repeat => :by_hour, :target => [8, 12, 16]).should be_valid
    end

    it "defaults start_at to the first occurrence" do
      now = Time.zone.now
      Time.stub!(:now).and_return(Time.local(2011, 1, 15, 8, 23))
      create_event_specification(:repeat => :by_hour, :target => [8, 12, 16], :generate => false).start_at.should == Time.local(2011, 1, 15, 12, 00)

      Time.stub!(:now).and_return(Time.local(2011, 1, 15, 23, 23))
      create_event_specification(:repeat => :by_hour, :target => [8, 12, 16], :generate => false).start_at.should == Time.local(2011, 1, 16, 8, 00)
    end

    it "does not support invalid recurrence specifications" do
      spec = new_event_specification(:repeat => :by_hour)
      spec.should_not be_valid
      spec.errors[:target].should be_present

      spec = new_event_specification(:repeat => :by_hour, :on_the => :first)
      spec.should_not be_valid
      spec.errors[:on_the].should be_present

      spec = new_event_specification(:repeat => :by_hour, :on => [1,2])
      spec.should_not be_valid
      spec.errors[:on].should be_present

      spec = new_event_specification(:repeat => :by_hour, :target => 8)
      spec.should_not be_valid
      spec.errors[:target].should be_present
    end

    it "generates an RRULE" do
      # every day at 08:00, 12:00, and 16:00
      new_event_specification(:repeat => :by_hour, :target => [8,12,16]).to_rrule.should == "FREQ=DAILY;BYHOUR=8,12,16"
    end

  end

  describe "events recurring daily" do
    it "passes validations" do
      new_event_specification(:repeat => :daily).should be_valid
      new_event_specification(:repeat => :daily, :frequency => 4).should be_valid
    end

    it "does not support invalid recurrence specifications" do
      spec = new_event_specification(:repeat => :daily, :frequency => 'foo')
      spec.should_not be_valid
      spec.errors[:frequency].should be_present

      spec = new_event_specification(:repeat => :daily, :on => [1, 2])
      spec.should_not be_valid
      spec.errors[:on].should be_present

      spec = new_event_specification(:repeat => :daily, :on_the => :first)
      spec.should_not be_valid
      spec.errors[:on_the].should be_present

      spec = new_event_specification(:repeat => :daily, :on_the => :first, :target => :wkday)
      spec.should_not be_valid
      spec.errors[:target].should be_present
    end

    it "defaults frequency to 1" do
      new_event_specification(:repeat => :daily).frequency.should == 1
    end

    it "generates an RRULE" do
      # every day
      new_event_specification(:repeat => :daily).to_rrule.should == "FREQ=DAILY;INTERVAL=1"
      # every four days
      new_event_specification(:repeat => :daily, :frequency => 4).to_rrule.should == "FREQ=DAILY;INTERVAL=4"
    end
  end

  describe "events recurring weekly" do
    it "passes validations" do
      new_event_specification(:repeat => :weekly).should be_valid
      new_event_specification(:repeat => :weekly, :frequency => 2).should be_valid
      new_event_specification(:repeat => :weekly, :on => [:mo, :we, :fr]).should be_valid
      new_event_specification(:repeat => :weekly, :frequency => 2, :on => [:mo, :we, :fr]).should be_valid
      new_event_specification(:repeat => :weekly, :frequency => 2, :on => [:mo, :we, :fr], :until => Time.parse("12/31/2010")).should be_valid
    end

    it "does not support invalid recurrence specifications" do
      spec = new_event_specification(:repeat => :weekly, :frequency => 'foo')
      spec.should_not be_valid
      spec.errors[:frequency].should be_present

      spec = new_event_specification(:repeat => :weekly, :on_the => :first, :target => :wkend)
      spec.should_not be_valid
      spec.errors[:on_the].should be_present
      spec.errors[:target].should be_present

      spec = new_event_specification(:repeat => :weekly, :on => '2')
      spec.should_not be_valid
      spec.errors[:on].should be_present
    end

    it "generates an RRULE" do
      # every week
      new_event_specification(:repeat => :weekly).to_rrule.should == "FREQ=WEEKLY;INTERVAL=1"
      # every two weeks
      new_event_specification(:repeat => :weekly, :frequency => 2).to_rrule.should == "FREQ=WEEKLY;INTERVAL=2"
      # every monday, wednesday, and friday
      new_event_specification(:repeat => :weekly, :on => [:mo, :we, :fr]).to_rrule.should == "FREQ=WEEKLY;INTERVAL=1;BYDAY=MO,WE,FR"
      # every other monday, wednesday, and friday
      new_event_specification(:repeat => :weekly, :frequency => 2, :on => [:mo, :we, :fr]).to_rrule.should == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR"
      # every other monday, wednesday, and friday, until 12/31/2010
      new_event_specification(:repeat => :weekly, :frequency => 2, :on => [:mo, :we, :fr], :until => Time.parse("12/31/2010")).to_rrule.should == "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,WE,FR;UNTIL=20101231T000000"
    end
  end

  describe "events recurring monthly" do
    it "passes validations" do
      new_event_specification(:repeat => :monthly).should be_valid
      new_event_specification(:repeat => :monthly, :frequency => 2).should be_valid
      new_event_specification(:repeat => :monthly, :frequency => 2, :on => [1, 15, 20]).should be_valid
      new_event_specification(:repeat => :monthly, :frequency => 2, :on_the => :third, :target => :wkday).should be_valid
      new_event_specification(:repeat => :monthly, :frequency => 2, :on_the => :third, :target => [:mo, :we], :until => Time.parse("12/31/2010")).should be_valid
    end

    it "does not support invalid recurrence specification" do
      spec = new_event_specification(:repeat => :monthly, :frequency => 'foo')
      spec.should_not be_valid
      spec.errors[:frequency].should be_present

      spec = new_event_specification(:repeat => :monthly, :on => 2)
      spec.should_not be_valid
      spec.errors[:on].should be_present

      spec = new_event_specification(:repeat => :monthly, :on => [2], :on_the => :first, :target => :wkday)
      spec.should_not be_valid
      spec.errors[:on].should be_present

      spec = new_event_specification(:repeat => :monthly, :on_the => 2)
      spec.should_not be_valid
      spec.errors[:on_the].should be_present

      spec = new_event_specification(:repeat => :monthly, :on_the => :first, :target => :we)
      spec.should_not be_valid
      spec.errors[:target].should be_present

      spec = new_event_specification(:repeat => :monthly, :on_the => :first, :on => [2])
      spec.should_not be_valid
      spec.errors[:on].should be_present
    end

    it "generates an RRULE" do
      # every month
      new_event_specification(:repeat => :monthly).to_rrule.should == "FREQ=MONTHLY;INTERVAL=1"
      # every two months
      new_event_specification(:repeat => :monthly, :frequency => 2).to_rrule.should == "FREQ=MONTHLY;INTERVAL=2"
      # every other month, on the 1st, 15th, and 20th
      new_event_specification(:repeat => :monthly, :frequency => 2, :on => [1, 15, 20]).to_rrule.should == "FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=1,15,20"
      # every other month, on the third weekday of the month
      new_event_specification(:repeat => :monthly, :frequency => 2, :on_the => :third, :target => :wkday).to_rrule.should == "FREQ=MONTHLY;INTERVAL=2;BYSETPOS=3;BYDAY=MO,TU,WE,TH,FR"
      # every other month, on the third monday and third wednesday, until 12/31/2010
      new_event_specification(:repeat => :monthly, :frequency => 2, :on_the => :third, :target => [:mo, :we], :until => Time.parse("12/31/2010")).to_rrule.should == "FREQ=MONTHLY;INTERVAL=2;BYSETPOS=3;BYDAY=MO,WE;UNTIL=20101231T000000"
    end
  end

  describe "events recurring yearly" do
    it "passes validations" do
      new_event_specification(:repeat => :yearly).should be_valid
      new_event_specification(:repeat => :yearly, :frequency => 3).should be_valid
      new_event_specification(:repeat => :yearly, :on => [1,7]).should be_valid
      new_event_specification(:repeat => :yearly, :frequency => 2, :on => [1,7]).should be_valid
      new_event_specification(:repeat => :yearly, :on => [1,7], :on_the => :first, :target => :wkend).should be_valid
      new_event_specification(:repeat => :yearly, :frequency => 2, :on => [1,7], :on_the => :first, :target => :wkday, :until => Time.parse("12/31/2010")).should be_valid
    end

    it "does not support invalid recurrence rules" do
      spec = new_event_specification(:repeat => :yearly, :frequency => 'foo')
      spec.should_not be_valid
      spec.errors[:frequency].should be_present

      spec = new_event_specification(:repeat => :yearly, :on => 2)
      spec.should_not be_valid
      spec.errors[:on].should be_present

      spec = new_event_specification(:repeat => :yearly, :on => [2], :on_the => 'first')
      spec.should_not be_valid
      spec.errors[:on_the].should be_present

      spec = new_event_specification(:repeat => :yearly, :on => [2], :on_the => :first, :target => 2)
      spec.should_not be_valid
      spec.errors[:target].should be_present
    end

    it "generates an RRULE" do
      # every year
      new_event_specification(:repeat => :yearly).to_rrule.should == "FREQ=YEARLY;INTERVAL=1"
      # every third year
      new_event_specification(:repeat => :yearly, :frequency => 3).to_rrule.should == "FREQ=YEARLY;INTERVAL=3"
      # every year in january and july
      new_event_specification(:repeat => :yearly, :on => [1,7]).to_rrule.should == "FREQ=YEARLY;INTERVAL=1;BYMONTH=1,7"
      # every other year, in january and july
      new_event_specification(:repeat => :yearly, :frequency => 2, :on => [1,7]).to_rrule.should == "FREQ=YEARLY;INTERVAL=2;BYMONTH=1,7"
      # every year, on the first weekend day in january and july
      new_event_specification(:repeat => :yearly, :on => [1,7], :on_the => :first, :target => :wkend).to_rrule.should == "FREQ=YEARLY;INTERVAL=1;BYMONTH=1,7;BYSETPOS=1;BYDAY=SU,SA"
      # every other year, on the first weekday in january and july, until 12/31/2010
      new_event_specification(:repeat => :yearly, :frequency => 2, :on => [1,7], :on_the => :first, :target => :wkday, :until => Time.parse("12/31/2010")).to_rrule.should == "FREQ=YEARLY;INTERVAL=2;BYMONTH=1,7;BYSETPOS=1;BYDAY=MO,TU,WE,TH,FR;UNTIL=20101231T000000"
    end
  end

  describe "#generate_events" do
    before(:each) do
      @now = Time.zone.now
      @bod = Date.today.to_time
    end

    describe "non-recurring events" do
      before(:each) do
        @spec = create_event_specification :start_at => @now, :added_string => 'foo', :added_boolean => true, :added_datetime => Date.yesterday.to_time.in_time_zone, :generate => false
      end

      it "generates a single event" do
        lambda {
          @spec.generate_events
        }.should change(EventOccurrence, :count).by(1)
      end

      it "copies base columns from event_specifications to event occurences" do
        @spec.generate_events
        @spec.event_occurrences.first.description.should == @spec.description
      end

      it "copies added columns from event_specifications to event_occurrences" do
        @spec.generate_events
        @spec.event_occurrences.first.added_string.should == @spec.added_string
        @spec.event_occurrences.first.added_boolean.should == @spec.added_boolean
        @spec.event_occurrences.first.added_datetime.should == @spec.added_datetime
      end

      it "allows attribute overrides" do
        @spec.generate_events :attributes => { :description => 'something new', :added_string => 'something else new'}
        @spec.event_occurrences.first.description.should == 'something new'
        @spec.event_occurrences.first.added_string.should == 'something else new'
      end
    end

    describe "recurring events" do
      before(:each) do
        @spec = create_event_specification :description => 'walk the dog', :start_at => @now, :repeat => :daily, :frequency => 1, :generate => false
      end

      it "generates recurring events according to the rrule" do
        lambda {
          @spec.generate_events :from => @bod, :to => @bod + 1.week
        }.should change(EventOccurrence, :count).by(7)
      end

      it "does not generate events before the specified :from" do
        lambda {
          @spec.generate_events :from => @bod + 1.day, :to => @bod + 1.week
        }.should change(EventOccurrence, :count).by(6)
      end

      it "does not generate events after the specified :to" do
        lambda {
          @spec.generate_events :from => @bod + 1.day, :to => @bod + 6.days
        }.should change(EventOccurrence, :count).by(5)
      end

      it "does not generate more events than the specified :count" do
        lambda {
          @spec.generate_events :from => @bod, :to => @bod + 1.week, :count => 3
        }.should change(EventOccurrence, :count).by(3)
      end

      it "returns the new events" do
        events = @spec.generate_events :from => @bod, :to => @bod + 1.week
        events.should be_present
        events.first.class.should == EventOccurrence
      end

      it "returns but does not persist duplicate events" do
        lambda {
          @spec.generate_events :from => @bod, :to => @bod + 1.week
        }.should change(EventOccurrence, :count).by(7)

        lambda {
          events = @spec.generate_events :from => @bod, :to => @bod + 1.week
          events.should be_present
          events.size.should == 7
        }.should_not change(EventOccurrence, :count)
      end

      it "raises an exception if the event specification is invalid" do
        spec = new_event_specification(:description => nil)
        spec.should_not be_valid
        lambda {
          spec.generate_events :from => @bod
        }.should raise_error(ActsAsEventOwner::Exception)
      end

      it "does not generate events for specifications that are past their end_at" do
        @spec.update_attributes! :start_at => @now - 1.week, :until => @now - 2.days
        lambda {
          @spec.generate_events :from => @bod, :to => @bod + 1.week
        }.should_not change(EventOccurrence, :count)
      end
    end
  end

  describe "autogeneration" do
    before(:each) do
      @now = Time.zone.now
      @bod = Date.today.to_time
    end

    def create_daily_event(generate=nil)
      create_event_specification :description => 'walk the dog', :start_at => @now, :repeat => :daily, :frequency => 2, :generate => generate
    end

    it "generates 30 days worth of events by default" do
      lambda {
        create_daily_event
      }.should change(EventOccurrence, :count).by(15)
    end

    it "does not generate any events if the :generate attribute is set to false" do
      lambda {
        create_daily_event(false)
      }.should_not change(EventOccurrence, :count)
    end

    it "generates events according the :generate attribute" do
      lambda {
        create_daily_event(:to => @now + 15.days)
      }.should change(EventOccurrence, :count).by(8)

      lambda {
        create_daily_event(:count => 5)
      }.should change(EventOccurrence, :count).by(5)
    end
  end

  describe "self.generate_events" do
    before(:each) do
      @now = Time.zone.now
      @bod = Date.today.to_time
      @walking_the_dog = create_event_specification :description => 'walk the dog', :start_at => @now, :repeat => :daily, :frequency => 1, :generate => false
      @taking_out_the_trash = create_event_specification :description => 'take out the trash', :start_at => @now, :repeat => :daily, :frequency => 3, :generate => false
    end

    it "generates events for all event specifications" do
      lambda {
        ActsAsEventOwner::EventSpecification.generate_events :from => @bod, :to => @bod + 1.week
      }.should change(EventOccurrence, :count).by(10)
    end
  end

  describe "timezone support" do
    context "repeating events" do
      context "with UTC times" do
        before do
          Time.zone = 'UTC'
        end
        
        it "generates the occurrences properly" do
          @now = Time.zone.local(2011, 1, 16, 23, 00)  # sunday
          spec = create_event_specification :description => "mwf event", :start_at => @now, :repeat => :weekly, :on => [:mo, :we, :fr]
          occurrence = spec.event_occurrences[1]
          occurrence.start_at.in_time_zone.wday.should == 1
          occurrence.start_at.in_time_zone.hour.should == 23
        end
      end
      
      context "with local times" do
        before(:each) do
          Time.zone = 'Pacific Time (US & Canada)'
        end
        
        it "generates the occurrences properly" do
          @now = Time.zone.local(2011, 1, 16, 23, 00)  # sunday
          spec = create_event_specification :description => "mwf event", :start_at => @now, :repeat => :weekly, :on => [:mo, :we, :fr]
          occurrence = spec.event_occurrences[1].reload
          # puts "*************** #{occurrence.start_at}"
          # puts "*************** #{occurrence.start_at.zone}"
          occurrence.start_at.in_time_zone.wday.should == 1
          occurrence.start_at.in_time_zone.hour.should == 23
        end
      end
      
      context "with conflicting time zones" do
        it "generates events with erroneous start_at values" do
          Time.zone = 'Pacific Time (US & Canada)'
          @now = Time.zone.local(2011, 1, 16, 23, 00)  # sunday
          spec = create_event_specification :description => "mwf event", :start_at => @now, :repeat => :weekly, :on => [:mo, :we, :fr], :generate => false
          Time.zone = 'Eastern Time (US & Canada)'
          spec.generate_events
          occurrence = spec.event_occurrences[1]
          occurrence.start_at.hour.should_not == 23
        end
      end
    end
  end
end
