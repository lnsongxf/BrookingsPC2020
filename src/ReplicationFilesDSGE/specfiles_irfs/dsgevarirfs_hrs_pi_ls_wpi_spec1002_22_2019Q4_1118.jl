using DSGE, ModelConstructors, Dates, LinearAlgebra, Test
include("../includeall.jl")
# ENV["frbnyjuliamemory"] = "1G"

## What to do?
run_irfs         = false
do_rev_transform = false
do_add_workers   = false
make_plots       = true
n_workers = 50

## Set flags
vint = "191118"
forecast_string1 = "regime1"
forecast_string2 = "regime2"

# Set up DSGE-VAR system
lags = 4
shocks = Vector{Symbol}(undef,0) # empty implies all shocks
observables = [:obs_hours, :π_t, :laborshare_t, :NominalWageGrowth]
obs_shock = :obs_hours

# Set up ylims for plots
ylims_dict = Dict{Symbol,Tuple{Float64,Float64}}()
ylims_dict[:obs_hours] = (-2.75, -0.5)
ylims_dict[:π_t] = (-0.6, 0.2)
ylims_dict[:laborshare_t] = (-1.0, 0.2)
ylims_dict[:NominalWageGrowth] = (-1.3, 0.3)

ylabels_dict = Dict{Symbol,String}()
ylabels_dict[:obs_hours] = "percent"
ylabels_dict[:π_t] = "percentage points"
ylabels_dict[:laborshare_t] = "percent"
ylabels_dict[:NominalWageGrowth] = "percentage points"

xlabels_dict = Dict{Symbol,String}()
xlabels_dict[:obs_hours] = "horizon"
xlabels_dict[:π_t] = "horizon"
xlabels_dict[:laborshare_t] = "horizon"
xlabels_dict[:NominalWageGrowth] = "horizon"

# ylims_dict[:π_t] = (-0.1, 0.25)
# ylims_dict[:π_t] = (-0.1, 0.25)
# ylims_dict[:obs_wages] = (-0.1, 0.25)
# ylims_dict[:Hours] = (-0.1, 2.)
# ylims_dict[:Wages] = (-0.25, 0.8)
# ylims_dict[:NominalWageGrowth] = (-0.1, 1.0)
# ylims_dict[:laborshare_t] = (-0.25, 1.0)
# ylims_dict[:laborproductivity] = (-0.4, 0.5)
# ylims_dict[:MarginalCost] = (-0.1, 1.0)

## Set up model and data for subsamples
custom_settings = Dict{Symbol,Setting}(:add_laborshare_measurement =>
                                        Setting(:add_laborshare_measurement, true),
                                        :hours_first_observable =>
                                        Setting(:hours_first_observable, false),
                                        :add_laborproductivity_measurement =>
                                        Setting(:add_laborproductivity_measurement, false),
                                        :add_laborproductivitygrowth_nome_measurement =>
                                        Setting(:add_laborproductivitygrowth_nome_measurement,
                                                false))
fp = dirname(@__FILE__)
m = Model1002("ss22"; custom_settings = custom_settings)
standard_spec!(m, vint, fp; fcast_date = Date(2019, 12, 31), dsid = 10021, cdid = 1)
m <= Setting(:period, "full_incZLB", true, "period", "period for this exercise (first or second)")
m <= Setting(:date_regime2_start_text, "900331", true, "reg2start",
             "The text version to be saved of when regime 2 starts")
m <= Setting(:friday, "true", true, "friday", "estimation ran on friday")
m <= Setting(:npart, "20000", true, "npart", "number of SMC particles")
m <= Setting(:reg, "2", true, "reg", "number of regimes")
m <= Setting(:use_population_forecast, false)

# Set estimation overrides
# overrides = forecast_input_file_overrides(m)
# overrides[:full] = joinpath(fp, "../../../save/output_data/$(spec(m))/$(subspec(m))/estimate/raw/smcsave_period=first_vint=191118.h5")

try
    @assert !isempty(shocks)
catch
    push!(shocks, collect(keys(m.exogenous_shocks))...)
end

