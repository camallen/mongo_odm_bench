require 'mongo'
require 'bson'
require 'mongo_mapper'
require 'mongoid'
require 'benchmark'
require 'ruby-prof'

m = Mongo::MongoClient.new
m.drop_database "benchmark-mongomapper"
m.drop_database "benchmark-mongoid"

MongoMapper.setup({"production" => {"uri" => "mongodb://localhost/benchmark-mongomapper"}}, "production")
Mongoid.load! File.expand_path("../mongoid.yml", __FILE__)
Mongoid.identity_map_enabled = true

BIRTHDAY = Time.at(123456789).to_date
INSERTS = 1000
LOOPS = 150

class MMUser
  include MongoMapper::Document
  plugin MongoMapper::Plugins::IdentityMap

  key :name,      String
  key :age,       Integer
  key :birthday,  Date
  key :timestamp, Time
end

class MongoidUser
  include Mongoid::Document

  field :name,      type: String
  field :age,       type: Integer
  field :birthday,  type: Date
  field :timestamp, type: Time
end

document = {name: "Chris", age: 30, birthday: BIRTHDAY, timestamp: Time.at(Time.now.to_i).utc}

GC.start; GC.disable
Benchmark.bm do |x|
  x.report("MongoMapper Insert") { INSERTS.times { MMUser.create(document) } }
  x.report("    Mongoid Insert") { INSERTS.times { MongoidUser.create(document) } }
end

Benchmark.bm do |x|
  [1, 25, 100, 500, 1000].each do |batch|
    GC.start; GC.disable
    x.report("MongoMapper Read %-10s batches of %-10s" % [LOOPS * batch, batch]) { LOOPS.times { MMUser.limit(batch).to_a } }
    GC.start; GC.disable
    x.report("    Mongoid Read %-10s batches of %-10s" % [LOOPS * batch, batch]) { LOOPS.times { MongoidUser.limit(batch).to_a } }
  end
end

#GC.start; GC.disable
#Benchmark.bm do |x|
#  x.report "Mongomapper" do
#    result = RubyProf.profile do
#      LOOPS.times { MMUser.limit(500).all }
#    end
#    open(File.expand_path("../callgrind.mm-prof", __FILE__), "w") do |f|
#      RubyProf::CallTreePrinter.new(result).print(f, :min_percent => 1)
#    end
#  end
#
#  x.report "Mongoid" do
#    result = RubyProf.profile do
#      LOOPS.times { MongoidUser.limit(500).to_a }
#    end
#    open(File.expand_path("../callgrind.mongoid-prof", __FILE__), "w") do |f|
#      RubyProf::CallTreePrinter.new(result).print(f, :min_percent => 1)
#    end
#  end
#end
#
