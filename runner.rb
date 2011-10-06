#! /usr/local/bin/ruby
TIMEOUT = 3000

running = true
trap "INT" do
  running = false
end

require 'ostruct'
require 'optparse'

options = OpenStruct.new \
  :tcp => false,
  :show => false,
  :maps => Dir.entries("./maps").select{|m| m[-4..-1] == ".txt"}.sort{|a,b| a[3..-4].to_i <=> b[3..-4].to_i},
  :bots => Dir.entries("./bots").select {|b| b[0..10] != "planet_wars" && b[0] != '.'},
  :players => [1,2],
  :log => "debug.log"

OptionParser.new do |parser|
  parser.banner = "Usage: runner.rb [options]"
  parser.separator ""
  parser.separator "Specific Options"
  parser.on "-m", "--maps [MAPS]", Array, "an optional list of maps to play, defaults to all .txt in ./maps" do |maps|
    options.maps = maps.map{|map| map[-4..-1] == ".txt" ? map : "map#{map}.txt"}
  end
  parser.on "-b", "--bots [BOTS]", Array, "an optional list of bots to play, defaults to all .jar in ./example_bots" do |bots|
    options.bots = bots
  end
  parser.on "-t", "--tcp" do
    options.tcp = true
  end
  parser.on "-s", "--show" do
    options.show = true
  end
  parser.on "-p", "--players [PLAYERS]", Array, "an optional list of players to play as, defaults to [1,2]" do |players|
    options.players = players.map{|player| player.to_i}
  end
  parser.on "-l", "--log [FILE_NAME]", "an optional log file, defaults to debug.log" do |file|
    options.log = file
  end
  parser.on_tail("-h", "--help", "Show this message") do
    puts parser
  end
end.parse!

if options.tcp
  while running do
    puts "\nStarting match"
    puts `./tools/tcp 72.44.46.68 995 montanalow-0.1.3 ./planet_wars`
    print "next match in"
    (1...10).each do |i|
      print " #{10 - i}"
      sleep 1 if running
    end
  end
  exit
end

wins = 0
losses = 0
collisions = 0
draws = 0
win_moves = 0

m_results = Hash.new {|hash,key| hash[key] = {:wins => 0, :win_moves => 0, :losses => 0, :draws => 0}}
options.maps.each do |m|
  options.bots.each do |b|
    next unless running
    if options.players.include? 1
      begin
        `#{options.show ? "tools/playnview" : "tools/playgame"} maps/#{m} #{TIMEOUT} #{TIMEOUT} log.txt "ruby src/main.rb" bots/#{b} 2> #{options.log}`
        debug = File.read(options.log).split("\n")
        if debug.empty?
          puts "lost output...wtf"
          raise "fuck"
        end
      rescue
        retry 
      end
      moves = debug.select{|line| (line =~ /Turn \d+/) == 0}.size
      result = debug[-1]
      File.delete options.log
      if result == "Player 1 Wins!"
        m_results[m][:wins] += 1
        m_results[m][:win_moves] += moves
        wins += 1
        win_moves += moves
        print "!!! win !!! (#{moves} moves)"
      elsif result == "Player 2 Wins!"
        m_results[m][:losses] += 1
        losses += 1
        print "@@@ loss @@@ (#{moves} moves)"
      elsif result == "Draw!"
        m_results[m][:draws] += 1
        collisions += 1
        print "### draw ### (#{moves} moves)"
      else
        print "&&&&&&& what:|#{result}|"
      end
      puts " as player 1 vs #{b} @ #{m} | ./runner.rb -b #{b} -m #{m} -p 1 -l tmp.txt -s"
    end
    next unless running
    if options.players.include? 2
      begin
        `#{options.show ? "tools/playnview" : "tools/playgame"} maps/#{m} #{TIMEOUT} #{TIMEOUT} log.txt bots/#{b} "ruby src/main.rb" 2> #{options.log}`
        debug = File.read(options.log).split("\n")
        if debug.empty?
          puts "lost output...wtf"
          raise "fuck"
        end
      rescue
        retry
      end
      moves = debug.select{|line| (line =~ /Turn \d+/) == 0}.size
      result = debug[-1]
      File.delete options.log
      if result == "Player 2 Wins!"
        m_results[m][:wins] += 1
        m_results[m][:win_moves] += moves
        wins += 1
        win_moves += moves
        print "!!! win !!! (#{moves} moves)"
      elsif result == "Player 1 Wins!"
        m_results[m][:losses] += 1
        losses += 1
        print "@@@ loss @@@ (#{moves} moves)"
      elsif result == "Draw!"
        m_results[m][:draws] += 1
        collisions += 1
        print "### draw ### (#{moves} moves)"
      else
        print "&&&&&&& what:|#{result}|"
      end
      puts " as player 2 vs #{b} @ #{m} | ./runner.rb -b #{b} -m #{m} -p 2 -l tmp.txt -s"
    end
  end
end

m_results.each do |map, results|
  puts "================================"
  puts "@ #{map}"
  puts "Wins: #{results[:wins]} (#{results[:win_moves] / (options.bots.size * options.players.size)} avg moves)"
  puts "Losses: #{results[:losses]}"
  puts "Draws: #{results[:draws]}"
  puts "-------------------------------"
  puts "Ratio: #{(results[:wins].to_f + 0.5 * results[:draws]) / (results[:wins] + results[:losses] + results[:draws])}"
end
puts "-------------------------------"
puts "Wins: #{wins} (#{win_moves / (options.bots.size * options.maps.size * options.players.size)} avg moves)"
puts "Losses: #{losses}"
puts "Draws: #{draws}"
puts "-------------------------------"
puts "Ratio: #{(wins.to_f + 0.5 * (draws + collisions)) / (wins + losses + draws + collisions)}"