if run_irfs
    if do_add_workers
        addprocs_frbny(n_workers)
        @everywhere using DSGE, DSGEModels, OrderedCollections
    end

    parallel = do_add_workers ? true : false
    impulse_responses(m, load_draws(m, :full), :full, :cholesky,
                      lags, observables, shocks,
                      findfirst(observables .== obs_shock);
                      parallel = parallel, flip_shocks = false,
                      compute_meansbands = true,
                      regime_switching = true,
                      n_regimes = 2,
                      regime = 1,
                      forecast_string = forecast_string1)
    impulse_responses(m, load_draws(m, :full), :full, :cholesky,
                      lags, observables, shocks,
                      findfirst(observables .== obs_shock);
                      parallel = parallel, flip_shocks = false,
                      compute_meansbands = true,
                      regime_switching = true,
                      n_regimes = 2,
                      regime = 2,
                      forecast_string = forecast_string2)
    impulse_responses(m, load_draws(m, :full), :full, :maxBC,
                      lags, observables, shocks,
                      findfirst(observables .== obs_shock);
                      parallel = parallel, flip_shocks = false,
                      compute_meansbands = true,
                      regime_switching = true,
                      n_regimes = 2,
                      regime = 1,
                      forecast_string = forecast_string1)
    impulse_responses(m, load_draws(m, :full), :full, :maxBC,
                      lags, observables, shocks,
                      findfirst(observables .== obs_shock);
                      parallel = parallel, flip_shocks = false,
                      compute_meansbands = true,
                      regime_switching = true,
                      n_regimes = 2,
                      regime = 2,
                      forecast_string = forecast_string2)

    @info "Completed calculation of IRFs"
end

