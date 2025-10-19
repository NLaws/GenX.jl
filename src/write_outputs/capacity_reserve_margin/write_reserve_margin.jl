function write_reserve_margin(path::AbstractString, setup::Dict, EP::Model)
    temp_ResMar = dual.(EP[:cCapacityResMargin])
    if setup["ParameterScale"] == 1
        temp_ResMar = temp_ResMar * ModelScalingFactor # Convert from MillionUS$/GWh to US$/MWh
    end

    dfResMar = DataFrame(temp_ResMar, :auto)
    CSV.write(joinpath(path, "ReserveMargin.csv"), dfResMar)
    return nothing
end


function write_cap_reserve_2(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    NCRM = inputs["NCapacityReserveMargin"]
    max_demand_by_zone = maximum(inputs["pD"], dims=1)
    # RHS is the minimum value of the capacity reserve
    RHS = [
        sum(
            max_demand_by_zone[z] * (1 + inputs["dfCapRes"][z, res])
            for z in findall(x -> x != 0, inputs["dfCapRes"][:, res])
        )
        for res=1:NCRM
    ]

    default = repeat([0.0], length(RHS))

    df = DataFrame(
        thermal_contribution = vec(value.(EP[:eCapResMarBalanceThermal])),
        vre_contribution = !isempty(inputs["VRE"]) ? vec(value.(EP[:eCapResMarBalanceVRE])) : default,
        hydro_contribution = !isempty(inputs["HYDRO_RES"]) ? vec(value.(EP[:eCapResMarBalanceHydro])) : default,
        must_run_contribution = !isempty(inputs["MUST_RUN"]) ? vec(value.(EP[:eCapResMarBalanceMustRun])) : default,
        storage_contribution = !isempty(inputs["STOR_ALL"]) ? vec(value.(EP[:eCapResMarBalanceStor])) : default,
        slack_contribution = haskey(inputs, "dfCapRes_slack") ? vec(value.(EP[:vCapResSlack])) : default,
        required_reserve = RHS,
        installed_reserve = vec(value.(EP[:eCapResMarBalance])),
        peak_demand = vec(max_demand_by_zone),
    )
    df .= round.(df, digits=3)


    if setup["ParameterScale"] == 1
        # TODO scale values
        max_demand_by_zone .*= ModelScalingFactor # Convert GW to MW
    end

    CSV.write(joinpath(path, "CapacityReserveMargin2.csv"), df)

end