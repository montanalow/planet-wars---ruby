require 'ostruct'
require File.join (File.dirname __FILE__), 'fleet'
require File.join (File.dirname __FILE__), 'game_state'

class Planet
  attr_accessor :id, :x, :y, :owner, :ships, :growth_rate, :game_state, :turn

  def initialize id, x, y, owner, ships, growth_rate, game_state
#    $stderr.puts "Planet.new #{id}, #{x}, #{y}, #{owner}, #{ships}, #{growth_rate}, #{game_state.turn}"
    @id = id
    @x = x
    @y = y
    @owner = owner
    @ships = ships
    @growth_rate = growth_rate
    @game_state = game_state
    @turns_to = {id => 0}
  end

  def to_s
    "P #{x} #{y} #{owner} #{ships} #{growth_rate}\n"
  end

  def turns_to planet
    @turns_to[planet.id] ||= (Math::sqrt (x - planet.x) ** 2 + (y - planet.y) ** 2).ceil
  end

  def neutral?
    owner == 0
  end

  def allied?
    owner == 1
  end

  def enemy?
    owner == 2
  end

  def planets_by_distance
    @planets_by_distance ||= game_state.planets.select {|planet| planet.ships > 0}.sort {|a,b| (a.turns_to self) <=> (b.turns_to self)}
  end

  def allied_planets_by_distance
    @allied_planets_by_distance ||= game_state.planets.select {|planet| planet.ships > 0 && planet.owner == 1 && planet.id != id}.sort {|a,b| (a.turns_to self) <=> (b.turns_to self)}
  end

  def enemy_planets_by_distance
    @enemy_planets_by_distance ||= game_state.planets.select {|planet| planet.ships > 0 && planet.owner == 2 && planet.id != id}.sort {|a,b| (a.turns_to self) <=> (b.turns_to self)}
  end

  def incoming_fleets
    game_state.fleets.select {|fleet| fleet.destination == self}
  end

  def incoming_enemy_fleets
    incoming_fleets.select {|fleet| fleet.owner != 1}
  end

  def landing_fleets
    incoming_fleets.select {|fleet| fleet.turns_remaining == 1}
  end

  def landing_allied_ships
    landing_fleets.select {|fleet| fleet.allied?}.map {|fleet| fleet.ships}.sum
  end

  def landing_enemy_ships
    landing_fleets.select {|fleet| fleet.enemy?}.map {|fleet| fleet.ships}.sum
  end

  def turns
    GameState.game_states.map {|game_state| game_state.planets[id]}
  end

  def at turn
    GameState.game_states[turn].planets[id]
  end

  def at_cheapest
#    $stderr.puts "at_cheapest #{id}"
    @at_cheapest ||= 
    GameState.game_states.map do |game_state|
      game_state.planets[id]
    end.select do |planet|
      !planet.conquer.nil?
    end.sort do |a, b|
      [a.conquer.cost, a.game_state.turn] <=> [b.conquer.cost, b.game_state.turn]
    end.first
  end

  def launch_fleet destination, ships
    $stderr.puts "launching #{ships} ships in #{game_state.turn} turns from planet #{self.id} with #{self.ships} ships to planet #{destination.id} with #{destination.ships} ships will arrive in #{self.game_state.turn + (turns_to destination)}"
    
    GameState.game_states.each do |game_state|
      if game_state.turn == 0
        turns_to_destination = self.game_state.turn + (turns_to destination)
        game_state.planets[id].ships -= ships
        game_state.fleets << (Fleet.new 1, ships, game_state.planets[id], game_state.planets[destination.id], turns_to_destination, turns_to_destination, game_state)
      else
        GameState.game_states[game_state.turn] = GameState.game_states[game_state.turn - 1].next_state
      end
    end
    
    if self.game_state.turn == 0 && ships > 0
      game_state.issue_order self, destination, ships
    end
  end

  def conquer for_realz = false
    if for_realz
      @conquer = nil
    end

    @conquer ||=
    if allied? || game_state.turn == 0
      nil
    else
      need = ships
      need += 1 if !(at game_state.turn - 1).allied? # invasions require 1 extra ship for conquest
      cost = 0
      total_distance = 0
      # attack until there are no ships left on the planet
      planets_by_distance.each do |source|
        distance = turns_to source
        if distance <= game_state.turn
          source = source.at game_state.turn - distance
          if source.enemy?
            need += source.ships
          end
        else
          break
        end
      end

#      $stderr.print "planet: #{id} turn: #{game_state.turn} ships: #{ships} need: #{need}"
      planets_by_distance.each do |source|
        distance = turns_to source
        if distance <= game_state.turn && need > 0
          source = source.at game_state.turn - distance
          if source.allied?
            ships = [0, [source.ships, need].min].max
            need -= ships
            cost += ships
            total_distance += ships * distance
            source.launch_fleet self, ships if for_realz
          end
        else
          break
        end
      end

#      $stderr.puts " remaining need: #{need} cost: #{cost}"
      if need > 0
        # not enough allied ships within range to conquer this planet
        OpenStruct.new :cost => 1 / 0.0, :distance => total_distance # cost infinity
      else
        OpenStruct.new :cost => cost, :distance => total_distance # cost infinity
      end
    end
  end

  def value
    growth_rate.to_f * case owner
    when 0
      1
    when 1
      0
    when 2
      8
    end
  end

  def attack!
    conquer true
  end

  def reserve ships
    ships = [0, [@ships, ships].min].max
    @ships -= ships;
    Fleet.new 1, ships, self, self, 0, 0, game_state
  end

  def reserve!
    incoming_enemy_fleets.each do |enemy_fleet|
      before_invasion = at enemy_fleet.turns_remaining - 1
      if before_invasion.allied?
        after_invasion = at enemy_fleet.turns_remaining
        if after_invasion.allied?
          # reserve only as many ships as it takes to defend
           reserve ships - after_invasion.ships
        else
          # reserve everything, we're gonna need backup
           reserve ships
        end
      end
    end
  end
end