# Plot IRFs
if make_plots
    obs_ind    = findall([k in collect(keys(m.observables)) for k in observables])
    pseudo_ind = findall([k in collect(keys(m.pseudo_observables)) for k in observables])
    plot_brookings_irfs(m, m, observables[obs_ind],
                        :obs, :cholesky, :full, :none;
                        irf_product = :dsgevarirf,
                        observables = observables,
                        forecast_string1 = forecast_string1,
                        forecast_string2 = forecast_string2,
                        legend_names = ["Pre 1990", "Post 1990"],
                        ylims_dict = ylims_dict,
                                 ylabels_dict = ylabels_dict,
                                 xlabels_dict = xlabels_dict)

    plot_brookings_irfs(m, m, observables[pseudo_ind],
                        :pseudo, :cholesky, :full, :none;
                        irf_product = :dsgevarirf,
                        observables = observables,
                        forecast_string1 = forecast_string1,
                        forecast_string2 = forecast_string2,
                        legend_names = ["Pre 1990", "Post 1990"],
                        ylims_dict = ylims_dict,
                                 ylabels_dict = ylabels_dict,
                                 xlabels_dict = xlabels_dict)

    plot_brookings_irfs(m, m, observables[obs_ind],
                        :obs, :maxBC, :full, :none;
                        irf_product = :dsgevarirf,
                        observables = observables,
                        forecast_string1 = forecast_string1,
                        forecast_string2 = forecast_string2,
                        legend_names = ["Pre 1990", "Post 1990"],
                        ylims_dict = ylims_dict,
                                 ylabels_dict = ylabels_dict,
                                 xlabels_dict = xlabels_dict)

    plot_brookings_irfs(m, m, observables[pseudo_ind],
                        :pseudo, :maxBC, :full, :none;
                        irf_product = :dsgevarirf,
                        observables = observables,
                        forecast_string1 = forecast_string1,
                        forecast_string2 = forecast_string2,
                        legend_names = ["Pre 1990", "Post 1990"],
                        ylims_dict = ylims_dict,
                                 ylabels_dict = ylabels_dict,
                                 xlabels_dict = xlabels_dict)


   # # Create shock decompositions at mode
    # DSGE.update!(m, load_draws(m, :mode))
    # DSGE.update!(m, load_draws(m, :mode))
    # system = compute_system(m)
    # system = compute_system(m)
    # permute_mat = Matrix{Float64}(I, n_observables(m), n_observables(m))
    # h = impulse_response_horizons(m)
    # _, obs1, _ = impulse_responses(m, system, h, permute_mat,
    #                                vcat(1.,
    #                                     zeros(n_observables(m) - 1)),
    #                                flip_shocks = false,
    #                                cholesky_obs_shock = true)
    # hr_shock1 = 1. / obs1[1,1]
    # states1, obs1, pseudo1, _, irfshock1 = impulse_responses(m, system, h, permute_mat,
    #                                           vcat(hr_shock1,
    #                                                zeros(n_observables(m) - 1)),
    #                                           cholesky_obs_shock = true,
    #                                           flip_shocks = false,
    #                                           get_shocks = true)
    # _, obs2, _ = impulse_responses(m, system, h, permute_mat,
    #                                vcat(1.,
    #                                     zeros(n_observables(m) - 1)),
    #                                flip_shocks = false,
    #                                cholesky_obs_shock = true)
    # hr_shock2 = 1. / obs2[1,1]
    # _, obs2, pseudo2, _, irfshock2 = impulse_responses(m, system, h, permute_mat,
    #                                           vcat(hr_shock2,
    #                                                zeros(n_observables(m) - 1)),
    #                                           flip_shocks = false,
    #                                           cholesky_obs_shock = true,
    #                                           get_shocks = true)

    # if do_rev_transform
    #     for (k,v) in m.observable_mappings
    #         irf_trans = DSGE.get_irf_transform(v.rev_transform)
    #         obs1[m.observables[k],:] = irf_trans(obs1[m.observables[k],:])
    #     end
    #     for (k,v) in m.observable_mappings
    #         irf_trans = DSGE.get_irf_transform(v.rev_transform)
    #         obs2[m.observables[k],:] = irf_trans(obs2[m.observables[k],:])
    #     end
    # end

    # pseudo1 = correct_integ_series!(m, pseudo1)
    # pseudo2 = correct_integ_series!(m, pseudo2)
    # df_irfshock1 = DataFrame()
    # df_irfshock2 = DataFrame()
    # df_obs1 = DataFrame()
    # df_obs2 = DataFrame()
    # df_pseudo1 = DataFrame()
    # df_pseudo2 = DataFrame()
    # for (shock,ind) in m.exogenous_shocks
    #     df_irfshock1[!,shock] = [irfshock1[ind]]
    #     df_irfshock2[!,shock] = [irfshock2[ind]]
    # end
    # for (k,v) in m.observables
    #     df_obs1[!,k] = vcat(0., obs1[v,:])
    #     df_obs2[!,k] = vcat(0., obs2[v,:])
    # end
    # for (k,v) in m.pseudo_observables
    #     df_pseudo1[!,k] = vcat(0., pseudo1[v,:])
    #     df_pseudo2[!,k] = vcat(0., pseudo2[v,:])
    # end
    # plot_shockdecirfline_cond_obs_shocks(m, :mode, :none, [:pseudo, :obs],
    #                                      shock_groupings(m),
    #                                      df_irfshock1,
    #                                      [DataFrame(df_pseudo1[2:end,:]),
    #                                       DataFrame(df_obs1[2:end,:])],
    #                                      forecast_string = forecast_string1,
    #                                      forecast_string1 = forecast_string1,
    #                                      forecast_string2 = forecast_string1,
    #                                      fourquarter = [false, false],
    #                                      addtl_fn_text = "_cholesky",
    #                                      ylims_dict = ylims_dict)
    # plot_shockdecirfline_cond_obs_shocks(m, :mode, :none, [:pseudo, :obs],
    #                                      shock_groupings(m), df_irfshock2,
    #                                      [DataFrame(df_pseudo2[2:end,:]),
    #                                       DataFrame(df_obs2[2:end,:])],
    #                                      forecast_string = forecast_string2,
    #                                      forecast_string1 = forecast_string2,
    #                                      forecast_string2 = forecast_string2,
    #                                      fourquarter = [false, false],
    #                                      addtl_fn_text = "_cholesky",
    #                                      ylims_dict = ylims_dict)
end

nothing
