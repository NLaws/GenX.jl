"""
    get_nuclear_technologies(inputs::Dict)::Vector{Int}

Get the indices of any resources that have "nuclear" in the `technology` field.
"""
function get_nuclear_technologies(inputs::Dict)::Vector{Int}
    ids = Int[]
    for r in inputs["RESOURCES"]
        if haskey(r, :technology)  # should be hasfield :/
            if occursin("nuclear", lowercase(r.technology))
                push!(ids, r.id)
            end
        end
    end
    return ids
end


@doc raw"""
	energy_share_requirement!(EP::Model, inputs::Dict, setup::Dict)
This function establishes constraints that can be flexibily applied to define alternative forms of policies that require generation of a minimum quantity of megawatt-hours from a set of qualifying resources, such as renewable portfolio standard (RPS) or clean electricity standard (CES) policies prevalent in different jurisdictions.
These policies usually require that the annual MWh generation from a subset of qualifying generators has to be higher than a pre-specified percentage of demand from qualifying zones.
The implementation allows for user to define one or multiple RPS/CES style minimum energy share constraints,
where each constraint can cover different combination of model zones to mimic real-world policy implementation (e.g. multiple state policies, multiple RPS tiers or overlapping RPS and CES policies).
Including an energy share requirement constraint is specified by the user by the value of the GenX settings parameter ```EnergyShareRequirement``` (this value should either 0 or 1).
For each constraint $p \in \mathcal{P}^{ESR}$, we define a subset of zones $z \in \mathcal{Z}^{ESR}_{p} \subset \mathcal{Z}$ that are eligible for trading renewable/clean energy credits to meet the corresponding renewable/clean energy requirement.
For each energy share requirement constraint $p \in \mathcal{P}^{ESR}$,
we specify the share of total demand in each eligible model zone,
$z \in \mathcal{Z}^{ESR}_{p}$, that must be served by qualifying resources,
$\mathcal{G}_{p}^{ESR} \subset \mathcal{G}$:
```math
\begin{aligned}
&\sum_{z \in \mathcal{Z}_{p}^{ESR}} \sum_{y \in \mathcal{G}_{p}^{ESR}} \sum_{t \in \mathcal{T}} (\omega_{t} \times  \Theta_{y,z,t}) \geq  \sum_{z \in \mathcal{Z}^{ESR}_{p}} \sum_{t \in \mathcal{T}} (\mu_{p,z}^{ESR} \times \omega_{t} \times D_{z,t}) + \\
&\sum_{y \in \mathcal{VS}^{stor}} \sum_{z \in \mathcal{Z}^{ESR}_{p}} \sum_{t \in \mathcal{T}} \left(\mu_{p,z}^{ESR} \times \omega_{t} \times (\frac{\Pi^{dc}_{y,z,t}}{\eta_{y,z}^{inverter}} + \Pi^{ac}_{y,z,t} - \eta_{y,z}^{inverter} \times \Theta^{dc}_{y,z,t} - \Theta^{ac}_{y,z,t}) \right) + \\
&\sum_{y \in \mathcal{O}} \sum_{z \in \mathcal{Z}^{ESR}_{p}} \sum_{t \in \mathcal{T}} \left(\mu_{p,z}^{ESR} \times \omega_{t} \times (\Pi_{y,z,t} - \Theta_{y,z,t}) \right) \hspace{1 cm}  \forall p \in \mathcal{P}^{ESR} \\
\end{aligned}
```
The final two terms in the summation above adds roundtrip storage losses to the total demand to which the energy share obligation applies.
This term is included in the constraint if the GenX setup parameter ```StorageLosses=1```.
If ```StorageLosses=0```, this term is removed from the constraint.
In practice, most existing renewable portfolio standard policies do not account for storage losses when determining energy share requirements.
However, with 100% RPS or CES policies enacted in several jurisdictions, policy makers may wish to include storage losses in the minimum energy share, as otherwise there will be a difference between total generation and total demand that will permit continued use of non-qualifying resources (e.g. emitting generators).
"""
function energy_share_requirement!(EP::Model, inputs::Dict, setup::Dict)
    println("Energy Share Requirement Policies Module")
    gen = inputs["RESOURCES"]
    T = inputs["T"]     # Number of time steps

    # esr(gen[y], tag = ESR) is the value in Resource_energy_share_requirement.csv

    @expression(EP, eESRgeneration[ESR = 1:inputs["nESR"]],
        sum(
            inputs["omega"][t] * esr(gen[y], tag = ESR) * EP[:vP][y, t]
            for y in ids_with_policy(gen, esr, tag = ESR), t in 1:T
        )
    )
    @expression(EP, eESRload[ESR = 1:inputs["nESR"]],
        sum(
            inputs["dfESR"][z, ESR] * inputs["omega"][t] * inputs["pD"][t, z]
            for t in 1:T, z in findall(x -> x > 0, inputs["dfESR"][:, ESR])
        )
    )
    add_similar_to_expression!(EP[:eESR], eESRgeneration - eESRload)

    if setup["ESRExcludeNuclearTechnologyGeneration"] == 1
        nukes = get_nuclear_technologies(inputs)
        if length(nukes) > 0
            @expression(EP, eESRnoNukes[ESR = 1:inputs["nESR"]],
                sum(
                    inputs["dfESR"][z, ESR] * inputs["omega"][t] * 
                    sum(EP[:vP][y, t] for y in intersect(nukes, resources_in_zone_by_rid(gen, z)))
                    for t in 1:T, z in findall(x -> x > 0, inputs["dfESR"][:, ESR])
                )
            )
            # add_similar_to_expression!(EP[:eESR], -1 * eESRnoNukes)
        end
    end

    # if input files are present, add energy share requirement slack variables
    if haskey(inputs, "dfESR_slack")
        @variable(EP, vESR_slack[ESR = 1:inputs["nESR"]] >= 0)
        add_similar_to_expression!(EP[:eESR], vESR_slack)


        @expression(EP,
            eCESRSlack[ESR = 1:inputs["nESR"]],
            inputs["dfESR_slack"][ESR, :PriceCap] * EP[:vESR_slack][ESR]
        )
        @expression(EP,
            eCTotalESRSlack,
            sum(EP[:eCESRSlack][ESR] for ESR in 1:inputs["nESR"])
        )

        add_to_expression!(EP[:eObj], eCTotalESRSlack)
    end

    ## Energy Share Requirements (minimum energy share from qualifying renewable resources) constraint
    if !haskey(inputs, "dfESR_slack") && !(setup["ESRExcludeNuclearTechnologyGeneration"] == 1)
        @constraint(EP, cESRShare[ESR = 1:inputs["nESR"]], eESRgeneration[ESR] - eESRload[ESR] >= 0)

    elseif haskey(inputs, "dfESR_slack") && !(setup["ESRExcludeNuclearTechnologyGeneration"] == 1)
        @constraint(EP, cESRShare[ESR = 1:inputs["nESR"]], eESRgeneration[ESR] - eESRload[ESR] + vESR_slack[ESR] >= 0)
        
    elseif haskey(inputs, "dfESR_slack") && setup["ESRExcludeNuclearTechnologyGeneration"] == 1
        @constraint(EP, cESRShare[ESR = 1:inputs["nESR"]], eESRgeneration[ESR] - eESRload[ESR] + eESRnoNukes[ESR] + vESR_slack[ESR] >= 0)
    end
end