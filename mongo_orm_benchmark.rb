require 'mongo'
require 'bson'
require 'mongo_mapper'
require 'mongoid'
require 'benchmark'
begin
  require 'ruby-prof'
rescue LoadError; end
begin
  require 'jruby/profiler'
rescue LoadError; end

$jruby = !Object.const_defined?(:RubyProf)

def cleanup
  GC.start
  GC.disable unless $jruby
end

def profile(prefix)
  if $jruby
    result = JRuby::Profiler.profile { yield }
  else
    result = RubyProf.profile { yield }
  end

  open(File.expand_path("../callgrind.#{prefix}.#{$jruby ? "jruby" : "mri"}.prof", __FILE__), "w") do |f|
    if $jruby
      JRuby::Profiler::FlatProfilePrinter.new(result).printProfile(f)
    else
      RubyProf::CallTreePrinter.new(result).print(f, :min_percent => 1)
    end
  end
end

INSERT = false
if INSERT
  m = Mongo::MongoClient.new
  m.drop_database "benchmark-mongomapper"
  m.drop_database "benchmark-mongoid"
end

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

if INSERT
  document = {name: "Chris", age: 30, birthday: BIRTHDAY, timestamp: Time.at(Time.now.to_i).utc}

  cleanup
  Benchmark.bm do |x|
    x.report("MongoMapper Insert") { INSERTS.times { MMUser.create(document) } }
    x.report("    Mongoid Insert") { INSERTS.times { MongoidUser.create(document) } }
  end
end

Benchmark.bmbm do |x|
  [1, 25, 100, 500, 1000].each do |batch|
    cleanup
    x.report("MongoMapper Read %-10s batches of %-10s" % [LOOPS * batch, batch]) { LOOPS.times { MMUser.limit(batch).to_a } }
    cleanup
    x.report("    Mongoid Read %-10s batches of %-10s" % [LOOPS * batch, batch]) { LOOPS.times { MongoidUser.limit(batch).to_a } }
  end
end if false

cleanup
Benchmark.bm do |x|
  x.report "Mongomapper" do
    profile "mm" do
      LOOPS.times { MMUser.limit(200).all }
    end
  end

  x.report "Mongoid" do
    profile "mongoid" do
      LOOPS.times { MongoidUser.limit(200).to_a }
    end
  end
end