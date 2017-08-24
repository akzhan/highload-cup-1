require "zip"
require "json"
require "time"
require "http/server"

class NotFoundException < Exception
end

def not_found! : NoReturn
  raise NotFoundException.new
end

def bad_request! : NoReturn
  raise "bad_request!"
end

class Object
  def on_presence(&block)
    unless is_a?(ValueAbsence)
      yield self.not_nil!
    end
  end
end

class ValueAbsence
  Absence = ValueAbsence.new

  def initialize(pull = nil)
    raise "oops" if pull # should never be pulled by JSON parser
  end

  # Writes `"absence"` to the given `IO`.
  def inspect(io)
    io << "absence"
  end

  def self.absence
    Absence
  end
end

class StorageUser
  JSON.mapping(
    first_name: String,
    last_name: String,
    birth_date: Int32,
    gender: String,
    email: String,
    id: Int32
  )
end

class StorageLocation
  JSON.mapping(
    country: String,
    city: String,
    place: String,
    distance: UInt32,
    id: Int32
  )
end

class StorageVisit
  JSON.mapping(
    visited_at: Int32,
    user: Int32,
    location: Int32,
    id: Int32,
    mark: UInt8
  )
end

Users     = Hash(Int32, User).new(initial_capacity: 32768)
Locations = Hash(Int32, Location).new(initial_capacity: 32768)
Visits    = Hash(Int32, Visit).new(initial_capacity: 32768)

class User < StorageUser
  property visits : Array(Visit)
  property? sorted_visits : Bool

  def initialize(storage_user)
    bad_request! if storage_user.gender != "m" && storage_user.gender != "f"
    @id = storage_user.id
    @first_name = storage_user.first_name
    @last_name = storage_user.last_name
    @birth_date = storage_user.birth_date
    @gender = storage_user.gender
    @email = storage_user.email
    @visits = [] of Visit
    @sorted_visits = false
  end

  def assign(update_user) : Nil
    update_user.id.on_presence do |i|
      bad_request! if i != id
    end

    update_user.first_name.not_nil!
    update_user.last_name.not_nil!
    update_user.birth_date.not_nil!
    update_user.email.not_nil!
    update_user.gender.not_nil!

    update_user.gender.on_presence do |g|
      # checks before any assignments
      if g != "m" && g != "f"
        bad_request!
      end
      self.gender = g
    end
    update_user.first_name.on_presence do |fn|
      self.first_name = fn
    end
    update_user.last_name.on_presence do |ln|
      self.last_name = ln
    end
    update_user.birth_date.on_presence do |bd|
      self.birth_date = bd
    end
    update_user.email.on_presence do |e|
      self.email = e
    end
  end

  def sort_visits! : Nil
    unless sorted_visits?
      visits.sort!
      self.sorted_visits = true
    end
  end

  def push_visit(visit) : Nil
    visits << visit
    self.sorted_visits = false
  end

  def_equals @id
end

class Location < StorageLocation
  property visits : Array(Visit)

  def initialize(storage_location)
    @id = storage_location.id
    @country = storage_location.country
    @city = storage_location.city
    @distance = storage_location.distance
    @place = storage_location.place
    @visits = [] of Visit
  end

  def assign(update_location) : Nil
    update_location.id.on_presence do |i|
      bad_request! if i != id
    end

    update_location.country.not_nil!
    update_location.city.not_nil!
    update_location.distance.not_nil!
    update_location.place.not_nil!

    update_location.country.on_presence do |c|
      self.country = c
    end
    update_location.city.on_presence do |ci|
      self.city = ci
    end
    update_location.distance.on_presence do |di|
      self.distance = di
    end
    update_location.place.on_presence do |pl|
      self.place = pl
    end
  end

  def push_visit(visit) : Nil
    visits << visit
  end

  def_equals @id
end

class Visit < StorageVisit
  include Comparable(Visit)

  def initialize(storage_visit)
    @id = storage_visit.id
    @user = storage_visit.user
    @location = storage_visit.location
    @visited_at = storage_visit.visited_at
    @mark = storage_visit.mark
  end

  def <=>(other : Visit)
    visited_at <=> other.visited_at
  end

  def assign(update_visit) : Nil
    update_visit.id.on_presence do |i|
      bad_request! if i != id
    end
    update_visit.id = id

    # checks before any assignments
    update_visit.user.not_nil!
    update_visit.location.not_nil!
    update_visit.mark.not_nil!
    update_visit.visited_at.not_nil!

    update_visit.user.on_presence do |u|
      if u == user
        update_visit.user = ValueAbsence.absence
      else
        bad_request! unless Users.has_key?(u)
      end
    end
    update_visit.location.on_presence do |l|
      if l == location
        update_visit.location = ValueAbsence.absence
      else
        bad_request! unless Locations.has_key?(l)
      end
    end
    update_visit.mark.on_presence do |m|
      if m > 5 # unsigned
        bad_request!
      end
      self.mark = m
    end
    # to optimize
    update_visit.user.on_presence do |u|
      Users[user].visits.delete(self)
      self.user = u
      Users[user].push_visit self
    end
    update_visit.location.on_presence do |l|
      Locations[location].visits.delete(self)
      self.location = l
      Locations[location].push_visit self
    end
    update_visit.visited_at.on_presence do |vat|
      next if vat == visited_at
      self.visited_at = vat
      Users[user].sorted_visits = false
    end
  end

  def_equals @id
