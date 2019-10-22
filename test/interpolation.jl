# This file is part of the TaylorIntegration.jl package; MIT licensed

using TaylorIntegration
using Test
using LinearAlgebra: norm, transpose

@testset "Testing `interpolation.jl`" begin

    local _order = 28
    local _abstol = 1.0E-20

    @testset "Taylor interpolation: scalar case" begin
        eqs_mov(x, p, t) = x^2
        exactsol(t, x0) = x0/(1.0-x0*t) #the analytical solution
        t0 = 0.0
        tmax = 0.3
        x0 = 3.0
        tv, xv = taylorinteg(eqs_mov, x0, t0, tmax, _order, _abstol, nothing)
        tv2, xv2 = taylorinteg(eqs_mov, x0, t0, tmax, _order, _abstol, dense=false)
        # taylorinteg should select dense=false by default
        @test tv == tv2
        @test xv == xv2
        tinterp = taylorinteg(eqs_mov, x0, t0, tmax, _order, _abstol, dense=true)
        tinterp2 = deepcopy(tinterp) # test TaylorInterpolant equality
        @test tinterp2 == tinterp
        @test tinterp.t == tv
        # the interpolator evaluated at tv should equal the solution without interpolation
        @test tinterp.(tinterp.t) == xv
        @test tinterp(0//1) == x0
        @test tinterp(t0) == x0
        @test tinterp(tmax) == xv[end]
        @test_throws AssertionError tinterp(tinterp.t[1]-0.1)
        @test_throws AssertionError tinterp(tinterp.t[end]+0.1)
        tv3 = sort(  union(t0, tmax, tmax*rand(20))  )
        @test all(diff(tv3).>0)
        sol_interp_exact = @__dot__ tinterp(tv3) - exactsol(tv3, x0)
        @test norm(sol_interp_exact, Inf) < 1e-13
        # Test interpolation evaluated at Taylor1 variables
        @test tinterp(t0+Taylor1(3)) == tinterp.x[1]
        dif2 = tinterp(t0+Taylor1(3))(0.1) - tinterp(t0+0.1)
        @test norm(  dif2, Inf  ) < 1e-14
        # Interpolation polynomial evaluated at Taylor1 should be approximately equal to full Taylor jet expansion
        δt = 1e-8
        x0T = Taylor1(tinterp(t0+δt), _order)
        tT = Taylor1(_order)
        tT[0] = t0+δt
        TaylorIntegration.jetcoeffs!(eqs_mov, tT, x0T, nothing)
        difT1 = tinterp(t0+δt+Taylor1(_order)) - x0T
        abs_dif = abs.(difT1.coeffs[1:end-2])
        # `bound_dif` is a bound which worsens as order grows
        bound_dif = eps.(x0T.coeffs[1:end-2]).^[1/k for k in eachindex(x0T.coeffs[1:end-2])]
        @test all( abs_dif .≤ bound_dif )
    end

    @testset "Taylor interpolation: vectorial case" begin
        function f!(Dx, x, p, t)
            Dx[1] = one(t)
            Dx[2] = cos(t)
            nothing
        end
        t0r = 0//1
        tmax = 10.25*(2pi)
        x0 = [t0r, 0.0] #initial conditions such that x(t)=sin(t)
        tv, xv = taylorinteg(f!, x0, t0r, tmax, _order, _abstol)
        tv2, xv2 = taylorinteg(f!, x0, t0r, tmax, _order, _abstol, dense=false)
        # @time tv2, xv2 = taylorinteg(f!, x0, t0r, tmax, _order, _abstol, dense=false)
        @test tv == tv2
        @test xv == xv2
        tinterp = taylorinteg(f!, x0, t0r, tmax, _order, _abstol, dense=true)
        tinterp2 = deepcopy(tinterp) # test TaylorInterpolant equality
        @test tinterp2 == tinterp
        # @time tinterp = taylorinteg(f!, x0, t0r, tmax, _order, _abstol, dense=true)
        @test tinterp.t == tv
        @test transpose(hcat(tinterp.(tv)...)) == xv
        @test tinterp(t0r) == x0
        @test tinterp(tmax) == xv[end,:]
        δt = 1e-8
        tT = Taylor1(_order)
        tT[0] = float(t0r)
        xT = Taylor1.(x0, _order)
        dxT = similar(xT)
        xaux = similar(xT)
        TaylorIntegration.jetcoeffs!(f!, tT, xT, dxT, xaux, nothing)
        dif1 = xT(δt) - tinterp(δt)
        dif2 = xT(δt) - tinterp(δt+Taylor1(_order))()
        dif3 = xT(δt) - tinterp(Taylor1(_order))(δt)
        dif4 = xT(δt) - tinterp(δt/2+Taylor1(_order))(δt/2)
        @test dif1 == zero.(dif1)
        @test dif2 == zero.(dif2)
        @test dif3 == zero.(dif3)
        @test dif4 == zero.(dif4)
    end
end
