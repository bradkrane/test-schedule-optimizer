#!/usr/bin/ruby
require 'time'

# this will optomize who should take what test and to minimize the number of tests times while ensuring test coverage and raising an exception


TESTS = %w[a b c d]



class Participant
    def initialize name, tests = TESTS
        @name = name
        @test_completion = {}; tests.each { |test| @test_completion[test] = false }
        @test_schedule = []
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
            if !@test_schedule.include? slot
                @test_schedule << slot

                slot.add_participant self
            else
                raise ArgumentError.new "Slots must be unique"
            end
        else
            raise RangeError.new "Participants are limited to #{test_completion.length} test slots"
        end
    end

    def to_s
        str = @name.to_s + "\t" + @test_completion.to_s + "\n" + @test_schedule.to_s + "\n"
    end
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
end


class Schedule

    class ExperimentSlot
        def initialize date, time
            @date, @time = date, time
            @participants = []  # 0 <= N_p <= 2
        end
    
        attr_reader :date, :time, :participants, :test
    
        def add_participant participant
            if @participants.count < 2
                @participants << participant
            else
                raise RangeError.new "More than two participants added."
            end
    
            self
        end

        def assign_test test
            @participants.each { |participant| return nil if participant.has_completed? test }
            @participants.each { |participant| participant.complete test }
            @test = test
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
            str = "Date: #{@date}\tTime: #{@time}\t"
            @participants.each { |participant| str += "#{participant.name}\t"}
            str += "#{test}\n"
        end

    end

    class TestDataGenerator
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
    
        def self.assign_participants_to_slots slots, participants, options = { generator: "random-dense" }
            case options[:generator]
            when "random-dense"
                raise ArgumentError.new("Can't even") if 2.0 * slots.count - participants.count * 4.0 < 0

                begin
                    slots.each { |slot|
                        avaialable_participant = get_random_available_participant(participants)
                        break if avaialable_participant == nil
                        avaialable_participant.assign_next_slot slot
                        
                        avaialable_participant = get_random_available_other(slot.participants.first, participants)
                        break if avaialable_participant == nil
                        avaialable_participant.assign_next_slot slot
                    }
    
                rescue ArgumentError => exception
                                       
                end
               
                # sanity check

            when ""
            end
        end

        def self.set_of_participants_not_fully_assigned participants
            list = []
            participants.each { |participant| list << participant if(!participant.has_all_slots?)
            }
            list
        end
    end

    def initialize start_date, weeks = 4, test_data = true
        raise ArgumentError.new "Test Only" if !test_data

        @slots = TestDataGenerator::experimentSlots start_date, weeks
        @participants = TestDataGenerator::participants 55

        TestDataGenerator::assign_participants_to_slots @slots, @participants
        print "UNASSIGNED" + TestDataGenerator::set_of_participants_not_fully_assigned(@participants).to_s + "\n" if TestDataGenerator::set_of_participants_not_fully_assigned(@participants) != []

        assign_tests_to_slots
    end

    
    def assign_tests_to_slots options = { generator: "simple-pass" }
        case options[:generator]
        when "simple-pass"
            i = 0
            @slots.each { |slot|
                slot.assign_test TESTS[i % TESTS.count]
                i += 1
            }

            print "FIRST PASS\n"
            hist = Histogram.new
            @slots.each { |slot| hist.add slot.test; print slot.to_s }
            print hist.to_s + "\n"


            unassigned_slots = @slots.select { |slot| hist.add(slot.test); slot.test == nil }
            p unassigned_slots.count

            p hist.lowest

            unassigned_slots.each { |uns|
                remaining = uns.get_participant_remaining_tests

                next if remaining == nil

                if uns.assign_test(hist.lowest) == nil
                    uns.assign_test remaining.shuffle.first
                end
            }

            print "SECOND PASS\n"
            @slots.each { |slot| print slot.to_s }


            hist = Histogram.new
            unassigned_slots = @slots.select { |slot| hist.add(slot.test); slot.test == nil }

            p hist.inspect
            p hist.lowest

            unassigned_slots.each { |uns|
                remaining = uns.get_participant_remaining_tests

                next if remaining == nil

                if uns.assign_test(hist.lowest) == nil
                    uns.assign_test remaining.shuffle.first
                end
            }

            print "SECOND PASS\n"
            @slots.each { |slot| print slot.to_s }
        end
    end

   
    def to_s
        @slots.each { |slot| print slot.to_s }

        #@participants.each { |participant| print participant.to_s }
    end

end

s = Schedule.new Date.today - 1


