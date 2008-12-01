require File.dirname(__FILE__) + '/database'

class SimpleJob
  cattr_accessor :runs; self.runs = 0
  def perform; @@runs += 1; end
end

class ErrorJob
  cattr_accessor :runs; self.runs = 0
  def perform; raise 'did not work'; end
end

describe Delayed::Job do
  before  do               
    Delayed::Job.max_priority = nil
    Delayed::Job.min_priority = nil      
    
    Delayed::Job.delete_all
  end
  
  before(:each) do
    SimpleJob.runs = 0
  end

  it "should set run_at automatically if not set" do
    Delayed::Job.create(:payload_object => ErrorJob.new ).run_at.should_not == nil
  end

  it "should not set run_at automatically if already set" do
    later = 5.minutes.from_now
    Delayed::Job.create(:payload_object => ErrorJob.new, :run_at => later).run_at.should == later
  end

  it "should raise ArgumentError when handler doesn't respond_to :perform" do
    lambda { Delayed::Job.enqueue(Object.new) }.should raise_error(ArgumentError)
  end

  it "should increase count after enqueuing items" do
    Delayed::Job.enqueue SimpleJob.new
    Delayed::Job.count.should == 1
  end

  it "should be able to set priority when enqueuing items" do
    Delayed::Job.enqueue SimpleJob.new, 5
    Delayed::Job.first.priority.should == 5
  end

  it "should be able to set run_at when enqueuing items" do
    later = 5.minutes.from_now
    Delayed::Job.enqueue SimpleJob.new, 5, later

    # use be close rather than equal to because millisecond values cn be lost in DB round trip
    Delayed::Job.first.run_at.should be_close(later, 1)
  end

  it "should call perform on jobs when running work_off" do
    SimpleJob.runs.should == 0

    Delayed::Job.enqueue SimpleJob.new
    Delayed::Job.work_off

    SimpleJob.runs.should == 1
  end

  it "should re-schedule by about 1 second at first and increment this more and more minutes when it fails to execute properly" do
    Delayed::Job.enqueue ErrorJob.new
    Delayed::Job.work_off(1)

    job = Delayed::Job.find(:first)

    job.last_error.should =~ /did not work/
    job.last_error.should =~ /job_spec.rb:10:in `perform'/
    job.attempts.should == 1

    job.run_at.should > Delayed::Job.db_time_now - 10.minutes
    job.run_at.should < Delayed::Job.db_time_now + 10.minutes
  end

  it "should raise an DeserializationError when the job class is totally unknown" do

    job = Delayed::Job.new
    job['handler'] = "--- !ruby/object:JobThatDoesNotExist {}"

    lambda { job.payload_object.perform }.should raise_error(Delayed::DeserializationError)
  end

  it "should try to load the class when it is unknown at the time of the deserialization" do
    job = Delayed::Job.new
    job['handler'] = "--- !ruby/object:JobThatDoesNotExist {}"

    job.should_receive(:attempt_to_load).with('JobThatDoesNotExist').and_return(true)

    lambda { job.payload_object.perform }.should raise_error(Delayed::DeserializationError)
  end

  it "should try include the namespace when loading unknown objects" do
    job = Delayed::Job.new
    job['handler'] = "--- !ruby/object:Delayed::JobThatDoesNotExist {}"
    job.should_receive(:attempt_to_load).with('Delayed::JobThatDoesNotExist').and_return(true)
    lambda { job.payload_object.perform }.should raise_error(Delayed::DeserializationError)
  end

  it "should also try to load structs when they are unknown (raises TypeError)" do
    job = Delayed::Job.new
    job['handler'] = "--- !ruby/struct:JobThatDoesNotExist {}"

    job.should_receive(:attempt_to_load).with('JobThatDoesNotExist').and_return(true)

    lambda { job.payload_object.perform }.should raise_error(Delayed::DeserializationError)
  end

  it "should try include the namespace when loading unknown structs" do
    job = Delayed::Job.new
    job['handler'] = "--- !ruby/struct:Delayed::JobThatDoesNotExist {}"

    job.should_receive(:attempt_to_load).with('Delayed::JobThatDoesNotExist').and_return(true)
    lambda { job.payload_object.perform }.should raise_error(Delayed::DeserializationError)
  end
  
  it "should be failed if it failed more than MAX_ATTEMPTS times and we don't want to destroy jobs" do
    default = Delayed::Job.destroy_failed_jobs
    Delayed::Job.destroy_failed_jobs = false

    @job = Delayed::Job.create :payload_object => SimpleJob.new, :attempts => 50
    @job.reload.failed_at.should == nil
    @job.reschedule 'FAIL'
    @job.reload.failed_at.should_not == nil

    Delayed::Job.destroy_failed_jobs = default
  end

  it "should be destroyed if it failed more than MAX_ATTEMPTS times and we want to destroy jobs" do
    default = Delayed::Job.destroy_failed_jobs
    Delayed::Job.destroy_failed_jobs = true

    @job = Delayed::Job.create :payload_object => SimpleJob.new, :attempts => 50
    @job.should_receive(:destroy)
    @job.reschedule 'FAIL'

    Delayed::Job.destroy_failed_jobs = default
  end

  it "should never find failed jobs" do
    @job = Delayed::Job.create :payload_object => SimpleJob.new, :attempts => 50, :failed_at => Time.now
    Delayed::Job.find_available(1).length.should == 0
  end

  context "when another worker is already performing an task, it" do

    before :each do
      Delayed::Job.worker_name = 'worker1'
      @job = Delayed::Job.create :payload_object => SimpleJob.new, :locked_by => 'worker1', :locked_at => Delayed::Job.db_time_now - 5.minutes
    end

    it "should not allow a second worker to get exclusive access" do
      lambda { @job.lock_exclusively! 4.hours, 'worker2' }.should raise_error(Delayed::Job::LockError)
    end

    it "should allow a second worker to get exclusive access if the timeout has passed" do
      lambda { @job.lock_exclusively! 1.minute, 'worker2' }.should_not raise_error(Delayed::Job::LockError)
    end      
    
    it "should be able to get access to the task if it was started more then max_age ago" do
      @job.locked_at = 5.hours.ago
      @job.save

      @job.lock_exclusively! 4.hours, 'worker2'
      @job.reload
      @job.locked_by.should == 'worker2'
      @job.locked_at.should > 1.minute.ago
    end

    it "should not be found by another worker" do
      Delayed::Job.worker_name = 'worker2'

      Delayed::Job.find_available(1, 6.minutes).length.should == 0
    end

    it "should be found by another worker if the time has expired" do
      Delayed::Job.worker_name = 'worker2'

      Delayed::Job.find_available(1, 4.minutes).length.should == 1
    end

    it "should be able to get exclusive access again when the worker name is the same" do
      @job.lock_exclusively! 5.minutes, 'worker1'
      @job.lock_exclusively! 5.minutes, 'worker1'
      @job.lock_exclusively! 5.minutes, 'worker1'
    end                                        
  end         
  
  context "worker prioritization" do
    
    before(:each) do
      Delayed::Job.max_priority = nil
      Delayed::Job.min_priority = nil      
    end
  
    it "should only work_off jobs that are >= min_priority" do
      Delayed::Job.min_priority = -5
      Delayed::Job.max_priority = 5
      SimpleJob.runs.should == 0
    
      Delayed::Job.enqueue SimpleJob.new, -10
      Delayed::Job.enqueue SimpleJob.new, 0
      Delayed::Job.work_off
    
      SimpleJob.runs.should == 1
    end
  
    it "should only work_off jobs that are <= max_priority" do
      Delayed::Job.min_priority = -5
      Delayed::Job.max_priority = 5
      SimpleJob.runs.should == 0
    
      Delayed::Job.enqueue SimpleJob.new, 10
      Delayed::Job.enqueue SimpleJob.new, 0

      Delayed::Job.work_off

      SimpleJob.runs.should == 1
    end                         
   
  end
  
  context "when pulling jobs off the queue for processing, it" do
    before(:each) do
      @job = Delayed::Job.create(
        :payload_object => SimpleJob.new, 
        :locked_by => 'worker1', 
        :locked_at => Delayed::Job.db_time_now - 5.minutes)
    end

    it "should leave the queue in a consistent state and not run the job if locking fails" do
      SimpleJob.runs.should == 0     
      @job.stub!(:lock_exclusively!).with(:any_args).once.and_raise(Delayed::Job::LockError)
      Delayed::Job.should_receive(:find_available).once.and_return([@job])
      Delayed::Job.work_off(1)
      SimpleJob.runs.should == 0
    end
  
  end
  
  context "while running alongside other workers with enqueued jobs, it" do 
    before(:each) do
      Delayed::Job.worker_name = 'worker1'
      Delayed::Job.create(:payload_object => SimpleJob.new, :locked_by => 'worker1', :locked_at => (Delayed::Job.db_time_now - 3.minutes))
      Delayed::Job.create(:payload_object => SimpleJob.new, :locked_by => 'worker2', :locked_at => (Delayed::Job.db_time_now - 11.minutes))  
      Delayed::Job.create(:payload_object => SimpleJob.new, :locked_by => 'worker1', :locked_at => (Delayed::Job.db_time_now - 2.minutes))
    end
    
    it "should only find jobs if the lock has expired reguardless of the worker" do
      SimpleJob.runs.should == 0  
      Delayed::Job.work_off(5)
      SimpleJob.runs.should == 2 
      Delayed::Job.find_available(5, 10.minutes).length.should == 1
    end
    
  end
  
end