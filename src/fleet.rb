require File.join (File.dirname __FILE__), 'planet'
require File.join (File.dirname __FILE__), 'game_state'

class Fleet
  attr_accessor :owner, :ships, :source, :destination, :total_turns, :turns_remaining, :game_state

   def initialize owner, ships, source, destination, total_turns, turns_remaining, game_state
     @owner = owner
     @ships = ships
     @source = source
     @destination = destination
     @total_turns = total_turns
     @turns_remaining = turns_remaining
    @game_state = game_state
  end

  def to_s
    "F #{@owner} #{@ships} #{@source} #{@destination} #{@total_turns} #{@turns_remaining}\n"
  end

  def allied?
    owner == 1
  end

  def enemy?
    owner == 2
  end
end
