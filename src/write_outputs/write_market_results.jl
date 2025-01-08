@doc raw"""
	write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)

Function for writing the market results.
"""
function write_market_results(path::AbstractString, inputs::Dict, setup::Dict, EP::Model)
    M = length(inputs[MARKET_LIMITS])  # number of market price tiers
    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    mwh_purchases = Dict()
    for m=1:M
        mwh_purchases["hourly_purchases_mwh_tier_$m"] = 
            vec(JuMP.value.(EP[:vMarketPurchaseMW][:, :, m])) * scale_factor
    end

    df = DataFrame(mwh_purchases)
    hourly_sales = vec(JuMP.value.(EP[:vMarketSaleMW][:, SELL_TIER])) * scale_factor

    df[!, "hourly_sales_mwh"] = hourly_sales

    CSV.write(joinpath(path, "market_results_time_series.csv"), df)

    summary = Dict()
    summary["total_mwh_sales"] = sum(sum(hourly_sales))
    summary["total_sales_benefit"] = [JuMP.value(EP[:eMarketSalesBenefit])] * scale_factor^2
    summary["total_mwh_purchases"]= sum(sum(values(mwh_purchases)))
    summary["total_purchases_cost"] = [JuMP.value(EP[:eMarketPurchasesCost])] * scale_factor^2
    df = DataFrame(summary)

    CSV.write(joinpath(path, "market_results.csv"), df)

end