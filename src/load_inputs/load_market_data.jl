
const MARKET_LIMITS = "market_import_limits_MW"
const MARKET_PRICES = "market_prices_per_MWh"
const SELL_TIER = 1  # can only sell in tier 1

@doc raw"""
	load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)

Parse the import_limit_MW_x and price_per_MWh_x for each of the tiers in the Market_data.csv into
the 
- inputs[MARKET_LIMITS]::Vector{Float64} and
- inputs[MARKET_PRICES]::Vector{Vector{Float64}}
"""
function load_market_data!(setup::Dict, path::AbstractString, inputs::Dict)

    TDR_directory = joinpath(path, setup["TimeDomainReductionFolder"])
    # if TDR is used, my_dir = TDR_directory, else my_dir = "system"
    system_dir = get_systemfiles_path(setup, TDR_directory, path)

    # scale_factor is 1,000 for MW to GW, etc.
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    filename = "Market_data.csv"
    df = load_dataframe(joinpath(system_dir, filename))
    limit_columns = names(df, r"^import_limit_MW_")
    price_columns = names(df, r"^price_per_MWh_")
    
    if !(length(limit_columns) == length(price_columns))
        throw(@error "$filename at $system_dir does not have equal number of import_limit_MW_X and price_per_MWh_X columns")
    end

    inputs[MARKET_LIMITS] = Vector{Float64}()
    for col in limit_columns
        push!(
            inputs[MARKET_LIMITS], 
            convert(Float64, df[1, col]) / scale_factor
        )
    end

    inputs[MARKET_PRICES] = Vector{Vector{Float64}}()
    for col in price_columns
        push!(
            inputs[MARKET_PRICES], 
            convert(Vector{Float64}, df[:, col]) / scale_factor
        )
    end

    println(filename * " Successfully Read!")
end