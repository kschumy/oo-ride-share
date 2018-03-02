require 'csv'
require 'time'

require_relative 'driver'
require_relative 'passenger'
require_relative 'trip'

module RideShare
  class TripDispatcher
    attr_reader :drivers, :passengers, :trips

    def initialize
      @drivers = load_drivers
      @passengers = load_passengers
      @trips = load_trips
    end

    def load_drivers
      my_file = CSV.open('support/drivers.csv', headers: true)
      all_drivers = []
      my_file.each do |line|
        input_data = {}
        vin = line[2].length == 17 ? line[2] : "0" * 17  # Set to default value
        status = line[3].to_sym
        input_data[:vin] = vin
        input_data[:id] = line[0].to_i
        input_data[:name] = line[1]
        input_data[:status] = status
        all_drivers << Driver.new(input_data)
      end
      return all_drivers
    end

    def find_driver(id)
      return find_by_id(@drivers, id)
    end

    def load_passengers
      passengers = []
      CSV.read('support/passengers.csv', headers: true).each do |line|
        input_data = {}
        input_data[:id] = line[0].to_i
        input_data[:name] = line[1]
        input_data[:phone] = line[2]
        passengers << Passenger.new(input_data)
      end
      return passengers
    end


    def find_passenger(id)
      return find_by_id(@passengers, id)
    end

    def load_trips
      trips = []
      trip_data = CSV.open('support/trips.csv', 'r', headers: true,
        header_converters: :symbol)
      trip_data.each do |raw_trip|
        driver = find_driver(raw_trip[:driver_id].to_i)
        passenger = find_passenger(raw_trip[:passenger_id].to_i)
        parsed_trip = {
          id: raw_trip[:id].to_i,
          driver: driver,
          passenger: passenger,
          start_time: Time.parse(raw_trip[:start_time]),
          end_time: Time.parse(raw_trip[:end_time]),
          cost: raw_trip[:cost].to_f,
          rating: raw_trip[:rating].to_i
        }
        trips << make_new_trip(parsed_trip)
      end
      return trips
    end

    def request_trip(passenger_id)
      driver = find_driver_or_error
      trip_id = @trips.empty? ? 1 : @trips.size
      new_trip_data = {
        id: trip_id,
        driver: driver,
        passenger: find_passenger(passenger_id),
        start_time: Time.now,
        end_time: nil,
        cost: nil,
        rating: nil
      }
      @trips << make_new_trip(new_trip_data)
      return @trips.last
    end

    def inspect
      "#<#{self.class.name}:0x#{self.object_id.to_s(16)}>"
    end

    private

    # Provided list_to_search must be a list of Drivers, Trips, or Passengers.
    def find_by_id(list_to_search, id)
      RideShare.return_valid_id_or_error(id)
      return list_to_search.find{ |element| element.id == id }
    end

    def find_driver_or_error
      driver = find_available_driver
      raise ArgumentError.new("No driver available") if driver.nil?
      return driver
    end

    def make_new_trip(new_trip_data)
      trip = Trip.new(new_trip_data)
      trip.driver.add_trip(trip)
      trip.passenger.add_trip(trip)
      return trip
    end

    def find_available_driver
      longest_ago_last_trip = Time.now
      longest_ago_last_trip_driver = nil
      @drivers.each do |driver|
        next if !driver.is_available?
        return driver if driver.trips.empty? # driver has never had a trip
        last_trip_end_time = get_last_trip_end_time(driver)
        if last_trip_end_time < longest_ago_last_trip
          longest_ago_last_trip = last_trip_end_time
          longest_ago_last_trip_driver = driver
        end
      end
      return longest_ago_last_trip_driver
    end

    def get_last_trip_end_time(driver)
      last_trip_end_time = Time.parse('1949-04-09') # arbitrary
      driver.trips.each do |trip|
        last_trip_end_time = trip.end_time if last_trip_end_time < trip.end_time
      end
      return last_trip_end_time
    end

  end
end
