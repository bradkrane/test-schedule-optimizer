#!/usr/bin/ruby

# this will optomize who should take what test and to minimize the number of tests times while ensuring test coverage and raising an exception
require "google/apis/sheets_v4"
require "googleauth"
require "googleauth/stores/file_token_store"
require "fileutils"

# add a new method to array to transpose sparse matricies
class Array
  def transpose_uneven
    array = self
    row_length = array.first.length

    array.each { |row|
      if row.length < row_length
        while row.length < row_length
          row << nil
        end
      elsif row.length > row_length
        raise ArgumentError.new "First row must be longest."
      end
    }

    array.transpose
  end
end

class ExperimentGSheetsSchedule
  def sheet_range sheet, range
    "#{sheet}!#{range}"
  end

  def initialize sheet_guid, schedule_ranges, schedule_sheet = 'Sheet1'
    @oOB_URI = "urn:ietf:wg:oauth:2.0:oob".freeze
    @aPPLICATION_NAME = "Google Sheets API Ruby Quickstart".freeze
    @cREDENTIALS_PATH = "credentials.json".freeze
    # The file token.yaml stores the user's access and refresh tokens, and is
    # created automatically when the authorization flow completes for the first
    # time.
    @tOKEN_PATH = "token.yaml".freeze
    @sCOPE = Google::Apis::SheetsV4::AUTH_SPREADSHEETS_READONLY

    ##
    # Ensure valid credentials, either by restoring from the saved credentials
    # files or intitiating an OAuth2 authorization. If authorization is required,
    # the user's default browser will be launched to approve the request.
    #
    # @return [Google::Auth::UserRefreshCredentials] OAuth2 credentials
    def authorize
      client_id = Google::Auth::ClientId.from_file @cREDENTIALS_PATH
      token_store = Google::Auth::Stores::FileTokenStore.new file: @tOKEN_PATH
      authorizer = Google::Auth::UserAuthorizer.new client_id, @sCOPE, token_store
      user_id = "default"
      credentials = authorizer.get_credentials user_id
      if credentials.nil?
        url = authorizer.get_authorization_url base_url: @oOB_URI
        puts "Open the following URL in the browser and enter the " \
            "resulting code after authorization:\n" + url
        code = gets
        credentials = authorizer.get_and_store_credentials_from_code(
          user_id: user_id, code: code, base_url: @oOB_URI
        )
      end
      credentials
    end

    @weekly_schedules = []

    # Initialize the API
    service = Google::Apis::SheetsV4::SheetsService.new
    service.client_options.application_name = @aPPLICATION_NAME
    service.authorization = authorize

    # aaaahhhhh dep 
    schedule_ranges.each { |range| 
      range = sheet_range schedule_sheet, range

      @weekly_schedules << (week_schedule = service.get_spreadsheet_values sheet_guid, range)
      raise ArgumentError.new "No data found." if week_schedule == nil
    }
  end

  attr_reader :weekly_schedules
end


class Histogram
    def initialize 
        @elements = {}
    end

    def add elm
        if !@elements.key? elm
            @elements[elm] = 1
        else
            @elements[elm] += 1
        end
    end

    def lowest
        values = @elements.sort { |elm_a, elm_b| elm_a.last <=> elm_b.last }
        values.first.first
    end

    def to_s; @elements.to_s; end

    def get elm; @elements[elm]; end

    def average
        sum = 0
        @elements.each { |elm| sum += elm }
        sum / @elements.count.to_f
    end
end

require 'time'
TESTS = %w[a b c d]

class Participant
    def initialize name
        @name = name
        @test_completion = {}; TESTS.each { |test| @test_completion[test] = false }
        @test_schedule = []

        self
    end

    attr_reader :name, :test_completion, :test_schedule

    def has_completed?     test;  @test_completion[test]; end
    def needs_to_complete? test; !@test_completion[test]; end
    def has_all_slots?
        return true if @test_schedule.count >= TESTS.count
        false
    end

    def complete test
        raise ArgumentError "Already Tested" if @test_completion[test] == true
        @test_completion[test] = true
    end

    def assign_next_slot slot
        if @test_schedule.count < test_completion.length
            if !@test_schedule.include?(slot)
                @test_schedule << slot
            else
                raise ArgumentError.new "Slots must be unique"
            end
        else
            raise RangeError.new "Participants are limited to #{test_completion.length} test slots"
        end
    end

    def to_s
        str = @name.to_s + "\t" + @test_completion.to_s + "\t" + 
        @test_schedule.to_s + "\n"
    end

    def reset_tests
        @test_completion = {}; TESTS.each { |test| @test_completion[test] = false }
    end
