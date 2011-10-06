require File.join (File.dirname __FILE__), 'game_state'

def do_turn game_state
  # reserve ships on a planet under attack

  $stderr.puts "defending against invading enemies"
  game_state.allied_planets.sort{|a, b| b.growth_rate <=> a.growth_rate}.each do |planet|
    planet.reserve!
#  end.each do |planet|
#    planet.reinforce!
  end

  # find the cheapest possible cost of conquering a planet
  planets = game_state.planets.map{|planet| planet.at_cheapest}.compact
  $stderr.puts "Cheapest versions of Planets:\n" + planets.map{|p| " id: #{p.id} ships: #{p.ships} turn: #{p.game_state.turn} cost: #{p.conquer.cost}\n"}.join
  # order the cheapest targets by value
  targets = planets.sort {|a, b| (b.value / b.conquer.cost) <=> (a.value / a.conquer.cost)}
  $stderr.puts "Targets:\n" + targets.map{|p| " id: #{p.id} ships: #{p.ships} growth_rate: #{p.growth_rate} value: #{p.value / p.conquer.cost}\n"}.join
  # attack each target in order of value
  targets.each do |target|
    target.attack!
  end

  game_state.enemy_planets.each do |enemy|
    ally = enemy.closest_allies.first
    need = enemy.ships
    if .closest_allies.each do |ally|
      ally.launch enemy.closest_allies.first, ally.ships
    end
  end
  game_state.finish_turn
end

map_data = ''
turn = 0
GC.disable
loop do
  current_line = gets
  if current_line.length >= 2 && current_line[0..1] == "go"
#    break if (turn += 1) > 8
    state = GameState.new 0, map_data
    do_turn state
    GameState.game_states.clear
    GC.enable
    GC.start
    GC.disable
    map_data = ''
  else
    map_data += current_line
  end
end
