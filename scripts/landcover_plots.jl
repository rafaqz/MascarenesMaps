deleteat!(Base.LOAD_PATH, 2:lastindex(Base.LOAD_PATH)) # Don't allow other environments

using Revise
using MascarenesMaps
using LandscapeChange
using CairoMakie
using DimensionalData

basepath = realpath(joinpath(dirname(pathof(MascarenesMaps)), ".."))

category_links = define_category_links()
masks = load_srtm_masks() 
states = MascarenesMaps.states

landcover_statistics = map(category_links, masks) do cl, m
    compile_all(cl, m, MascarenesMaps.transitions)
end
timeline_counts = map(summarise_timeline, landcover_statistics)
striped_statistics = stripe_raster(landcover_statistics, MascarenesMaps.states)

name = :mus
sizes = (; mus=(1500, 2800), reu=(1800, 2400), rod=(1800, 1000))
sze = sizes.mus

foreach(MascarenesMaps.island_names, sizes) do name, sze
    timeline, striped, npixels = timeline_counts[name], striped_statistics[name], count(masks[name]);
    fig = Figure(; size=sze .* 2);
    plot_compilation!(fig, timeline, striped, npixels)
    save("$basepath/images/timeline_compilation_$(name).png", fig)
end
