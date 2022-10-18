## Precompilation
@precompile_setup begin
    # Putting some things in `setup` can reduce the size of the
    # precompile file and potentially make loading faster.
    function midrange(material)
        λmin, λmax = material.λrange
        return λmin + 0.5(λmax - λmin)
    end
    
    function exercise(material)
        @show material
        material(midrange(material))
    end

    @precompile_all_calls begin
        redirect_stdout(devnull) do
            exercise(RefractiveMaterial("main", "Ar", "Grace-liquid-90K"))
            exercise(RefractiveMaterial("main", "CdTe", "Marple"))
            exercise(RefractiveMaterial("other", "Mg-LiTaO3", "Moutzouris-o"))
            exercise(RefractiveMaterial("main", "ZnTe", "Li"))
            exercise(RefractiveMaterial("main", "SF6", "Vukovic"))
            exercise(RefractiveMaterial("main", "He", "Mansfield"))
            exercise(RefractiveMaterial("main", "Si", "Edwards"))
            exercise(RefractiveMaterial("main", "AgBr", "Schröter"))
            exercise(RefractiveMaterial("organic", "urea","Rosker-e"))
            exercise(RefractiveMaterial("main", "ZnO", "Stelling"))
            exercise(RefractiveMaterial("https://refractiveindex.info/?shelf=main&book=MgAl2O4&page=Tropf"))
        end
    end
end