end

class Schedule

    class ExperimentSlot
        def initialize date, time
            @date, @time = date, time
            @participants = []  # 0 <= N_p <= 2
        end
    
        attr_reader :date, :time, :participants, :test
    
        def add_participant participant
            if participant.class != Participant || participant.nil? || participant == ''
                raise ArgumentError.new "Add participant: '#{participant}''"
                return nil
            elsif @participants.include? participant
                raise RangeError.new "Same participant: '#{participant}'\nadded twice: #{self}"
            elsif @participants.count < 2
                participant.assign_next_slot self
                @participants << participant
            else
                raise RangeError.new "More than two participants added."
            end
    
            self
        end

        def isAttended; @participants.count > 0; end

        def remove_participant
        end

        def assign_test test
            #print @participants.inspect + "\n"
            #print test.inspect + "\n"
            
            @participants.each { |participant| return nil if participant.has_completed? test }
            @participants.each { |participant| participant.complete test }
            @test = test
        end

        def reset_test
            @test = nil
        end

        def get_participant_remaining_tests
            tests = []; TESTS.each { |i| tests << i }

            @participants.each { |participant| 
                participant.test_completion.each_pair { |tc,status| tests.delete tc if status }
            }

            return tests if tests != []
            nil
        end

        def inspect
            to_s
        end

        def to_s
            str = "#{@date}\t#{@time}\t#{test}\t"
            @participants.each { |participant| str += "#{participant.name}\t"}
            str[0..-2]
        end

    end

    class TestDataFactory
        # for generating the weekly schedule for testing
        def self.experimentSlots start_date, weeks
            slot_template = [ ['08:30', '10:00', '11:00', '13:00', '15:00', '16:30'], 
                            ['10:00', '12:00', '13:30', '16:00'] ] # this shuold be parameter
            
            slots = []
            date = start_date
            (1..weeks).each { |i|
                day = 0

                while day <= 5
                    slot_template[day % 2].each { |time| 
                        slots << ExperimentSlot.new(date, time)
                    }

                    date += 1
                    day += 1 
                end

                date += 2
            }

            slots
        end

        # for generating participants for testing
        def self.participants number
            participants = []
            (1..number).each { |n| participants << Participant.new(n) }

            participants
        end

        def self.get_random_available_other loner, participants
            everyone_else = participants.select { |p| p != loner && !p.has_all_slots? }
            return nil if everyone_else.count == 0
            everyone_else[Random.new.rand(everyone_else.count)]
        end
    
        def self.get_random_available_participant participants
            avaialable = participants.select { |p| !p.has_all_slots? }
            return nil if avaialable.count == 0
            avaialable[Random.new.rand(avaialable.count)]
        end
    
        def self.assign_participants_to_slots slots, participants, options = { factory: "random-50-75" }
            raise ArgumentError.new("Not enought time slots for participants and test course.") if 2.0 * slots.count - participants.count * TESTS.count < 0

            def self.random_slot_assignemnt slots, participants, chance_of_second_participant = 100, chance_of_any_participant = 100
                rand = Random.new

                slots.each { |slot|
                    next if rand.rand(100) >= chance_of_any_participant
                    avaialable_participant = get_random_available_participant(participants)
                    break if avaialable_participant == nil
                    avaialable_participant.assign_next_slot slot
                    
                    next if rand.rand(100) >= chance_of_second_participant
                    avaialable_participant = get_random_available_other(slot.participants.first, participants)
                    break if avaialable_participant == nil
                    avaialable_participant.assign_next_slot slot
                }
            end


            case options[:factory]
            when "random-100"
                random_slot_assignemnt slots, participants
            when "random-75"
                random_slot_assignemnt slots, participants, 75
            when "random-50"
                random_slot_assignemnt slots, participants, 50
            when "random-50-75"
                random_slot_assignemnt slots, participants, 50, 75
            end
        end

        def self.set_of_participants_not_fully_assigned participants
            list = []
            participants.each { |participant| list << participant if(!participant.has_all_slots?)
            }
            list
        end
    end

    def initialize test_data = true, weeks = 8
        if test_data
            @slots = TestDataFactory::experimentSlots Date.today, weeks
            @participants = TestDataFactory::participants 40

            TestDataFactory::assign_participants_to_slots @slots, @participants
            print "UNASSIGNED" + TestDataFactory::set_of_participants_not_fully_assigned(@participants).to_s + "\n" if TestDataFactory::set_of_participants_not_fully_assigned(@participants) != []
        end

        @slots = []
        @participants = []
    end

    def add_participant participant
        return nil if participant == '' || participant.nil?
        participant = participant.strip

        existing_participant = @participants.select { |p| 
            return false if p.nil?
            p.name == participant 
        }
        return existing_participant.first if existing_participant != []

        new_participant = Participant.new participant       
        @participants << new_participant
        new_participant
    end

    def add_slot date, time, participant1, participant2
        if date.class != Date || time.class != Time
            raise ArgumentError.new "One of date #{date.class} or time #{time.class} is the wrong type."
        end

        @slots << (slot = ExperimentSlot.new date, time)

        p1 = add_participant(participant1)
        p2 = add_participant(participant2)
        
        #p "two lines"
        #p p1
        if !p1.nil?
            slot.add_participant p1
            #p slot
        end
        #p p2
        #STDOUT.flush
        if !p2.nil?
            slot.add_participant p2
            #p slot
        end
        
    end

    def initialize2
        ranges = ['C3:H22', 'K5:P24', 'S5:X24', 'AA5:AE24', 'AI5:AN24']
        spreadsheet_id = "1Rpj1jsejJmiKe4D64HNL4KnYlIiug-KiZWEHBuwKNtM"


        gsheet_schedule = ExperimentGSheetsSchedule.new spreadsheet_id, ranges
        raise ArgumentError.new "No data found." if gsheet_schedule == nil

        print "Ranges Loaded: #{ranges}\n"
        print "#{gsheet_schedule.weekly_schedules.count} weeks of scheduile loaded.\n\n"
   
        def get_next_day_slot day
            last_cell = nil

            while day.length > 0
                begin
                    cell = day.shift
                    if cell.nil?
                        last_cell = cell
                        next
                    end
                    time = cell.gsub(/^\D*/ , '')
                    test = /(\D*)$/.match(time)[1].strip
                    time = Time.parse time.gsub(/(\D*)$/ , '')

                    return [last_cell, time, day.shift]
                rescue ArgumentError => exception
                    last_cell = cell
                end
            end
        end

        gsheet_schedule.weekly_schedules.each { |week|
            transpose_schedule = week.values.transpose_uneven

            transpose_schedule.each { |day|
                date = Date.parse day.shift

                #print "DAY:#{date}:" + day.inspect + "\n"

                while day.length > 0
                    slot_data = get_next_day_slot day
                    break if slot_data == nil

                 #   print "SD: #{slot_data}\n"

                    participant_1 = slot_data.shift
                    time = slot_data.shift
                    participant_2 = slot_data.shift

                    self.add_slot date, time, (participant_1 == '' ? nil : participant_1), (participant_2 == '' ? nil : participant_2)
                end
            }
        }

    end

    
    def assign_tests_to_slots options = { factory: "simple-random" }
        case options[:factory]
        when "simple-random"
            i = 0
            rand = Random.new

            @attended_slots = @slots.select { |slot| slot.isAttended }

            @attended_slots.each { |slot|
                slot.assign_test TESTS[i % TESTS.count]
                i = rand.rand(999999)
            }

            #print "FIRST PASS\n"
            hist = Histogram.new
            @attended_slots.each { |slot| 

                hist.add slot.test; #print slot.to_s 
            }
            #print hist.to_s + "\n"
            @hist0 = hist


            #print "SECOND PASS\n"
            test_unass_slots = @attended_slots.select { |slot| hist.add(slot.test); slot.test == nil }
            test_unass_slots.each { |test_unass_slot|
                remaining = test_unass_slot.get_participant_remaining_tests

                if remaining == nil
                    # it is not possible for this pair to complete all and must reassign one
                    #print "Conflict: #{test_unass_slot}"
                    next
                end

                if test_unass_slot.assign_test(hist.lowest) == nil
                    test_unass_slot.assign_test remaining.shuffle.first
                end
            }
            
            #@slots.each { |slot| print slot.to_s }
            hist = Histogram.new
            test_unass_slots = @attended_slots.select { |slot| hist.add(slot.test); slot.test == nil }
            #p hist.inspect
            @hist1 = hist
            
            test_unass_slots.each { |test_unass_slot|
                remaining = test_unass_slot.get_participant_remaining_tests

                if remaining == nil
                    # it is not possible for this pair to complete all and must reassign one
                    #print "Conflict: #{test_unass_slot}"
                    next
                end

                if test_unass_slot.assign_test(hist.lowest) == nil
                    test_unass_slot.assign_test remaining.shuffle.first
                end
            }

            #print test_unass_slots.inspect

            #print "LAST PASS\n"
            #@slots.each { |slot| print slot.to_s }
            hist = Histogram.new
            unass_slots = @slots.select { |slot| hist.add(slot.test); slot.test == nil }
            #p hist.inspect
            @hist2 = hist
        end


    end

    def reset_tests
        @slots.each { |slot| slot.reset_test }
        @participants.each { |participants| participants.reset_tests }
    end
   
    def to_s
        str = ''
        @slots.each { |slot| str += slot.to_s}
        str[0..-3]
        #@participants.each { |participant| print participant.to_s }
    end

    def slots_tsv
        str = "Date\tTime\t\Test\tParticipant_1\tParticipant_2\n"
        @slots.each { |slot| str += slot.to_s + "\n"}
        str
        
        #@participants.each { |participant| print participant.to_s }
    end

    def participants_tsv
        str = "Name\tTests Completed\tTest Schedule\n"
        @participants.each { |slot| str += slot.to_s }
        str
    end

    attr_reader :hist0, :hist1, :hist2, :attended_slots, :participants, :slots
