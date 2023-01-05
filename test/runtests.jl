using RefractiveIndex
using Test

function midrange(material)
    λmin, λmax = material.λrange
    return λmin + 0.5(λmax - λmin)
end

function testRM(material, n_ref)
    n = material(midrange(material))
    # Compare only fractional parts
    isapprox(n_ref % 1, n % 1, rtol=1e-3)
end

@testset "RefractiveIndex.jl" begin
    @testset "Dispersion formulas" begin
        # Sellmeier
        @test testRM(RefractiveMaterial("main", "Ar", "Grace-liquid-90K"), 1.2281)

        # Sellmeier-2
        @test testRM(RefractiveMaterial("main", "CdTe", "Marple"), 2.7273)

        # Polynomial
        @test testRM(RefractiveMaterial("other", "Mg-LiTaO3", "Moutzouris-o"), 2.1337)

        # RefractiveIndex.INFO
        @test testRM(RefractiveMaterial("main", "ZnTe", "Li"), 2.6605)

        # Cauchy
        @test testRM(RefractiveMaterial("main", "SF6", "Vukovic"), 1.00072071)

        # Gases
        @test testRM(RefractiveMaterial("main", "He", "Mansfield"), 1.000034724)

        # Herzberger
        @test testRM(RefractiveMaterial("main", "Si", "Edwards"), 3.4208)

        # Retro
        @test testRM(RefractiveMaterial("main", "AgBr", "Schröter"), 2.2600)

        # Exotic
        @test testRM(RefractiveMaterial("organic", "urea","Rosker-e"), 1.6000)
    end

    @testset "Tabular data" begin
        # RefractiveNK
        @test testRM(RefractiveMaterial("main", "ZnO", "Stelling"), 1.5970)
    end

    @testset "Multiple dispersion data entries" begin # (https://github.com/stillyslalom/RefractiveIndex.jl/issues/14)
        # Hikari-F1 (Polynomial, TabulatedK)
        HikariF1 = @test_nowarn RefractiveMaterial("glass", "HIKARI-F", "F1") 
        @test length(HikariF1) == 2
        @test isapprox(extinction(HikariF1[2], 0.35), 4.5265e-7, rtol=1e-3)
    end

end
