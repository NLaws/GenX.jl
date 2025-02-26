@doc raw"""
	load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)

Read input parameters related to planning reserve margin constraints
"""
function load_cap_reserve_margin!(setup::Dict, path::AbstractString, inputs::Dict)
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Capacity_reserve_margin_slack.csv"
    if isfile(joinpath(path, filename))
        df = load_dataframe(joinpath(path, filename))
        inputs["dfCapRes_slack"] = df
        inputs["dfCapRes_slack"][!, :PriceCap] ./= scale_factor # Million $/GW if scaled, $/MW if not scaled
        println(filename * " Successfully Read!")
    end

    filename = "Capacity_reserve_margin.csv"
    df = load_dataframe(joinpath(path, filename))
    mat = extract_matrix_from_dataframe(df, "CapRes")
    inputs["dfCapRes"] = mat
    inputs["NCapacityReserveMargin"] = size(mat, 2)

    gen = inputs["RESOURCES"]
    res = 1:inputs["NCapacityReserveMargin"]
    inputs["DERATING_FACTOR"] = [derating_factor(g, tag = r) for g in gen, r = res]

    println(filename * " Successfully Read!")

    filename = "ring_fenced_generators.csv"
    fpath = joinpath(path, filename)
    if isfile(fpath)
        inputs["ring_fenced_generators"] = load_dataframe(fpath)[!, "firm_capacity"][1] / scale_factor
        println(filename * " Successfully Read!")
    end

    filename = "Capacity_reserve_peak_load.csv"
    fpath = joinpath(path, filename)
    if isfile(fpath)
        inputs["capacity_reserve_peak_load"] = load_dataframe(fpath)[!, "peak_load"][1] / scale_factor
        println(filename * " Successfully Read!")
    end

    filename = "Capacity_market.csv"
    fpath = joinpath(path, filename)
    if isfile(fpath)
        df = load_dataframe(fpath)
        inputs["capacity_market"] = Dict(
            "limit" => df[!, "limit"][1] / scale_factor,
            "price" => df[!, "price"][1] / scale_factor,
        )
        println(filename * " Successfully Read!")
    end

    filename = "Capacity_requirements.csv"
    fpath = joinpath(path, filename)
    if isfile(fpath)
        df = load_dataframe(fpath)
        inputs["required_capacity"] = df[!, "required_capacity"][1] / scale_factor
        println(filename * " Successfully Read!")
    end
end

@doc raw"""
	load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)

Read input parameters related to participation of transmission imports/exports in capacity reserve margin constraint.
"""
function load_cap_reserve_margin_trans!(setup::Dict, inputs::Dict, network_var::DataFrame)
    mat = extract_matrix_from_dataframe(network_var, "DerateCapRes")
    inputs["dfDerateTransCapRes"] = mat

    mat = extract_matrix_from_dataframe(network_var, "CapRes_Excl")
    inputs["dfTransCapRes_excl"] = mat
end