end


s = Schedule.new false
s.initialize2

# this bit tries over and over function out
min = 99999999999999999999
min0 = 99999999999999999999
min1 = 99999999999999999999

num_mins = 0

hmin = nil
hmin0 = nil
hmin1 = nil

num_rolls = 0

start = Time.now
print "Start: #{start}\n"

while Time.now - start < 10
    s.assign_tests_to_slots



    if !s.hist0.get(nil).nil? && s.hist0.get(nil) < min0
        min0 = s.hist0.get(nil) 
        hmin0 = s.hist0
    end
    #p s.inspect
    if !s.hist1.get(nil).nil?
        if s.hist1.get(nil) < min1
            min1 = s.hist1.get(nil) 
            hmin1 = s.hist1
            num_mins += 1
            
            print "Min: #{min1}\n"
            print s.slots_tsv + "\n"
            print s.participants_tsv + "\n"

            complete = 0
            s.participants.each { |p| complete += 1 if p.has_all_slots? }
            print "Complete: #{complete} of #{s.participants.count}\n"
        elsif s.hist1.get(nil) <= min1
            num_mins += 1
        end
    end

    if !s.hist2.get(nil).nil? && s.hist2.get(nil) < min
        min = s.hist2.get(nil) 
        hmin = s.hist2
    end

    s.reset_tests

    #print "Min: #{min}\n"
    num_rolls += 1
end


print "Min: #{min}\n"

print "Min0: #{min0}\n"
print "Min1: #{min1}\n"
print s.hist2
print hmin
print "Num Rolls: #{num_rolls}\n"
print "Num Mins: #{num_mins}\n"











