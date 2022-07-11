function __init__()
    RI_INFO_ROOT[] = joinpath(artifact"refractiveindex.info",
                              "refractiveindex.info-database-2021-07-18", "database")

    lib = YAML.load_file(joinpath(RI_INFO_ROOT[], "library.yml"), dicttype=Dict{String, Any})
    for shelf in lib
        shelfname = shelf["SHELF"]
        for book in shelf["content"]
            haskey(book, "DIVIDER") && continue
            bookname = book["BOOK"]
            for page in book["content"]
                haskey(page, "DIVIDER") && continue
                pagename = string(page["PAGE"])
                RI_LIB[(shelfname, bookname, pagename)] = (name = page["name"], path=page["data"])
            end
        end
    end

end
