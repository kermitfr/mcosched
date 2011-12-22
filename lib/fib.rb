module Fib
  def self.fib(args)
    n = args['iterations']
    curr = 0
    succ = 1

    n.times do |i|
      sleep 0.1
      curr, succ = succ, curr + succ
    end
   
    return { :iteration => n, :value => curr }
  end
end
