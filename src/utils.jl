function optimfunwrapper(x::Vector, g::Vector, site, var)
    g === nothing && (g = zeros(Float64, length(x)))
    return PLsiteAndGrad!(x, g, site,  var)            
end

function optimfunwrapper(x::Vector, g::Vector, var)
    g === nothing && (g = zeros(Float64, length(x)))
    return PLsiteAndGradSym!(x, g, var)            
end


function ComputeScore(Jmat::Array{Float64,2}, var::PlmVar, min_separation::Int)

    q = var.q
    N = var.N

    JJ=reshape(Jmat[1:end-q,:], q,q,N-1,N)



    Jtemp1=zeros( q,q,Int(N*(N-1)/2))
    Jtemp2=zeros( q,q,Int(N*(N-1)/2))
    l = 1

    for i=1:(N-1)
        for j=(i+1):N
            Jtemp1[:,:,l]=JJ[:,:,j-1,i]; #J_ij as estimated from from g_i.
            Jtemp2[:,:,l]=JJ[:,:,i,j]'; #J_ij as estimated from from g_j.
            l=l+1;
        end
    end

    
    Jtensor = zeros(q,q,N,N)
    l = 1
    for i = 1:N-1
        for j=i+1:N
            Jtensor[:,:,i,j] = Jtemp1[:,:,l]
            Jtensor[:,:,j,i] = Jtemp2[:,:,l]'
            l += 1
        end
    end



    ASFN = zeros(N,N)
    for i=1:N,j=1:N 
        i!=j && (ASFN[i,j] =sum(Jtensor[:,:,i,j].^2)) 
    end
    
    J1=fill(0.0,q,q,Int(N*(N-1)/2))
    J2=fill(0.0,q,q,Int(N*(N-1)/2))

    for l=1:Int(N*(N-1)/2)
        J1[:,:,l] = Jtemp1[:,:,l]-repeat(mean(Jtemp1[:,:,l],dims=1),q,1)-repeat(mean(Jtemp1[:,:,l],dims=2),1,q) .+ mean(Jtemp1[:,:,l])
        J2[:,:,l] = Jtemp2[:,:,l]-repeat(mean(Jtemp2[:,:,l],dims=1),q,1)-repeat(mean(Jtemp2[:,:,l],dims=2),1,q) .+ mean(Jtemp2[:,:,l])
    end
    J = 0.5 * ( J1 + J2 )

    htensor = fill(0.0, q,N)
    for i in 1:N
        htensor[:,i] = Jmat[end-q+1:end,i]
    end
    
    FN = fill(0.0, N,N)
    l = 1

    for i=1:N-1
        for j=i+1:N
            FN[i,j] = norm(J[1:q-1,1:q-1,l],2)
#            FN[i,j] = vecnorm(J[:,:,l],2)
            FN[j,i] =FN[i,j]
            l+=1
        end
    end
    FN=GaussDCA.correct_APC(FN)
    score = GaussDCA.compute_ranking(FN,min_separation)
    return score, FN, 0.5*(permutedims(Jtensor,[2,1,4,3])+Jtensor), htensor
end


function ReadFasta(filename::AbstractString,max_gap_fraction::Real, theta::Any, remove_dups::Bool)

    Z = GaussDCA.read_fasta_alignment(filename, max_gap_fraction)
    if remove_dups
        Z, _ = GaussDCA.remove_duplicate_seqs(Z)
    end


    N, M = size(Z)
    q = round(Int,maximum(Z))
    
    q > 32 && error("parameter q=$q is too big (max 31 is allowed)")
    W , Meff = GaussDCA.compute_weights(Z,q,theta)
    rmul!(W, 1.0/Meff)
    Zint=round.(Int,Z)
    return W, Zint,N,M,q
end

function sumexp(vec::Array{Float64,1})    
    mysum = 0.0
    @inbounds @simd for i=1:length(vec)
        mysum += exp(vec[i])
    end
    return mysum
end
