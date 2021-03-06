mutable struct FwdsNode
  x::AbstractArray{Float64, 1}
  u::AbstractArray{Float64, 1}
  r::Float64

  FwdsNode(x) = new(x, Float64[], 0.0)
  FwdsNode(x, u) = new(x, u, 0.0)
end

function plan_fwds(x::AbstractArray{Float64, 1}, agent::Agent, world::World, 
                   reward::Function, ctrl_d::Discretization, depth::Int)
  root = Tree(FwdsNode(x))

  rs = select_action_fwds(root, agent, world, reward, ctrl_d, depth)
  for node in root.next
    if node.value.r >= rs
      return node.value.u
    end
  end
  error("No best action? FWDS has a bug")

  return Float64[]
end

function select_action_fwds(node::Tree, agent::Agent, world::World, 
                            reward::Function, ctrl_d::Discretization, 
                            depth::Int)
  if depth <= 0
    return 0.0
  end

  max_r = -Inf
  us = Float64[]

  node.value.x[1] = mod(node.value.x[1], world.road.path.S[end])

  la_len = ctrl_d.thr[end] * ctrl_d.pt[end] # number of actions to survey
  node.next = Array{Tree, 1}(undef, la_len)
  for la in 0:(la_len - 1)
    u = dis.ls2x(ctrl_d, la)
    agent.custom = u
    nx = copy(node.value.x)
    sim.advance!(sim.default_dynamics!, nx, Pair(agent, world), 0.0, olm_dt, 
                 olm_h)
    nx[1] = mod(nx[1], world.road.path.S[end])
    r = reward(node.value.x, u, nx, agent, world)
    value = FwdsNode(nx, u)
    node.next[la + 1] = Tree(value)
    next_r = select_action_fwds(node.next[la + 1], agent, world, reward, 
                                ctrl_d, depth - 1)
    r = reward(node.value.x, u, nx, agent, world) + olm_gamma * next_r
    node.next[la + 1].value.r = r

    #println("x = $(node.value.x), u = $(u), nx = $(nx), r = $(r)")

    if r > max_r
      max_r = r
    end
  end

  return max_r
end

function controller_fwds!(u::AbstractArray{Float64}, 
                          x::AbstractArray{Float64}, 
                          dx::AbstractArray{Float64}, 
                          agent_world::Pair{Agent, World}, t::Float64)
  agent = agent_world.first
  u[1] = agent.custom[1]
  u[2] = agent.custom[2]
end
