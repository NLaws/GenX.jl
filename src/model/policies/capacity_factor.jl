"""
    get_new_ng_technologies(inputs::Dict)::Vector{Int}

Get the indices of any resources that have "nuclear" in the `technology` field.
"""
function get_new_ng_technologies(inputs::Dict)::Vector{Int}
    ids = Int[]
    for r in inputs["RESOURCES"]
        if haskey(r, :technology)  # should be hasfield :/
            if startswith(r.technology, "NG_")
                push!(ids, r.id)
            end
        end
    end
    return ids
end


function limit_ng_techs_to_40_cap_factor(EP::Model, inputs::Dict, setup::Dict)
    ng_resources = get_new_ng_technologies(inputs)
    T = inputs["T"] 

    @constraint(EP, cNG40CapFactor[y in ng_resources],
        sum(EP[:vP][y, t] for t in 1:T) <= 0.40 * EP[:eTotalCap][y] * T
    )
    @info "NG_ technologies limited to 40% caapcity factor."

end
