using Rasters
using Rasters.Lookups
using RasterDataSources
using ArchGDAL
using LandscapeChange
const NV = NamedVector
using Rasters: Between

include("landcover_settings.jl")

# Get masks from SRTM dataset
function load_srtm_masks()
    island_bounds = (
        # mus=((57.1, 57.9), (-20.6, -19.8)), # with islands
        mus=((57.1, 57.9), (-20.6, -19.949)),
        reu=((55.0, 56.0), (-22.0, -20.0)),
        rod =((63.0, 64.0), (-20.0, -19.0)),
    )

    tiles = getraster(SRTM; bounds=island_bounds.mus)
    dem1 = Raster(tiles[1]; name=:DEM)
    dem2 = Raster(tiles[2]; name=:DEM)
    border_selectors = map(island_bounds) do bb
        (X(Between(bb[1])), Y(Between(bb[2])))
    end
    # Mauritius is right over the split in the tiles
    m1 = view(dem1, border_selectors.mus...)
    m2 = view(dem2, border_selectors.mus...)
    mus_dem = replace_missing(trim(cat(m1, m2; dims=Y); pad=10))

    reu_tile  = getraster(SRTM; bounds=island_bounds.reu)[1]
    reu_dem = replace_missing(trim(view(Raster(reu_tile), border_selectors.reu...); pad=10))

    rod_tile = getraster(SRTM; bounds=island_bounds.rod)[1]
    rod_dem = replace_missing(trim(view(Raster(rod_tile), border_selectors.rod...); pad=10))

    return map((mus=mus_dem, reu=reu_dem, rod=rod_dem)) do A
        rebuild(boolmask(reorder(A, ForwardOrdered)); name=:mask)
    end
end

function compile_all(filelist, mask, transitions)
    compiled = compile_timeline(filelist, mask, states)
    combined = Rasters.combine(namedvector_raster.(compiled.timeline))
    merged = cross_validate_timeline(combined, transitions)
    added = map(combined, merged) do rs, fs
        # We minimise forced values in the source throught its possible 
        # transitions, they may resolve to one or two distinct timelines. 
        if any(rs) # Ignore completely missing
            map(rs, fs) do r, f
                !r & f
            end
        else
            rs
        end
    end
    filled = map(combined, merged) do rs, fs
        if any(rs)
            zero(rs)
        else
            fs
        end
    end
    removed = map(combined, merged) do rs, fs
        map(rs, fs) do r, f
            r & !f
        end
    end
    uncertain = map(merged) do fs
        if count(fs) > 1
            fs
        else
            zero(fs)
        end
    end

    return (; combined, filled, uncertain, added, removed, merged)
end

function summarise_timeline(s)
    (c, f, u, a, re, m) = s
    combined = sum(+, c; dims=(X, Y)) |> _nt_vecs
    filled = sum(+, f; dims=(X, Y)) |> _nt_vecs
    uncertain = sum(+, u; dims=(X, Y)) |> _nt_vecs
    added = sum(+, a; dims=(X, Y)) |> _nt_vecs
    removed = sum(+, re; dims=(X, Y)) |> _nt_vecs
    merged = sum(+, m; dims=(X, Y)) |> _nt_vecs
    return (; combined, filled, added, removed, uncertain, merged)
end

function _nt_vecs(xs::AbstractArray{<:NamedVector{K}}) where K
    xs = dropdims(xs; dims=(X(), Y()))
    vecs = map(1:length(K)) do i
        getindex.(xs, i)
    end
    RasterStack(vecs...; name=K)
end
