module MascarenesMaps

using ArchGDAL
using Colors
using ColorSchemes
using DataFrames
using DBFTables
using GeometryBasics
using LandscapeChange
using Makie
using Rasters
using RasterDataSources
using Stencils

using Rasters.Lookups

const NV = NamedVector
using Rasters: Between

export define_map_files

export plot_timeline, plot_habitats!, plot_aggregate!, add_legend! 

export compile_all, load_srtm_masks, summarise_timeline

export stripe_raster, load_srtm_masks

const basepath = realpath(joinpath(@__DIR__, ".."))

include("landcover_settings.jl")
include("map_file_list.jl")
include("plots.jl")
include("landcover_compilation.jl")
include("rasters.jl")

end
