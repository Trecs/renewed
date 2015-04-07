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
    attr_reader :time
    attr_reader :content
    def initialize(time, content)
      @time = time
      @content = content
    end

    def render(screen)
      screen.puts("Frame: #{time}: #{content}")
    end

    def prepare(state)
    end
  end

  class MyTransition
    attr_reader :time

    def initialize(time)
      @time = time
    end
    
    def render(screen)
      screen.puts "Transition %{duration}ms : %{from} ==(#{rand(100..999)})==> %{to}" % {duration: @duration, from: @from.inspect, to: @to.inspect} 
    end
    
    def prepare(state)
      @duration = state.next_frame.time - state.previous_frame.time
      @from = state.previous_frame.content
      @to   = state.next_frame.content
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
                                      Trecs::Frame.new(0, "-"),
                                      Trecs::Frame.new(20, "--"),
                                      Trecs::Frame.new(45, "---"),
                                      Trecs::MyTransition.new(50),
                                      Trecs::Frame.new(200, "***"),
                                     ])

player = Trecs::Player.new(source: source)
player.timestamps
# => [0, 20, 45, 50, 200]

player.play


# >> >>> Play <<<
# >> Frame: 0: -
# >>                               sleep 20
# >> Frame: 20: --
# >>                               sleep 25
# >> Frame: 45: ---
# >>                               sleep 5
# >> Transition 155ms : "---" ==(224)==> "***"
# >>                               sleep 150
# >> Frame: 200: ***
# >> >>> End <<<
