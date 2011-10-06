require File.join (File.dirname __FILE__), 'fleet'
require File.join (File.dirname __FILE__), 'planet'

class GameState
  attr_accessor :planets, :fleets, :max_fleet_turns_remaining, :turn
  @@game_states = []
  def self.game_states
    @@game_states
  end

  def self.game_states= game_states
    @@game_states = game_states
  end

  def initialize turn, game_state = nil
    @turn = turn
    @@game_states[@turn] = self
    parse_game_state game_state if game_state
#    $stderr.puts "GameState.new #{turn}, #{game_state}"
  end

  def allied_planets
    @planets.select {|planet| planet.owner == 1 }
  end

  def neutral_planets
    @planets.select {|planet| planet.owner == 0 }
  end

  def enemy_planets
    @planets.select {|planet| planet.owner > 1 }
  end

  def not_allied_planets
    @planets.reject {|planet| planet.owner == 1 }
  end

  def allied_fleets
    @fleets.select {|fleet| fleet.owner == 1 }
  end

  def enemy_fleets
    @fleets.select {|fleet| fleet.owner > 1 }
  end

  def max_fleet_turns_remaining
    @fleets.map {|fleet| fleet.turns_remaining}.max || 0
  end
  
  def to_s
    @planets.map {|planet| planet.to_s} + @fleets.map {|fleet| fleet.to_s}
  end

  def next_state
#    #$stderr.puts "NEXT STATE: #{turn + 1}"
    next_state = GameState.new turn + 1
    next_state.planets = planets.map do |planet|
      owner = planet.owner;
      ships = planet.ships;

      # initialize ships on the planet and add newly produced ships to player controlled planets
      neutral_ships = allied_ships = enemy_ships = 0;
      case owner
      when 0
        neutral_ships = ships
      when 1
        allied_ships = ships + planet.growth_rate
      when 2
        enemy_ships = ships + planet.growth_rate
      end

      # total up all ships arriving on this next turn
      fleets.each do |fleet|
        if fleet.destination.id == planet.id && fleet.turns_remaining <= 1
          case fleet.owner
          when 1
            allied_ships += fleet.ships
          when 2
            enemy_ships += fleet.ships
          end
        end
      end

      # set the owner of the planet, and the number of ships remaining
      if neutral_ships > allied_ships && neutral_ships > enemy_ships
        # neutral powers win
        ships = neutral_ships - [allied_ships, enemy_ships].max
        owner = 0
      elsif allied_ships > neutral_ships && allied_ships > enemy_ships
        # allies win
        ships = allied_ships - [neutral_ships, enemy_ships].max
        owner = 1
      elsif enemy_ships > allied_ships && enemy_ships > neutral_ships
        # enemies win
        ships = enemy_ships - [neutral_ships, allied_ships].max
        owner = 2
      else
        # no clear winner, all ships are annihilated and control remains the same
        ships = 0
      end
      Planet.new planet.id, planet.x, planet.y, owner, ships, planet.growth_rate, next_state
    end
    next_state.fleets = fleets.map do |fleet|
      if fleet.turns_remaining > 1
        Fleet.new fleet.owner, fleet.ships, next_state.planets[fleet.source.id], next_state.planets[fleet.destination.id], fleet.total_turns, fleet.turns_remaining - 1, next_state
      else
        nil
      end
    end.compact
    next_state
  end

  def issue_order source, destination, ships
    $stderr.puts "#{source.id} #{destination.id} #{ships}"
    $stdout.puts "#{source.id} #{destination.id} #{ships}"
  end

  def finish_turn
    $stderr.puts "go"
    $stdout.puts "go"
    $stderr.flush
    $stdout.flush
  end

  def parse_game_state game_state
    @planets = []
    @fleets = []
    id = 0

    (game_state.split "\n").each do |line|
      line = (line.split "#")[0]
      tokens = (line.split " ")
      next if tokens.length == 1
      if tokens[0] == "P"
        return if tokens.length != 6
        @planets << (Planet.new id, tokens[1].to_f, tokens[2].to_f, tokens[3].to_i, tokens[4].to_i, tokens[5].to_i, self)
        id += 1
      elsif tokens[0] == "F"
        return if tokens.length != 7
        @fleets << (Fleet.new tokens[1].to_i, tokens[2].to_i, planets[tokens[3].to_i], planets[tokens[4].to_i], tokens[5].to_i, tokens[6].to_i, self)
      else
        return
      end
    end
    ((@turn + 1)..[30, max_fleet_turns_remaining].max).each do |turn|
      @@game_states[turn] = @@game_states[turn - 1].next_state
    end
  end
end

class Array
  def map_with_index!
    each_with_index {|e, i| self[i] = yield e, i}
  end

  def map_with_index &block
    dup.map_with_index! &block
  end
end