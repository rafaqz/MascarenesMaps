deleteat!(Base.LOAD_PATH, 2:lastindex(Base.LOAD_PATH)) # Don't allow other environments

using Revise
using Rasters
using ColorSchemes
using Colors
using FileIO
using ImageIO

using CairoMakie
CairoMakie.activate!()
# using GLMakie
# GLMakie.activate!()

using MascarenesMaps

basepath = realpath(joinpath(dirname(pathof(MascarenesMaps)), ".."))

category_links = define_category_links()
masks = load_srtm_masks()

# Original vegetation rasters
mus_veg_path = joinpath(basepath, "data/vegetation/mus/lostland_vegetation.tif")
reu_veg_path = joinpath(basepath, "data/vegetation/reu/strassberg_vegetation.tif")

# Habitat classes
island_habitat_names = (;
    mus=["semi-dry_evergreen_forest", "open_dry_palm-rich_woodland", "wet_forest", "pandanus_swamp", "mossy_rainforest", "mangrove", "wetland vegetation"],
    reu=["Acacia heterophylla forest", "Coastal habitats", "Lava flows", "Leeward mountain rainforest", "Leeward submountain rainforest", "Lowland open woodland",
         "Lowland rainforest", "Pandanus humid thicket", "Pandanus mountain humid thicket", "Philippia mountain thicket", "Semi dry forest", "Subalpine grassland",
         "Subalpine heathland", "Subalpine shrubland on lapillis", "Subalpine Sophora thicket", "Submountain mesic forest", "Wetlands", "Windward mountain rainforest",
         "Windward submountain rainforest", "no_data"],
)

# Compile statistics
landcover_statistics = map(category_links, masks) do cl, m
    compile_all(cl, m, MascarenesMaps.transitions)
end
certain_uncleared = map(landcover_statistics) do island
    map(island.final) do xs
        count(xs) == 1 && xs.native
    end |> x -> rebuild(x; missingval=0)
end
uncertain_uncleared = map(landcover_statistics) do island
    map(island.final) do xs
        count(xs) > 1 && xs.native
    end |> x -> rebuild(x; missingval=0)
end
original_veg = (;
    mus=reorder(replace_missing(Raster(mus_veg_path), 0), dims(uncertain_uncleared.mus)),
    reu=resample(reorder(replace_missing(Raster(reu_veg_path), 0), uncertain_uncleared.reu); to=masks.reu),
)

# Mask final vegetation maps
# We just broadcast a multiplication of the vegetation
# over the timeseries of uncleared masks
k = keys(original_veg) # Probably no rod
habitat = map(original_veg, certain_uncleared[k], uncertain_uncleared[k]) do v, c, u
    (; certain=broadcast_dims(*, c, v), uncertain=broadcast_dims(*, u, v))
end
nhabitats = map(length, island_habitat_names)

# Full process plot

compiled = map(category_links, masks) do cl, m
    standardize_timeline(cl, m, MascarenesMaps.states)
end;
originals = map(compiled, masks) do c, m
    map(c.files) do f
        if isnothing(f.link.filename)
            nothing
        else
            orig_name = splitext(basename(f.link.filename))[1] * "_warped.png"
            orig_path = joinpath(dirname(f.link.filename), "originals", orig_name)
            isfile(orig_path) ? rebuild(m; data=rotr90(load(orig_path)), missingval=nothing) : nothing
        end
    end
end
categorised = map(compiled) do c
    map(x -> x.categorized_raster, c.files)
end

striped_statistics = stripe_raster(landcover_statistics, MascarenesMaps.states)
original_years = map(compiled, masks) do c, m
    map(f -> f.times, c.files)
end

k = :reu
mus = (:mus, (1700, 3500), original_years.mus)
reu = (:reu, (1700, 2400), original_years.reu)
rod = (:rod, (1400, 1400), original_years.rod)
for (k, size, years) in (mus, reu, rod,)
    full_fig = Figure(; size);
    MascarenesMaps.plot_process!(full_fig,
        originals[k],
        categorised[k],
        Rasters.slice(striped_statistics[k].standardized, Ti),
        Rasters.slice(striped_statistics[k].final, Ti),
        get(habitat, k, nothing);
        years,
    )
    save(joinpath(basepath, "images", "full_process_$k.png"), full_fig)
end

originals[k][1] |> lookup
categorised[k][1] |> lookup
Rasters.slice(striped_statistics[k].standardized, Ti)[1] |> lookup
Rasters.slice(striped_statistics[k].final, Ti)[1] |> lookup

