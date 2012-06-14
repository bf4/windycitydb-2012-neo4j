# brew install gremlin
require 'rubygems'
require 'neography'

@neo = Neography::Rest.new

def create_person(name)
  @neo.create_node("name" => name)
end

def make_mutual_friends(node1, node2)
  @neo.create_relationship("friends", node1, node2)
  @neo.create_relationship("friends", node2, node1)
end

# see this
def degrees_of_separation(start_node, destination_node)
  paths =  @neo.get_paths(start_node,
                          destination_node,
                          {"type"=> "friends", "direction" => "in"},
                          depth=4,
                          algorithm="allSimplePaths")
  paths.each do |p|
   p["names"] = p["nodes"].collect { |node|
     @neo.get_node_properties(node, "name")["name"] }
  end
end

johnathan = create_person('Johnathan')
mark      = create_person('Mark')
phil      = create_person('Phil')
mary      = create_person('Mary')

make_mutual_friends(johnathan, mark)
make_mutual_friends(mark, phil)
make_mutual_friends(phil, mary)
make_mutual_friends(mark, mary)

# new gremlin code
def suggestions_for(node)
  node_id = node["self"].split('/').last.to_i
  @neo.execute_script("g.v(node_id).
                         in('friends').
                         in('friends').
                         dedup.
                         filter{it != g.v(node_id)}.
                         name", {:node_id => node_id})
end

puts "Johnathan should become friends with #{suggestions_for(johnathan).join(', ')}"

# RESULT
# Johnathan should become friends with Mary, Phil
#
#gremlin 2
def degrees_of_separation(start_node, destination_node)
  start_node_id = start_node["self"].split('/').last.to_i
  destination_node_id = destination_node["self"].split('/').last.to_i
  @neo.execute_script("g.v(start_node_id).
                         as('x').
                         in.loop('x'){it.loops <= 4 &
                                      it.object.id != destination_node_id}.
                         simplePath.
                         filter{it.id == destination_node_id}.
                         paths{it.name}", {:start_node_id => start_node_id,
                                           :destination_node_id => destination_node_id })
end

degrees_of_separation(johnathan, mary).each do |path|
  puts "#{(path.size - 1 )} degrees: " + path.join(' => friends => ')
end

# RESULT
# 3 degrees: Johnathan => friends => Mark => friends => Phil => friends => Mary
# 2 degrees: Johnathan => friends => Mark => friends => Mary