end

class UpdateUser
  JSON.mapping(
    id: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    first_name: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    last_name: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    birth_date: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    gender: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    email: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence}
  )
end

class UpdateLocation
  JSON.mapping(
    id: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    country: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    city: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    place: {type: String | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    distance: {type: UInt32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence}
  )
end

class UpdateVisit
  JSON.mapping(
    id: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    visited_at: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    user: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    location: {type: Int32 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence},
    mark: {type: UInt8 | ValueAbsence | Nil, nilable: true, default: ValueAbsence.absence}
  )
end

emulated_now = if File.exists?("/tmp/data/options.txt")
                 File.open("/tmp/data/options.txt") do |f|
                   Time.epoch(f.gets.not_nil!.to_i64)
                 end
               else
                 File.stat("/tmp/data/data.zip").mtime
               end

Zip::File.open("/tmp/data/data.zip") do |file|
  file.entries.each do |entry|
    m = /(?:^|\/)(users|locations|visits)_(\d+)\.json$/.match(entry.filename)
    next if m.nil?
    entity_type = m[1]
    case entity_type
    when "users"
      entry.open do |io|
        arr = Array(StorageUser).from_json(io, "users")
        arr.each do |u|
          Users[u.id] = User.new(u)
        end
      end
    when "locations"
      entry.open do |io|
        arr = Array(StorageLocation).from_json(io, "locations")
        arr.each do |l|
          Locations[l.id] = Location.new(l)
        end
      end
    when "visits"
      entry.open do |io|
        arr = Array(StorageVisit).from_json(io, "visits")
        arr.each do |v|
          Visits[v.id] = Visit.new(v)
        end
      end
    end
  end
end

# visits per user/location
Visits.each_value do |visit|
  u = Users[visit.user]
  u.visits << visit
  l = Locations[visit.location]
  l.visits << visit
end

# visits sorted by visited_at
Users.each_value do |u|
  u.sort_visits!
end

def get_int_param(params, key)
  value = params[key]?
  return nil if value.nil?
  value.to_i32
end

def get_uint_param(params, key)
  value = get_int_param(params, key)
  return nil if value.nil?
  bad_request! if value < 0
  value
end

GC.collect

server = HTTP::Server.new("0.0.0.0", 80) do |context|
  context.response.content_type = "application/json; charset=utf-8"
  begin
    case context.request.method
    when "GET"
      case context.request.path
      when %r{^/users/([+\-]?\d+)$}
        u = Users[$1.to_i32] rescue not_found!
        u.to_json(context.response)
      when %r{^/locations/([+\-]?\d+)$}
        l = Locations[$1.to_i32] rescue not_found!
        l.to_json(context.response)
      when %r{^/visits/([+\-]?\d+)$}
        v = Visits[$1.to_i32] rescue not_found!
        v.to_json(context.response)
      when %r{^/users/([+\-]?\d+)/visits$}
        u = Users[$1.to_i32] rescue not_found!
        params = context.request.query_params
        from_date = get_int_param(params, "fromDate")
        to_date = get_int_param(params, "toDate")
        country = params["country"]?
        to_distance = get_uint_param(params, "toDistance")

        if u.visits.empty?
          context.response.print "{\"visits\": []}"
          next
        end

        u.sort_visits!
        dated_visits = u.visits

        JSON.build(context.response) do |json|
          # one of binary searches wrong and need some investigation
          if !from_date.nil?
            idx = dated_visits.bsearch_index { |x, i| x.visited_at >= from_date }
            unless idx.nil?
              dated_visits = dated_visits[idx, dated_visits.size - idx]
            end
          end
          if !dated_visits.empty? && !to_date.nil?
            idx = dated_visits.bsearch_index { |x, i| x.visited_at >= to_date }
            unless idx.nil?
              dated_visits = dated_visits[0, idx]
            end
          end
          json.object do
            json.field "visits" do
              json.array do
                dated_visits.each do |visit|
                  next if !from_date.nil? && from_date >= visit.visited_at
                  break if !to_date.nil? && to_date <= visit.visited_at
                  next if !country.nil? && country != Locations[visit.location].country
                  next if !to_distance.nil? && to_distance <= Locations[visit.location].distance
                  json.object do
                    json.field "mark", visit.mark
                    json.field "visited_at", visit.visited_at
                    json.field "place", Locations[visit.location].place
                  end
                end
              end
            end
          end
        end
      when %r{^/locations/([+\-]?\d+)/avg$}
        l = Locations[$1.to_i32] rescue not_found!
        params = context.request.query_params
        from_date = get_int_param(params, "fromDate")
        to_date = get_int_param(params, "toDate")
        from_age = get_uint_param(params, "fromAge")
        to_age = get_uint_param(params, "toAge")
        gender = params["gender"]?

        if !gender.nil? && gender != "m" && gender != "f"
          bad_request!
        end

        # ages to dates
        now = emulated_now
        from_birth_date = from_age.nil? ? nil : (now - from_age.years).epoch
        to_birth_date = to_age.nil? ? nil : (now - to_age.years).epoch

        avg = 0_f64
        unless l.visits.empty?
          count, sum = 0_u32, 0_u32
          dated_visits = l.visits
          dated_visits.each do |visit|
            next if !from_date.nil? && from_date >= visit.visited_at
            next if !to_date.nil? && to_date <= visit.visited_at
            next if !gender.nil? && gender != Users[visit.user].gender
            next if !from_birth_date.nil? && from_birth_date <= Users[visit.user].birth_date
            next if !to_birth_date.nil? && to_birth_date >= Users[visit.user].birth_date
            count += 1
            sum += visit.mark
          end
          avg = (sum.to_f64 / count) + 1e-7_f64 unless count.zero?
        end
        avg = (avg * 100000_f64).round / 100000_f64
        savg = "%0.5f" % avg
        context.response.print "{\"avg\": #{savg}}"
      else
        context.response.status_code = 404
        context.response.print "{}"
      end
    when "POST"
      case context.request.path
      when "/users/new"
        new_u = User.new(StorageUser.from_json(context.request.body.not_nil!))
        bad_request! if Users.has_key?(new_u.id)
        Users[new_u.id] = new_u
        context.response.print "{}"
      when "/locations/new"
        new_l = Location.new(StorageLocation.from_json(context.request.body.not_nil!))
        bad_request! if Locations.has_key?(new_l.id)
        Locations[new_l.id] = new_l
        context.response.print "{}"
      when "/visits/new"
        new_v = Visit.new(StorageVisit.from_json(context.request.body.not_nil!))
        bad_request! if Visits.has_key?(new_v.id)
        bad_request! unless Users.has_key?(new_v.user)
        bad_request! unless Locations.has_key?(new_v.location)
        Visits[new_v.id] = new_v
        Users[new_v.user].push_visit new_v
        Locations[new_v.location].push_visit new_v
        context.response.print "{}"
      when %r{^/users/([+\-]?\d+)$}
        u = Users[$1.to_i32] rescue not_found!
        new_u = UpdateUser.from_json(context.request.body.not_nil!)
        u.assign(new_u)
        context.response.print "{}"
      when %r{^/locations/([+\-]?\d+)$}
        l = Locations[$1.to_i32] rescue not_found!
        new_l = UpdateLocation.from_json(context.request.body.not_nil!)
        l.assign(new_l)
        context.response.print "{}"
      when %r{^/visits/([+\-]?\d+)$}
        v = Visits[$1.to_i32] rescue not_found!
        new_v = UpdateVisit.from_json(context.request.body.not_nil!)
        v.assign(new_v)
        context.response.print "{}"
      else
        context.response.status_code = 404
        context.response.print "{}"
      end
    else
      context.response.status_code = 404
      context.response.print "{}"
    end
  rescue NotFoundException
    context.response.status_code = 404
    context.response.print "{}"
  rescue
    context.response.status_code = 400
    context.response.print "{}"
  end
end

master = false
children = [] of Process

Signal::TERM.trap do
  puts "#{Process.pid} term"
  exit unless master
  children.each { |p| p.kill(Signal::TERM) }
end

Signal::INT.trap do
  puts "#{Process.pid} int"
  exit unless master
  children.each { |p| p.kill(Signal::INT) }
end

Process.new("/heater")

server.listen

exit

# multiprocessing requires any form of synchronization
# between master and child processes.
# not implemented here.

CpuCount = System.cpu_count || 1

CpuCount.times do
  children << Process.fork do
    master = false
    puts "#{Process.pid}: Listening on http://0.0.0.0:80"
    server.listen(reuse_port: true)
  end
end

children.each { |p| p.wait }
