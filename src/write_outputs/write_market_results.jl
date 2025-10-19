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

    net_hourly_sales = [ val > 0 ? val : 0.0 for val in 
        hourly_sales - mwh_purchases["hourly_purchases_mwh_tier_$SELL_TIER"]
    ]
    net_purchase_in_sell_tier = [ val > 0 ? val : 0.0 for val in 
        mwh_purchases["hourly_purchases_mwh_tier_$SELL_TIER"] - hourly_sales
    ]
    summary = Dict()
    summary["net_mwh_sales"] = sum(net_hourly_sales .* inputs["omega"])
    summary["tier_$(SELL_TIER)_net_mwh_purchases"] = sum(net_purchase_in_sell_tier .* inputs["omega"])
    summary["total_mwh_sales"] = sum(sum(hourly_sales) .* inputs["omega"])
    summary["total_sales_benefit"] = [JuMP.value(EP[:eMarketSalesBenefit])] * scale_factor^2
    summary["total_mwh_purchases"] = sum(sum(values(mwh_purchases)) .* inputs["omega"])
    summary["total_purchases_cost"] = [JuMP.value(EP[:eMarketPurchasesCost])] * scale_factor^2
    summary["net_mwh_purchases"] = summary["total_mwh_purchases"] - sum(mwh_purchases["hourly_purchases_mwh_tier_$SELL_TIER"] .* inputs["omega"]) + summary["tier_$(SELL_TIER)_net_mwh_purchases"]
    df = DataFrame(summary)

    CSV.write(joinpath(path, "market_results.csv"), df)

end