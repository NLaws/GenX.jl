@doc raw"""
    load_annual_build_limits!(setup::Dict, path::AbstractString, inputs::Dict)

Put Annual_build_limits.csv, which is assumed to have columns: Resource,Max_MW, into a dict stored in
`inputs["AnnualBuildLimits"]`. The dict has Resource string keys and Max_MW values (scaled
appropriately).

If any resources are in the Annual_build_limits.csv that are not indicated as `New_Build` (with a
`1` in their CSV file) then an error is thrown.
"""
function load_annual_build_limits!(setup::Dict, path::AbstractString, inputs::Dict)
    filename = "Annual_build_limits.csv"
    df = load_dataframe(joinpath(path, filename))

    scale_factor = setup["ParameterScale"] == 1 ? ModelScalingFactor : 1

    inputs["AnnualBuildLimits"] = Dict(
        row.Resource => row.Max_MW / scale_factor for row in eachrow(df)
    ) 

    resources_with_annual_limits = [
        y for y in inputs["RESOURCES"] if y.resource in keys(inputs["AnnualBuildLimits"])
    ]
    resources_not_in_new_builds = [
        y.resource for y in resources_with_annual_limits if !(y.id in inputs["NEW_CAP"])
    ]
    if !isempty(resources_not_in_new_builds)
        throw(
            @error(
                "The Annual_build_limits.csv contains resources that are not designated as new builds: $(resources_not_in_new_builds)"
            )
        )
    end
    println(filename * " Successfully Read!")
end
