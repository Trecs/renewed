class MyStruct < Struct
  def initialize(**attributes)
    attributes.each do |k, v|
      public_send "#{k}=", v
    end
  end
end

module Trecs
  class Timer
    def sleep(time)
      puts " "*30 + "sleep #{time}"
    end
  end

  class Frame
    attr_accessor :time
    attr_reader :content
    def initialize(time: nil, content:)
      @time = time
      @content = content
    end

    def render(screen)
      screen.puts("Frame: #{time}: #{content}")
    end

    def prepare(state)
    end
  end

  class MyStrategy
    attr_accessor :time
    attr_reader :step
    attr_reader :content
    attr_reader :timer
    attr_reader :duration
    
    def initialize(time: nil, content: , duration: 10)
      @time = time
      @content = content
      @duration = duration
    end

    def render(screen)
      content.split("").each_with_object("") do |c, msg|
        msg << c
        screen.puts msg
        timer.sleep step
      end
    end

    def prepare(state)
      raise "Time was not set for frame #{self}." unless time
      @timer = state.timer
      if state.next_frame && state.previous_frame
        @duration = state.next_frame.time - state.previous_frame.time
      end
      @step = duration.to_f / @content.size
    end
  end
  class Transition
    attr_accessor :time
    def initialize(time: nil)
      @time = time
    end
    
    def prepare(state)
      raise "Next frame must be a frame." unless state.next_frame.is_a? Frame
      raise "Previous frame must be a frame." unless state.previous_frame.is_a? Frame
      @duration = state.next_frame.time - state.previous_frame.time
      @from = state.previous_frame.content
      @to   = state.next_frame.content
    end
  end
  
  class MyTransition < Transition
    def render(screen)
      screen.puts "Transition %{duration}ms : %{from} ==(#{rand(100..999)})==> %{to}" % {duration: @duration, from: @from.inspect, to: @to.inspect}
    end
  end

  class YourTransition < Transition
    def render(screen)
      screen.puts "%{from}==>%{to}" % {from: @from.inspect, to: @to.inspect}
    end
  end

  class Undefined; end
  State = MyStruct.new(:timer, :previous_frame, :next_frame)

  class ArrayFrameSource
    include Enumerable
    attr_reader :frames

    def initialize(frames)
      @frames = frames.sort_by(&:time).freeze
    end

    def each(&block)
      frames.each(&block)
    end

    def to_h
      @to_h ||= frames.map { |f| [f.time, f]}.to_h
    end

    def timestamps
      @timestamps ||= frames.map(&:time).sort.freeze
    end

    def [](time)
      to_h[timestamp_at(time)]
    end

    private

    def timestamp_at(time)
      return time if timestamps.include?(time)
      return timestamps.first if time < timestamps.first
      pair = timestamps.each_cons(2).find { |a, b|
        a < time && b > time
      }
      (pair && pair.first) || timestamps.last
    end
  end

  class HashFrameSource
    include Enumerable
    attr_reader :frames_hash
    
    def initialize(frames)
      @frames_hash = frames.sort.to_h.freeze
      frames.each do |time, frame|
        frame.time = time
      end
    end

    def each(&block)
      frames_hash.values.each(&block)
    end

    def frames
      @frames ||= frames_hash.values
    end
    
    def to_h
      frames_hash
    end

    def timestamps
      @timestamps ||= frames_hash.keys.sort.freeze
    end

    def [](time)
      frames_hash[timestamp_at(time)]
    end

    private

    def timestamp_at(time)
      return time if timestamps.include?(time)
      return timestamps.first if time < timestamps.first
      pair = timestamps.each_cons(2).find { |a, b|
        a < time && b > time
      }
      (pair && pair.first) || timestamps.last
    end
  end

  class Player
    attr_reader :source
    attr_reader :screen
    attr_reader :timer

    def initialize(source: Undefined, screen: $stdout, timer: Timer.new)
      @source = source
      @screen = screen
      @timer  = timer

      prepare_frames
    end

    def play
      screen.puts ">>> Play <<<"
      source[0].render(screen)
      timestamps.each_cons(2) do |prev, curr|
        timer.sleep(curr-prev)
        source[curr].render(screen)
      end
      screen.puts ">>> End <<<"
    end

    def timestamps
      source.timestamps
    end

    def [](time)
      source.frame_at(time)
    end

    private

    def prepare_frames
      [nil, *source.frames, nil].each_cons(3) do |prv, current, nxt|
        state = State.new(timer: timer, next_frame: nxt, previous_frame: prv)
        current.prepare(state)
      end
    end
  end
end

timer = Trecs::Timer.new
source = Trecs::ArrayFrameSource.new([
                                      Trecs::Frame.new(time: 0, content: "-"),
                                      Trecs::Frame.new(time: 20, content: "--"),
                                      Trecs::YourTransition.new(time: 25),
                                      Trecs::Frame.new(time: 45, content: "---"),
                                      Trecs::MyTransition.new(time: 50),
                                      Trecs::Frame.new(time: 200, content: "***"),
                                      Trecs::MyStrategy.new(time: 210, content: "Federico", duration: 30),
                                     ])

source2 = Trecs::HashFrameSource.new({
                                      0   => Trecs::Frame.new( content: "-"),
                                      20  => Trecs::Frame.new( content: "--"),
                                      25  => Trecs::YourTransition.new(),
                                      45  => Trecs::Frame.new( content: "---"),
                                      50  => Trecs::MyTransition.new(),
                                      200 => Trecs::Frame.new( content: "***"),
                                      210 => Trecs::MyStrategy.new( content: "Federico", duration: 30),
                                      })

player = Trecs::Player.new(source: source)
player.timestamps
# => [0, 20, 25, 45, 50, 200, 210]

player.play

player2 = Trecs::Player.new(source: source)
player2.timestamps
# => [0, 20, 25, 45, 50, 200, 210]

player2.play


# >> >>> Play <<<
# >> Frame: 0: -
# >>                               sleep 20
# >> Frame: 20: --
# >>                               sleep 5
# >> "--"==>"---"
# >>                               sleep 20
# >> Frame: 45: ---
# >>                               sleep 5
# >> Transition 155ms : "---" ==(270)==> "***"
# >>                               sleep 150
# >> Frame: 200: ***
# >>                               sleep 10
# >> F
# >>                               sleep 3.75
# >> Fe
# >>                               sleep 3.75
# >> Fed
# >>                               sleep 3.75
# >> Fede
# >>                               sleep 3.75
# >> Feder
# >>                               sleep 3.75
# >> Federi
# >>                               sleep 3.75
# >> Federic
# >>                               sleep 3.75
# >> Federico
# >>                               sleep 3.75
# >> >>> End <<<
# >> >>> Play <<<
# >> Frame: 0: -
# >>                               sleep 20
# >> Frame: 20: --
# >>                               sleep 5
# >> "--"==>"---"
# >>                               sleep 20
# >> Frame: 45: ---
# >>                               sleep 5
# >> Transition 155ms : "---" ==(176)==> "***"
# >>                               sleep 150
# >> Frame: 200: ***
# >>                               sleep 10
# >> F
# >>                               sleep 3.75
# >> Fe
# >>                               sleep 3.75
# >> Fed
# >>                               sleep 3.75
# >> Fede
# >>                               sleep 3.75
# >> Feder
# >>                               sleep 3.75
# >> Federi
# >>                               sleep 3.75
# >> Federic
# >>                               sleep 3.75
# >> Federico
# >>                               sleep 3.75
# >> >>> End <<<
