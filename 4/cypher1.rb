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

#cypher1
def suggestions_for(node)
  node_id = node["self"].split('/').last.to_i
  @neo.execute_query("START me = node({node_id})
                      MATCH (me)-[:friends]->(friend)-[:friends]->(foaf)
                      RETURN foaf.name", {:node_id => node_id})["data"]
end

puts "Johnathan should become friends with #{suggestions_for(johnathan).join(', ')}"

# RESULT
# Johnathan should become friends with Mary, Phil
#
#cypher2
def degrees_of_separation(start_node, destination_node)
  start_node_id = start_node["self"].split('/').last.to_i
  destination_node_id = destination_node["self"].split('/').last.to_i
  @neo.execute_query("START me=node({start_node_id}),
                            them=node({destination_node_id})
                      MATCH path = allShortestPaths( me-[?*]->them )
                      RETURN length(path), extract(person in nodes(path) : person.name)",
                      {:start_node_id => start_node_id,
                       :destination_node_id => destination_node_id })["data"]
end


degrees_of_separation(johnathan, mary).each do |path|
  nodes = path.last
  puts "#{path.first} degrees: " + nodes.join(' => friends => ')
end

# RESULT
# 2 degrees: Johnathan => friends => Mark => friends => Mary
