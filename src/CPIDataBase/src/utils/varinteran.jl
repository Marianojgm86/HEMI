# varinteran.jl - basic operations to compute annual price change arrays

"""
    varinteran!(idx, base_index::Real = 100)

Compute annual price changes of `idx` index vector in place, using `base_index` as starting point.
Fills observations 1 to 11 with NaN values.
"""
function varinteran!(idx::AbstractVector, base_index::Real = 100)
    l = length(idx)
    for i in l:-1:13
        @inbounds idx[i] = 100 * (idx[i] / idx[i-12] - 1)
    end
    idx[12] = 100 * (idx[12] / base_index - 1)
    idx[1:11] .= NaN
end

"""
    varinteran!(v, idx, base_index::Real = 100)

Fill `v` vector of annual price changes of `idx` index vector using `base_index` as starting point.
Usually `v` has 11 observations less than `idx`.
"""
function varinteran!(v::AbstractVector, idx::AbstractVector, base_index::Real = 100)
    l = length(v)
    for i in l:-1:2
        @inbounds v[i] = 100 * (idx[i+11] / idx[i-12+11] - 1)
    end
    v[1] = 100 * (idx[12] / base_index - 1)
end


"""
    varinteran(idx::AbstractVector, base_index::Real = 100)

Function to get a vector of annual price changes from a price index vector starting with `base_index`.
"""
function varinteran(idx::AbstractVector, base_index::Real = 100)
    r = length(idx)
    v = zeros(eltype(idx), r-11)
    varinteran!(v, idx, base_index)
    v
end

"""
    varinteran(cpimat::AbstractMatrix, base_index::Real = 100)

Function to get a matrix of annual price changes from a price index matrix starting with `base_index`.
"""
function varinteran(cpimat::AbstractMatrix, base_index::Real = 100)
    r, c = size(cpimat)
    vmat = zeros(eltype(cpimat), r-11, c)
    for j in 1:c
        vcol = @view vmat[:, j]
        idxcol = @view cpimat[:, j]
        varinteran!(vcol, idxcol, base_index)
    end
    vmat
end

"""
    varinteran(cpimat::AbstractMatrix, base_index::AbstractVector)

Function to get a matrix of annual price changes from a price index matrix starting with **vector** `base_index`.
"""
function varinteran(cpimat::AbstractMatrix, base_index::AbstractVector)
    r, c = size(cpimat)
    vmat = zeros(eltype(cpimat), r-11, c)
    for j in 1:c
        vcol = @view vmat[:, j]
        idxcol = @view cpimat[:, j]
        varinteran!(vcol, idxcol, base_index[j])
    end
    vmat
end