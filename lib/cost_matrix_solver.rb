# encoding: utf-8

require "rubygems"
require "gga4r" # genetic algorithm lib that also adds #shuffle! to Array, among others
require "matrix"

class CostMatrix < Matrix
	alias_method :task_count, :column_size
	alias_method :worker_count, :row_size
	
	# TODO: format matrix and make non-assigned cells blank (or put * around assigned cells)
	def to_s
		"Cost" + super.to_s # is this safe?
	end
	def inspect
		"Cost" + super.inspect
	end
end

class TaskAllocation
	attr_accessor :task_num, :worker_num, :cost
	
	def initialize(task_num, worker_num, cost_matrix)
		@task_num = task_num
		@worker_num = worker_num
		@cost = cost_matrix[worker_num, task_num]
	end
	
	def to_s
		"task #{@task_num + 1}: worker #{@worker_num + 1} at cost #{@cost}"
	end
end

class WorkerTaskAllocationSet
	attr_accessor :cost_matrix, :task_allocations
	
	def initialize(cost_matrix, task_allocations)
		@cost_matrix = cost_matrix
		@task_allocations = task_allocations
	end
	
	# fitness (goodness) is inverse of maximum cost to any one worker
	# this assumes cost is time, and you want the least time spent to do all tasks if all
	#  workers start at the same time
	# this is apparently called "min-max fairness"
	def fitness
		cost_for_each_worker = Array.new(task_allocations.length).fill(0)
		@task_allocations.each do |allocation|
			cost_for_each_worker[allocation.worker_num] += allocation.cost
		end
		1.0 / cost_for_each_worker.max
	end
	
	# (not currently) take half the task allocations from this set and half from the other
	# (current method) randomly split the task allocations between this set and the other
	def recombine(other_allocation_set)
		new_task_allocations = Array.new(cost_matrix.task_count)
		cost_matrix.task_count.times do |task_num|
			current_allocation_set = rand(2) ? @task_allocations : other_allocation_set
			current_worker_num = current_allocation_set[task_num].worker_num
			new_task_allocations[task_num] = TaskAllocation.new(task_num, \
			 current_worker_num, @cost_matrix)
		end
		
		WorkerTaskAllocationSet.new(@cost_matrix, new_task_allocations)
	end
	
	# TODO: try changing worker of just one task and see if results improve
	# randomly switch the workers two tasks are assigned to
	def mutate
		@task_allocations.shuffle!
		@task_allocations[0].worker_num, @task_allocations[1].worker_num = \
		 @task_allocations[1].worker_num, @task_allocations[0].worker_num
		@task_allocations.sort_by { |ta| ta.task_num }
	end
	
	def to_s
		# TODO: tell which worker(s) took the longest
		string = @task_allocations.sort_by{ |ta| ta.task_num }.join("\n").to_s
		string += "\nmax cost to a worker: " + (1 / fitness).to_s # this assumes fitness is inverse cost
		string += "\ninputted cost matrix: " + cost_matrix.to_s
	end
end


def create_population(cost_matrix, num = 10, include_OLB_and_UDA = false)
	population = []
	
	# TODO: make OLB and UDA generation happen in separate methods, so can also add to final population if necessary
	if include_OLB_and_UDA
		# number of tasks times, assign task to the next worker (OLB)
		task_allocations = []
		cost_matrix.task_count.times do |task_num|
			worker_num = task_num % cost_matrix.worker_count # % means modulo
			task_allocations[task_num] = TaskAllocation.new(task_num, \
			 worker_num, cost_matrix)
		end
		population << WorkerTaskAllocationSet.new(cost_matrix, task_allocations)
		
		# number of tasks times, assign task to the fastest worker for it (UDA)
		task_allocations = []
		cost_matrix.task_count.times do |task_num|
			min_cost = cost_matrix.column(task_num).to_a.min
			task_allocations[task_num] = TaskAllocation.new(task_num, \
			 cost_matrix.column(task_num).to_a.index(min_cost), cost_matrix)
		end
		population << WorkerTaskAllocationSet.new(cost_matrix, task_allocations)
	end
	
	(include_OLB_and_UDA ? num - 2 : num).times do
		# number of tasks times, assign task to a random worker
		task_allocations = []
		cost_matrix.task_count.times do |task_num|
			worker_num = rand(cost_matrix.worker_count)
			task_allocations[task_num] = TaskAllocation.new(task_num, \
			 worker_num, cost_matrix)
		end
		chromosome = WorkerTaskAllocationSet.new(cost_matrix, task_allocations)
		population << chromosome
	end
	population
end

# each column is a task (there are #task_count tasks), each row is a worker (#worker_count),
# each cell is a cost for that worker doing that task
# cost_matrix = CostMatrix[[2, 3, 6], [5, 4, 2], [4, 5, 7]]
# cost_matrix = CostMatrix[[2, 3, 6, 7, 8], [5, 4, 2, 6, 6], [4, 5, 7, 4, 7], [5, 2, 5, 3, 3]]
# cost_matrix = CostMatrix[[3,2,7,9,2,4,5], [6,6,6,6,6,6,6], [4,8,8,6,4,5,6], [7,7,7,7,7,7,7]]
# cost_matrix = CostMatrix[[100, 100, 50, 50, 50], [95, 90, 30, 25, 30], [95, 90, 25, 30, 25]]
cost_matrix = CostMatrix[[5,7,8,3,4,9,2,6,5,6],[6,6,6,6,6,6,6,6,6,6],[7,7,7,7,7,7,7,7,7,7,],[5,8,9,2,4,5,5,6,8,4],[4,7,9,3,6,4,4,8,7,6],[3,5,8,4,5,6,6,5,5,8]]
puts cost_matrix.class # TODO fix; the cost_matrix initialization line is somehow creating a plain Matrix, not a CostMatrix

POPULATION_SIZE = 10000 # increases time taken exponentially
INCLUDE_OLB_AND_UDA_IN_SEED_POPULATION = true
NUM_OF_RESULTS = 100 # increases time taken linearly
NUM_OF_EVOLUTIONS = 0 # increases time taken exponentially
# more than 100000 population on MacBook Pro may take up too much memory

# accuracy test results for third example cost matrix with various values of constants:
# 10p, 500r, 1e: 7 x "9", 5 x "10"
# 10p, 50r, 10e: 0 x "9", 9 x "10", 2 x "11", 1 x "12"
# 10p, 250r, 10e: 6 x "9", 6 x "10"

# best_results = Array.new
best_result = nil
NUM_OF_RESULTS.times do |result_num|
	puts "#{result_num}/#{NUM_OF_RESULTS} done"
	ga = GeneticAlgorithm.new(create_population(cost_matrix, POPULATION_SIZE,\
	 INCLUDE_OLB_AND_UDA_IN_SEED_POPULATION))
	
	NUM_OF_EVOLUTIONS.times { |evolution_num| ga.evolve }
	if best_result == nil || ga.best_fit[0].fitness > best_result.fitness
		best_result = ga.best_fit[0]
	end
	# best_results.push ga.best_fit[0]
end

puts "done! the best of the generated possible best results:\n\n"
puts best_result
# puts best_results.max { |a, b| a.fitness <=> b.fitness }

# helpful sites:
# http://en.wikipedia.org/wiki/Scheduling_%28production_processes%29
# http://gga4r.rubyforge.org/
# http://gga4r.rubyforge.org/rdoc/
# http://www.ruby-doc.org/core/
# http://www.cs.cornell.edu/home/selman/task/