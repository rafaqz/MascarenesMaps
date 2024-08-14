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
