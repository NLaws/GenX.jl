"""
    add_known_price_market_model(EP::Model, inputs::Dict, setup::Dict)

Given market price forecasts this method adds the constraints and objective terms to account for
energy market sales and purchases. For each price vector there is a MW limit of import capacity
meant to represent a transmission limit. The model is only allowed to sell into the first price
vector. 

TODO need to limit the selling quantity in relation to the buying quantity?

The inputs for this market model have the following columns:

    import_limit_MW_1, ..., import_limit_MW_N, price_per_MWh_1, ..., price_per_MWh_N


"""
function add_known_price_market_model(EP::Model, inputs::Dict, setup::Dict)

        # TODO load inputs, need anything in setup?
        T = inputs["T"]     # Number of time steps (hours)
        Z = inputs["Z"]     # Number of zones
        M = 4  # TODO number of markets or price tiers

        # TODO how to add to the load balance equation? appears that all expressions added to
        # ePowerBalance must have (T, Z) indices because in generate_model.jl:
        # @constraint(EP, cPowerBalance[t = 1:T, z = 1:Z],
        #     EP[:ePowerBalance][t, z] == inputs["pD"][t, z]
        # )
        
        @expression(EP, eMarketPurchases[t = 1:T, z = 1:Z],
            0.0
        )

        # add energy purchased to the load balance 
        add_similar_to_expression!(EP[:ePowerBalance], eMarketPurchases)

        # TODO add cost of purchases to objective function
        # TODO add benefit of sales to objective function
        # add_to_expression!(EP[:eObj], eTotalCVarOut)
end